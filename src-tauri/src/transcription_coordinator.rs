use crate::actions::ACTION_MAP;
use crate::managers::audio::AudioRecordingManager;
use log::{debug, error, warn};
use std::sync::mpsc::{self, Sender};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};
use tauri::{AppHandle, Manager};

const DEBOUNCE: Duration = Duration::from_millis(30);
const RELEASE_GRACE: Duration = Duration::from_millis(50);
/// A push-to-talk press shorter than this is a tap, not a hold.
const TAP_MAX: Duration = Duration::from_millis(250);
/// After a tap, a second press within this window turns on hands-free.
const DOUBLE_TAP_WINDOW: Duration = Duration::from_millis(350);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum PttAction {
    Passthrough,
    DeferRelease,
    CancelRelease,
}

struct PendingRelease {
    binding_id: String,
    hotkey_string: String,
    deadline: Instant,
}

/// Commands processed sequentially by the coordinator thread.
enum Command {
    Input {
        binding_id: String,
        hotkey_string: String,
        is_pressed: bool,
        push_to_talk: bool,
    },
    Cancel {
        recording_was_active: bool,
    },
    ProcessingFinished,
    BeginUpdate(Sender<bool>),
    EndUpdate,
}

/// Pipeline lifecycle, owned exclusively by the coordinator thread.
enum Stage {
    Idle,
    Recording(String), // binding_id
    Processing,
}

#[derive(Default)]
struct UpdateReservation(bool);

impl UpdateReservation {
    fn reserve(&mut self, stage: &Stage) -> bool {
        if self.0 || !matches!(stage, Stage::Idle) {
            return false;
        }
        self.0 = true;
        true
    }

    fn release(&mut self) {
        self.0 = false;
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum PttDecision {
    Nothing,
    Start,
    Stop,
    Cancel,
}

/// Push-to-talk with a hands-free mode: hold the key to talk, or double-tap it
/// to keep recording after letting go, then tap once more to finish. Recording
/// starts on the first press, so nothing said during the double tap is lost.
#[derive(Debug, Default)]
struct HoldOrDoubleTap {
    pressed_at: Option<Instant>,
    second_tap_deadline: Option<Instant>,
    hands_free: bool,
    swallow_release: bool,
}

impl HoldOrDoubleTap {
    fn press(&mut self, now: Instant, idle: bool, recording_this: bool) -> PttDecision {
        if idle {
            *self = Self {
                pressed_at: Some(now),
                ..Self::default()
            };
            return PttDecision::Start;
        }
        if !recording_this {
            return PttDecision::Nothing;
        }
        if self.second_tap_deadline.take().is_some() {
            self.hands_free = true;
            self.swallow_release = true;
            PttDecision::Nothing
        } else if self.hands_free {
            *self = Self::default();
            PttDecision::Stop
        } else {
            PttDecision::Nothing
        }
    }

    fn release(&mut self, released_at: Instant, recording_this: bool) -> PttDecision {
        if !recording_this {
            return PttDecision::Nothing;
        }
        if self.swallow_release {
            self.swallow_release = false;
            return PttDecision::Nothing;
        }
        if self.hands_free {
            return PttDecision::Nothing;
        }
        if self
            .pressed_at
            .is_some_and(|t| released_at.saturating_duration_since(t) < TAP_MAX)
        {
            self.second_tap_deadline = Some(released_at + DOUBLE_TAP_WINDOW);
            return PttDecision::Nothing;
        }
        *self = Self::default();
        PttDecision::Stop
    }

    fn deadline(&self) -> Option<Instant> {
        self.second_tap_deadline
    }

    /// A lone tap with no second press: too short to hold any speech, so the
    /// recording is discarded instead of transcribed.
    fn expire(&mut self, now: Instant, recording: bool) -> PttDecision {
        match self.second_tap_deadline {
            Some(deadline) if deadline <= now => {
                *self = Self::default();
                if recording {
                    PttDecision::Cancel
                } else {
                    PttDecision::Nothing
                }
            }
            _ => PttDecision::Nothing,
        }
    }
}

fn classify_ptt_event(
    pending_release_binding: Option<&str>,
    is_pressed: bool,
    push_to_talk: bool,
    binding_id: &str,
    recording_binding: Option<&str>,
) -> PttAction {
    if !push_to_talk {
        return PttAction::Passthrough;
    }

    if is_pressed {
        if pending_release_binding == Some(binding_id) {
            PttAction::CancelRelease
        } else {
            PttAction::Passthrough
        }
    } else if recording_binding == Some(binding_id) && pending_release_binding.is_none() {
        PttAction::DeferRelease
    } else {
        PttAction::Passthrough
    }
}

/// Serialises all transcription lifecycle events through a single thread
/// to eliminate race conditions between keyboard shortcuts, signals, and
/// the async transcribe-paste pipeline.
pub struct TranscriptionCoordinator {
    tx: Sender<Command>,
}

pub fn is_transcribe_binding(id: &str) -> bool {
    id == "transcribe" || id == "transcribe_with_post_process"
}

impl TranscriptionCoordinator {
    pub fn new(app: AppHandle) -> Self {
        let (tx, rx) = mpsc::channel();

        thread::spawn(move || {
            let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                let mut stage = Stage::Idle;
                let mut last_press: Option<Instant> = None;
                let mut pending_release: Option<PendingRelease> = None;
                let mut update = UpdateReservation::default();
                let mut hold_or_tap = HoldOrDoubleTap::default();

                loop {
                    let next_deadline = [
                        pending_release.as_ref().map(|pending| pending.deadline),
                        hold_or_tap.deadline(),
                    ]
                    .into_iter()
                    .flatten()
                    .min();
                    let cmd = if let Some(deadline) = next_deadline {
                        match rx.recv_timeout(deadline.saturating_duration_since(Instant::now())) {
                            Ok(cmd) => cmd,
                            Err(mpsc::RecvTimeoutError::Timeout) => {
                                let now = Instant::now();
                                if pending_release
                                    .as_ref()
                                    .is_some_and(|pending| pending.deadline <= now)
                                {
                                    if let Some(pending) = pending_release.take() {
                                        let recording_this = matches!(&stage, Stage::Recording(id) if id == &pending.binding_id);
                                        let released_at = pending.deadline - RELEASE_GRACE;
                                        if hold_or_tap.release(released_at, recording_this)
                                            == PttDecision::Stop
                                        {
                                            stop(
                                                &app,
                                                &mut stage,
                                                &pending.binding_id,
                                                &pending.hotkey_string,
                                            );
                                        }
                                    }
                                }
                                let recording = matches!(stage, Stage::Recording(_));
                                if hold_or_tap.expire(now, recording) == PttDecision::Cancel {
                                    debug!("Single tap without a second: discarding recording");
                                    crate::utils::cancel_current_operation(&app);
                                    stage = Stage::Idle;
                                }
                                continue;
                            }
                            Err(mpsc::RecvTimeoutError::Disconnected) => break,
                        }
                    } else {
                        match rx.recv() {
                            Ok(cmd) => cmd,
                            Err(_) => break,
                        }
                    };

                    match cmd {
                        Command::Input {
                            binding_id,
                            hotkey_string,
                            is_pressed,
                            push_to_talk,
                        } => {
                            if update.0 {
                                debug!("Ignoring dictation input while an approved update is installing");
                                continue;
                            }
                            let pending_release_binding = pending_release
                                .as_ref()
                                .map(|pending| pending.binding_id.as_str());
                            let recording_binding = match &stage {
                                Stage::Recording(id) => Some(id.as_str()),
                                _ => None,
                            };

                            match classify_ptt_event(
                                pending_release_binding,
                                is_pressed,
                                push_to_talk,
                                &binding_id,
                                recording_binding,
                            ) {
                                PttAction::CancelRelease => {
                                    pending_release = None;
                                    continue;
                                }
                                PttAction::DeferRelease => {
                                    pending_release = Some(PendingRelease {
                                        binding_id,
                                        hotkey_string,
                                        deadline: Instant::now() + RELEASE_GRACE,
                                    });
                                    continue;
                                }
                                PttAction::Passthrough => {}
                            }

                            // Debounce rapid-fire press events (key repeat / double-tap).
                            // Push-to-talk releases may be deferred above to absorb X11 auto-repeat.
                            if is_pressed {
                                let now = Instant::now();
                                if last_press.is_some_and(|t| now.duration_since(t) < DEBOUNCE) {
                                    debug!("Debounced press for '{binding_id}'");
                                    continue;
                                }
                                last_press = Some(now);
                            }

                            if push_to_talk {
                                let idle = matches!(stage, Stage::Idle);
                                let recording_this =
                                    matches!(&stage, Stage::Recording(id) if id == &binding_id);
                                let decision = if is_pressed {
                                    hold_or_tap.press(Instant::now(), idle, recording_this)
                                } else {
                                    hold_or_tap.release(Instant::now(), recording_this)
                                };
                                match decision {
                                    PttDecision::Start => {
                                        start(&app, &mut stage, &binding_id, &hotkey_string)
                                    }
                                    PttDecision::Stop => {
                                        stop(&app, &mut stage, &binding_id, &hotkey_string)
                                    }
                                    PttDecision::Cancel | PttDecision::Nothing => {}
                                }
                            } else if is_pressed {
                                match &stage {
                                    Stage::Idle => {
                                        start(&app, &mut stage, &binding_id, &hotkey_string);
                                    }
                                    Stage::Recording(id) if id == &binding_id => {
                                        stop(&app, &mut stage, &binding_id, &hotkey_string);
                                    }
                                    _ => {
                                        debug!("Ignoring press for '{binding_id}': pipeline busy")
                                    }
                                }
                            }
                        }
                        Command::Cancel {
                            recording_was_active,
                        } => {
                            pending_release = None;
                            hold_or_tap = HoldOrDoubleTap::default();
                            // Don't reset during processing — wait for the pipeline to finish.
                            if !matches!(stage, Stage::Processing)
                                && (recording_was_active || matches!(stage, Stage::Recording(_)))
                            {
                                stage = Stage::Idle;
                            }
                        }
                        Command::ProcessingFinished => {
                            hold_or_tap = HoldOrDoubleTap::default();
                            stage = Stage::Idle;
                        }
                        Command::BeginUpdate(reply) => {
                            let reserved = update.reserve(&stage);
                            if reply.send(reserved).is_err() && reserved {
                                update.release();
                            }
                        }
                        Command::EndUpdate => update.release(),
                    }
                }
                debug!("Transcription coordinator exited");
            }));
            if let Err(e) = result {
                error!("Transcription coordinator panicked: {e:?}");
            }
        });

        Self { tx }
    }

    /// Reserve idle dictation until the approved installation finishes. The
    /// same queue handles shortcuts, so a late keypress cannot race the check.
    pub fn begin_update(&self) -> Result<(), String> {
        let (reply, result) = mpsc::channel();
        self.tx.send(Command::BeginUpdate(reply)).map_err(|_| {
            "Dictation is unavailable; restart NSM Flow before updating.".to_string()
        })?;
        match result.recv_timeout(Duration::from_secs(5)) {
            Ok(true) => Ok(()),
            Ok(false) => Err("Finish your recording or transcription before updating.".to_string()),
            Err(_) => {
                let _ = self.end_update();
                Err("Could not prepare the update. Please try again.".to_string())
            }
        }
    }

    pub fn end_update(&self) -> Result<(), String> {
        self.tx
            .send(Command::EndUpdate)
            .map_err(|_| "Could not release the update reservation.".to_string())
    }

    /// Send a keyboard/signal input event for a transcribe binding.
    /// For signal-based toggles, use `is_pressed: true` and `push_to_talk: false`.
    pub fn send_input(
        &self,
        binding_id: &str,
        hotkey_string: &str,
        is_pressed: bool,
        push_to_talk: bool,
    ) {
        if self
            .tx
            .send(Command::Input {
                binding_id: binding_id.to_string(),
                hotkey_string: hotkey_string.to_string(),
                is_pressed,
                push_to_talk,
            })
            .is_err()
        {
            warn!("Transcription coordinator channel closed");
        }
    }

    pub fn notify_cancel(&self, recording_was_active: bool) {
        if self
            .tx
            .send(Command::Cancel {
                recording_was_active,
            })
            .is_err()
        {
            warn!("Transcription coordinator channel closed");
        }
    }

    pub fn notify_processing_finished(&self) {
        if self.tx.send(Command::ProcessingFinished).is_err() {
            warn!("Transcription coordinator channel closed");
        }
    }
}

fn start(app: &AppHandle, stage: &mut Stage, binding_id: &str, hotkey_string: &str) {
    let Some(action) = ACTION_MAP.get(binding_id) else {
        warn!("No action in ACTION_MAP for '{binding_id}'");
        return;
    };
    action.start(app, binding_id, hotkey_string);
    if app
        .try_state::<Arc<AudioRecordingManager>>()
        .is_some_and(|a| a.is_recording())
    {
        *stage = Stage::Recording(binding_id.to_string());
    } else {
        debug!("Start for '{binding_id}' did not begin recording; staying idle");
    }
}

fn stop(app: &AppHandle, stage: &mut Stage, binding_id: &str, hotkey_string: &str) {
    let Some(action) = ACTION_MAP.get(binding_id) else {
        warn!("No action in ACTION_MAP for '{binding_id}'");
        return;
    };
    action.stop(app, binding_id, hotkey_string);
    *stage = Stage::Processing;
}

#[cfg(test)]
mod tests {
    #[test]
    fn update_cannot_reserve_a_recording_or_processing_session() {
        let mut update = super::UpdateReservation::default();
        assert!(!update.reserve(&super::Stage::Recording("transcribe".into())));
        assert!(!update.reserve(&super::Stage::Processing));
        assert!(update.reserve(&super::Stage::Idle));
    }

    #[test]
    fn update_blocks_late_dictation_until_failure_releases_it() {
        let mut update = super::UpdateReservation::default();
        assert!(update.reserve(&super::Stage::Idle));
        assert!(update.0);
        assert!(!update.reserve(&super::Stage::Idle));
        update.release();
        assert!(!update.0);
        assert!(update.reserve(&super::Stage::Idle));
    }

    use super::*;

    #[test]
    fn push_to_talk_release_while_recording_defers_release() {
        assert_eq!(
            classify_ptt_event(None, false, true, "transcribe", Some("transcribe")),
            PttAction::DeferRelease
        );
    }

    #[test]
    fn push_to_talk_press_matching_pending_release_cancels_release() {
        assert_eq!(
            classify_ptt_event(
                Some("transcribe"),
                true,
                true,
                "transcribe",
                Some("transcribe")
            ),
            PttAction::CancelRelease
        );
    }

    #[test]
    fn toggle_mode_press_and_release_pass_through() {
        assert_eq!(
            classify_ptt_event(
                Some("transcribe"),
                true,
                false,
                "transcribe",
                Some("transcribe")
            ),
            PttAction::Passthrough
        );
        assert_eq!(
            classify_ptt_event(None, false, false, "transcribe", Some("transcribe")),
            PttAction::Passthrough
        );
    }

    #[test]
    fn press_for_different_binding_than_pending_release_passes_through() {
        assert_eq!(
            classify_ptt_event(
                Some("transcribe"),
                true,
                true,
                "transcribe_with_post_process",
                Some("transcribe")
            ),
            PttAction::Passthrough
        );
    }

    #[test]
    fn press_matching_pending_release_cancels_without_recording_state() {
        assert_eq!(
            classify_ptt_event(Some("transcribe"), true, true, "transcribe", None),
            PttAction::CancelRelease
        );
    }

    // ---------------------------------------------------------------------
    // Sequence-level regression coverage for issue #1539.
    //
    // Under X11 key auto-repeat, holding a push-to-talk key does not emit one
    // long press. It emits the initial press followed by a stream of
    // synthesized release/press pairs, then a single genuine release on key-up.
    // Before the fix, every synthesized release passed straight through and
    // stopped recording, so holding the key "rapidly toggled" recording on and
    // off. The fix defers each release for a short grace window and cancels it
    // when the matching auto-repeat press arrives.
    //
    // The unit tests above assert `classify_ptt_event` in isolation. The
    // simulator below threads that classifier through the same `pending_release`
    // / `stage` state transitions the coordinator loop performs (lines that
    // handle `Command::Input` and the `recv_timeout` grace expiry), so a whole
    // event burst can be exercised deterministically without a Tauri AppHandle
    // or real timers.
    // ---------------------------------------------------------------------

    const BINDING: &str = "transcribe";

    #[derive(Clone, Copy)]
    enum Ev {
        /// A key-down event (real initial press or a synthesized auto-repeat press).
        Press,
        /// A key-up event (synthesized auto-repeat release or the genuine key-up).
        Release,
        /// The `RELEASE_GRACE` window elapsed with no cancelling press arriving.
        Grace,
    }

    #[derive(Debug, PartialEq, Eq)]
    enum SimStage {
        Idle,
        Recording,
        Processing,
    }

    struct SimResult {
        starts: u32,
        stops: u32,
        stage: SimStage,
    }

    /// Mirror of the coordinator loop's decision logic for a single push-to-talk
    /// binding: it calls the real `classify_ptt_event` and applies the exact same
    /// Defer / Cancel / debounce / start / stop transitions.
    fn simulate(events: &[Ev]) -> SimResult {
        let mut stage = SimStage::Idle;
        let mut pending: Option<String> = None;
        let mut last_press_ms: Option<u64> = None;
        let mut clock_ms: u64 = 0;
        let mut starts = 0u32;
        let mut stops = 0u32;
        let debounce_ms = DEBOUNCE.as_millis() as u64;

        for ev in events {
            // Auto-repeat events arrive a few ms apart, well inside DEBOUNCE.
            clock_ms += 5;

            match ev {
                Ev::Grace => {
                    // Coordinator's `RecvTimeoutError::Timeout` arm: fire the
                    // deferred release iff we are still recording that binding.
                    if let Some(pending_binding) = pending.take() {
                        if stage == SimStage::Recording && pending_binding == BINDING {
                            stage = SimStage::Processing;
                            stops += 1;
                        }
                    }
                }
                Ev::Press | Ev::Release => {
                    let is_pressed = matches!(ev, Ev::Press);
                    let pending_binding = pending.as_deref();
                    let recording_binding = if stage == SimStage::Recording {
                        Some(BINDING)
                    } else {
                        None
                    };

                    match classify_ptt_event(
                        pending_binding,
                        is_pressed,
                        true, // push_to_talk
                        BINDING,
                        recording_binding,
                    ) {
                        PttAction::CancelRelease => {
                            pending = None;
                            continue;
                        }
                        PttAction::DeferRelease => {
                            pending = Some(BINDING.to_string());
                            continue;
                        }
                        PttAction::Passthrough => {}
                    }

                    if is_pressed {
                        if last_press_ms.is_some_and(|t| clock_ms - t < debounce_ms) {
                            continue;
                        }
                        last_press_ms = Some(clock_ms);
                    }

                    if is_pressed && stage == SimStage::Idle {
                        stage = SimStage::Recording;
                        starts += 1;
                    } else if !is_pressed && stage == SimStage::Recording {
                        stage = SimStage::Processing;
                        stops += 1;
                    }
                }
            }
        }

        SimResult {
            starts,
            stops,
            stage,
        }
    }

    fn ms(base: Instant, n: u64) -> Instant {
        base + Duration::from_millis(n)
    }

    #[test]
    fn holding_the_key_records_until_release() {
        let t = Instant::now();
        let mut k = HoldOrDoubleTap::default();
        assert_eq!(k.press(t, true, false), PttDecision::Start);
        assert_eq!(k.release(ms(t, 1500), true), PttDecision::Stop);
        assert_eq!(k.deadline(), None);
    }

    #[test]
    fn double_tap_keeps_recording_until_the_next_tap() {
        let t = Instant::now();
        let mut k = HoldOrDoubleTap::default();
        assert_eq!(k.press(t, true, false), PttDecision::Start);
        assert_eq!(k.release(ms(t, 100), true), PttDecision::Nothing);
        assert_eq!(k.press(ms(t, 250), false, true), PttDecision::Nothing);
        assert_eq!(k.release(ms(t, 330), true), PttDecision::Nothing);
        // Hands-free: long after letting go, still recording.
        assert_eq!(k.expire(ms(t, 5000), true), PttDecision::Nothing);
        assert_eq!(k.press(ms(t, 9000), false, true), PttDecision::Stop);
        // The release of the finishing tap does nothing more.
        assert_eq!(k.release(ms(t, 9080), false), PttDecision::Nothing);
    }

    #[test]
    fn a_single_tap_is_discarded_not_transcribed() {
        let t = Instant::now();
        let mut k = HoldOrDoubleTap::default();
        assert_eq!(k.press(t, true, false), PttDecision::Start);
        assert_eq!(k.release(ms(t, 120), true), PttDecision::Nothing);
        assert_eq!(k.expire(ms(t, 300), true), PttDecision::Nothing);
        assert_eq!(k.expire(ms(t, 480), true), PttDecision::Cancel);
        assert_eq!(k.deadline(), None);
    }

    #[test]
    fn a_slow_second_press_after_a_tap_does_not_turn_on_hands_free() {
        let t = Instant::now();
        let mut k = HoldOrDoubleTap::default();
        k.press(t, true, false);
        k.release(ms(t, 100), true);
        assert_eq!(k.expire(ms(t, 460), true), PttDecision::Cancel);
        // Idle again: the next press is a fresh hold.
        assert_eq!(k.press(ms(t, 600), true, false), PttDecision::Start);
        assert_eq!(k.release(ms(t, 2000), true), PttDecision::Stop);
    }

    /// Initial press plus several synthesized release/press pairs, as X11 emits
    /// while a push-to-talk key is held down.
    fn autorepeat_burst() -> Vec<Ev> {
        let mut events = vec![Ev::Press];
        for _ in 0..6 {
            events.push(Ev::Release);
            events.push(Ev::Press);
        }
        events
    }

    /// Regression for #1539: a burst of X11 auto-repeat release/press pairs must
    /// not stop recording. Before the fix the first synthesized release stopped
    /// recording immediately (stops == 1, stage left Recording), which produced
    /// the rapid on/off toggling. With the fix the releases are coalesced and
    /// recording stays continuously active for the whole burst.
    #[test]
    fn x11_autorepeat_burst_does_not_toggle_recording() {
        let result = simulate(&autorepeat_burst());
        assert_eq!(result.starts, 1, "recording should start exactly once");
        assert_eq!(
            result.stops, 0,
            "synthesized auto-repeat releases must not stop recording mid-burst"
        );
        assert_eq!(
            result.stage,
            SimStage::Recording,
            "recording must remain active across the entire auto-repeat burst"
        );
    }

    /// Complements the burst test: once the key is genuinely released and the
    /// grace window elapses with no re-press, recording stops exactly once. This
    /// proves the debounce only coalesces synthesized releases and does not wedge
    /// the coordinator or swallow the real key-up.
    #[test]
    fn genuine_release_after_grace_stops_recording_once() {
        let mut events = autorepeat_burst();
        events.push(Ev::Release); // genuine key-up
        events.push(Ev::Grace); // grace window elapses, no cancelling press
        let result = simulate(&events);
        assert_eq!(result.starts, 1, "recording should start exactly once");
        assert_eq!(
            result.stops, 1,
            "a genuine release should stop recording exactly once"
        );
        assert_eq!(result.stage, SimStage::Processing);
    }
}
