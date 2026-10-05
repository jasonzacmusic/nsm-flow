use active_win_pos_rs::get_active_window;
use once_cell::sync::Lazy;
use regex::Regex;
use std::sync::Mutex;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WritingMode {
    AiPrompt,
    Email,
    Messaging,
    Music,
    Document,
    Code,
    General,
}

impl WritingMode {
    pub fn prompt_id(self) -> &'static str {
        match self {
            Self::AiPrompt => "nsm_ai_prompt",
            Self::Email => "nsm_email",
            Self::Messaging => "nsm_messaging",
            Self::Music => "nsm_music",
            Self::Document => "nsm_document",
            Self::Code => "nsm_code",
            Self::General => "nsm_general",
        }
    }
}

static LAST_MODE: Lazy<Mutex<WritingMode>> = Lazy::new(|| Mutex::new(WritingMode::General));

static NEW_PARAGRAPH: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)[ \t]*\b(?:new paragraph|next paragraph)\b[ \t,.:;-]*")
        .expect("valid new paragraph regex")
});

static NEW_LINE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)[ \t]*\b(?:new line|next line)\b[ \t,.:;-]*").expect("valid new line regex")
});

static BULLET_POINT: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)[ \t]*\b(?:bullet point|new bullet)\b[ \t,.:;-]*")
        .expect("valid bullet point regex")
});

static EMAIL_SUBJECT_LINE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)^[ \t]*subject[ \t]+line(?:[ \t]+(?:is|colon))?[ \t,.:;-]*")
        .expect("valid email subject regex")
});

/// Spoken Western pitch names are normalized to Unicode accidentals:
/// ♭ U+266D, ♯ U+266F, ♮ U+266E, 𝄫 U+1D12B, and 𝄪 U+1D12A.
///
/// Requiring a note name from A-G keeps normal prose such as "a flat fee" or
/// "a sharp reply" unchanged. An optional numeric octave is joined to the
/// pitch, so "F sharp 4" becomes "F♯4".
static MUSICAL_NOTE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"(?i)\b([a-g])[ \t]+(double[ \t]+flat|double[ \t]+sharp|flat|sharp|natural)(?:[ \t]+(-?\d+))?\b",
    )
    .expect("valid musical note regex")
});

/// Explicit symbol commands work without a note name while remaining safe for
/// ordinary speech: "flat sign" becomes ♭, but "the table is flat" does not.
static MUSICAL_SIGN: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)\b(double[ \t]+flat|double[ \t]+sharp|flat|sharp|natural)[ \t]+sign\b")
        .expect("valid musical sign regex")
});

/// Chord qualities with an extension or an unambiguous quality word are safe
/// to compact in every prose mode. Accidentals have already been normalized by
/// `MUSICAL_NOTE`, so the root can contain a real Unicode accidental.
static CHORD_QUALITY: Lazy<Regex> = Lazy::new(|| {
    // Speech recognizers also produce ordinal words and numerals: "major 7th"
    // must be consumed as one quality before plain-triad formatting runs.
    let seventh = r"(?:seven(?:th)?|7(?:th)?)";
    let upper_extensions = r"(?:seven(?:th)?|7(?:th)?|nine|ninth|9(?:th)?|eleven(?:th)?|11(?:th)?|thirteen(?:th)?|13(?:th)?)";
    let extensions = format!(r"(?:six(?:th)?|6(?:th)?|{upper_extensions})");
    Regex::new(&format!(
        r"(?i)\b([a-g])([♭♯♮𝄫𝄪]?)[ \t]+(half[ \t]+diminished(?:[ \t]+{seventh})?|major[ \t]+{extensions}|minor[ \t]+{extensions}|dominant(?:[ \t]+{upper_extensions})?|diminished(?:[ \t]+{seventh})?|augmented|suspended[ \t]+(?:two|2|four|4)|sus[ \t]+(?:two|2|four|4)|add[ \t]+(?:two|2|four|4|six|6|nine|9|eleven|11|thirteen|13)|power[ \t]+(?:five|5)|{extensions})(?:[ \t]+((?:flat|sharp)[ \t]+(?:five|5|nine|9|eleven|11|thirteen|13)))?(?:[ \t]+chord)?\b",
    ))
    .expect("valid chord quality regex")
});

/// Plain major/minor triads are ambiguous in ordinary prose ("a major
/// problem"), so they are compacted only when the destination or surrounding
/// sentence is clearly musical.
static SIMPLE_TRIAD: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)\b([a-g])([♭♯♮𝄫𝄪]?)[ \t]+(major|minor)(?:[ \t]+chord)?\b")
        .expect("valid simple triad regex")
});

/// Runs after chord-quality compaction. The final separator is captured and
/// restored because Rust regex deliberately has no look-around support.
static SLASH_CHORD: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"\b([A-G](?:[♭♯♮𝄫𝄪])?(?:maj(?:6|7|9|11|13)|m(?:6|7|9|11|13)?|ø7?|°7?|aug|sus[24]|add(?:2|4|6|9|11|13)|[5679]|11|13)?(?:[♭♯](?:5|9|11|13))?)[ \t]+(?:over|slash)[ \t]+([A-G])([♭♯♮𝄫𝄪]?)([ \t]+|[,.;:!?]|$)",
    )
    .expect("valid slash chord regex")
});

static MUSIC_CONTEXT: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"(?i)\b(?:play|practice|sing|hear|write|type|pitch|note|chord|progression|voicing|inversion|cadence|arpeggio|harmony|transpose|key|scale|bar|measure|rehearsal|tempo|metronome|musescore|reaper)\b",
    )
    .expect("valid music context regex")
});

static CHORD_INTENT: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"(?i)\b(?:play|practice|strum|chord|progression|voicing|inversion|cadence|arpeggio|harmony)\b",
    )
    .expect("valid chord intent regex")
});

static SPOKEN_TIME_SIGNATURE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"(?i)\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d+)[ \t]+(two|four|eight|sixteen|2|4|8|16)[ \t]+time\b",
    )
    .expect("valid spoken time signature regex")
});

static PREFIXED_TIME_SIGNATURE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"(?i)\btime[ \t]+signature(?:[ \t]+(?:is|of))?[ \t]+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d+)[ \t]+(two|four|eight|sixteen|2|4|8|16)\b",
    )
    .expect("valid prefixed time signature regex")
});

static TEMPO_NOTE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"(?i)\b(dotted[ \t]+)?(quarter|eighth)[ \t]+note[ \t]+(?:equals|equal[ \t]+to|at)[ \t]+(\d{2,3})\b",
    )
    .expect("valid tempo note regex")
});

static BEATS_PER_MINUTE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)\b(\d{2,3})[ \t]+beats[ \t]+per[ \t]+minute\b")
        .expect("valid beats per minute regex")
});

static EXPLICIT_NOTE_OR_REST_SYMBOL: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)\b(whole|half|quarter|eighth|sixteenth)[ \t]+(note|rest)[ \t]+symbol\b")
        .expect("valid note or rest symbol regex")
});

static EXTRA_SPACES: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"[ \t]{2,}").expect("valid whitespace regex"));
static EXTRA_NEWLINES: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"\n{3,}").expect("valid newline regex"));

fn accidental_symbol(spoken: &str) -> &'static str {
    match spoken
        .to_ascii_lowercase()
        .split_whitespace()
        .collect::<Vec<_>>()
        .as_slice()
    {
        ["flat"] => "♭",
        ["sharp"] => "♯",
        ["natural"] => "♮",
        ["double", "flat"] => "𝄫",
        ["double", "sharp"] => "𝄪",
        _ => "",
    }
}

fn should_format_note(text: &str, captures: &regex::Captures<'_>) -> bool {
    let note_match = captures.get(1).expect("note capture");
    if !note_match.as_str().eq_ignore_ascii_case("a") {
        return true;
    }

    let whole_match = captures.get(0).expect("musical note capture");
    let before = text[..whole_match.start()]
        .split(|character: char| !character.is_alphabetic())
        .rfind(|word| !word.is_empty())
        .unwrap_or("")
        .to_ascii_lowercase();
    let after = text[whole_match.end()..]
        .trim_start_matches(|character: char| {
            character.is_whitespace() || character.is_ascii_punctuation()
        })
        .split(|character: char| !character.is_alphanumeric())
        .find(|word| !word.is_empty())
        .unwrap_or("")
        .to_ascii_lowercase();

    // The note A is also the English article "a". Convert it when the nearby
    // wording is musical, or when the pitch is a standalone item. This avoids
    // damaging ordinary phrases such as "a flat fee" and "a natural ability".
    after.is_empty()
        || [
            "major",
            "minor",
            "chord",
            "scale",
            "key",
            "note",
            "octave",
            "triad",
            "seventh",
            "seven",
            "arpeggio",
            "inversion",
        ]
        .contains(&after.as_str())
        || [
            "play", "sing", "hear", "write", "type", "pitch", "note", "chord", "key", "scale",
        ]
        .contains(&before.as_str())
}

fn spoken_number(spoken: &str) -> &str {
    match spoken.to_ascii_lowercase().as_str() {
        "one" => "1",
        "two" => "2",
        "three" => "3",
        "four" => "4",
        "five" => "5",
        "six" | "sixth" | "6th" => "6",
        "seven" | "seventh" | "7th" => "7",
        "eight" => "8",
        "nine" | "ninth" | "9th" => "9",
        "ten" => "10",
        "eleven" | "eleventh" | "11th" => "11",
        "twelve" => "12",
        "thirteen" | "thirteenth" | "13th" => "13",
        _ => spoken,
    }
}

fn chord_quality_symbol(spoken: &str) -> String {
    let words = spoken
        .to_ascii_lowercase()
        .split_whitespace()
        .map(str::to_owned)
        .collect::<Vec<_>>();
    let word = |index: usize| words.get(index).map(String::as_str);

    match word(0) {
        Some("half") => {
            if words.iter().any(|part| spoken_number(part) == "7") {
                "ø7".to_string()
            } else {
                "ø".to_string()
            }
        }
        Some("major") => word(1)
            .map(|extension| {
                let number = spoken_number(extension);
                if number == "6" {
                    "6".to_string()
                } else {
                    format!("maj{number}")
                }
            })
            .unwrap_or_default(),
        Some("minor") => word(1)
            .map(|extension| format!("m{}", spoken_number(extension)))
            .unwrap_or_else(|| "m".to_string()),
        Some("dominant") => word(1)
            .map(|extension| spoken_number(extension).to_string())
            .unwrap_or_else(|| "7".to_string()),
        Some("diminished") => word(1)
            .map(|extension| format!("°{}", spoken_number(extension)))
            .unwrap_or_else(|| "°".to_string()),
        Some("augmented") => "aug".to_string(),
        Some("suspended" | "sus") => word(1)
            .map(|extension| format!("sus{}", spoken_number(extension)))
            .unwrap_or_else(|| "sus".to_string()),
        Some("add") => word(1)
            .map(|extension| format!("add{}", spoken_number(extension)))
            .unwrap_or_else(|| "add".to_string()),
        Some("power") => "5".to_string(),
        Some(number) => spoken_number(number).to_string(),
        None => String::new(),
    }
}

fn chord_alteration_symbol(spoken: &str) -> String {
    let mut words = spoken.split_whitespace();
    let accidental = match words
        .next()
        .unwrap_or_default()
        .to_ascii_lowercase()
        .as_str()
    {
        "flat" => "♭",
        "sharp" => "♯",
        _ => "",
    };
    let number = words.next().map(spoken_number).unwrap_or_default();
    format!("{accidental}{number}")
}

fn note_or_rest_symbol(duration: &str, kind: &str) -> &'static str {
    match (
        duration.to_ascii_lowercase().as_str(),
        kind.to_ascii_lowercase().as_str(),
    ) {
        ("whole", "note") => "𝅝",
        ("half", "note") => "𝅗𝅥",
        ("quarter", "note") => "𝅘𝅥",
        ("eighth", "note") => "𝅘𝅥𝅮",
        ("sixteenth", "note") => "𝅘𝅥𝅯",
        ("whole", "rest") => "𝄻",
        ("half", "rest") => "𝄼",
        ("quarter", "rest") => "𝄽",
        ("eighth", "rest") => "𝄾",
        ("sixteenth", "rest") => "𝄿",
        _ => "",
    }
}

fn should_compact_triad(text: &str, captures: &regex::Captures<'_>) -> bool {
    let matched = captures.get(0).expect("triad capture");
    if matched
        .as_str()
        .split_whitespace()
        .last()
        .is_some_and(|word| word.eq_ignore_ascii_case("chord"))
    {
        return true;
    }
    let before = &text[..matched.start()];
    let after = &text[matched.end()..];
    let previous_word = before
        .split(|c: char| !c.is_alphabetic())
        .rfind(|word| !word.is_empty())
        .unwrap_or("")
        .to_ascii_lowercase();
    let next_word = after
        .split(|c: char| !c.is_alphabetic())
        .find(|word| !word.is_empty())
        .unwrap_or("")
        .to_ascii_lowercase();
    // Keep the major/minor quality of named keys and scales. A music
    // destination alone cannot distinguish a key question from a chord.
    if ["in", "of", "from", "to", "key", "scale", "tonality"].contains(&previous_word.as_str())
        || ["key", "scale", "tonality"].contains(&next_word.as_str())
    {
        return false;
    }
    if ["over", "slash"].contains(&next_word.as_str()) {
        return true;
    }
    let sentence = before
        .rsplit(['.', '?', '!', ';', '\n'])
        .next()
        .unwrap_or("");
    CHORD_INTENT.is_match(sentence)
}

fn format_music_notation(text: &str, mode: WritingMode) -> String {
    let with_notes = MUSICAL_NOTE.replace_all(text, |captures: &regex::Captures<'_>| {
        if !should_format_note(text, captures) {
            return captures
                .get(0)
                .expect("musical note capture")
                .as_str()
                .to_string();
        }

        let note = captures
            .get(1)
            .expect("note capture")
            .as_str()
            .to_ascii_uppercase();
        let accidental = accidental_symbol(captures.get(2).expect("accidental capture").as_str());
        let octave = captures.get(3).map_or("", |value| value.as_str());
        format!("{note}{accidental}{octave}")
    });

    let with_signs = MUSICAL_SIGN
        .replace_all(&with_notes, |captures: &regex::Captures<'_>| {
            accidental_symbol(captures.get(1).expect("musical sign capture").as_str())
        })
        .to_string();

    let music_context = mode == WritingMode::Music
        || MUSIC_CONTEXT.is_match(text)
        || MUSICAL_NOTE.is_match(text)
        || CHORD_QUALITY.is_match(&with_signs);

    let with_chord_qualities = CHORD_QUALITY
        .replace_all(&with_signs, |captures: &regex::Captures<'_>| {
            let root = captures
                .get(1)
                .expect("chord root capture")
                .as_str()
                .to_ascii_uppercase();
            let accidental = captures.get(2).map_or("", |value| value.as_str());
            let quality =
                chord_quality_symbol(captures.get(3).expect("chord quality capture").as_str());
            let alteration = captures
                .get(4)
                .map(|value| chord_alteration_symbol(value.as_str()))
                .unwrap_or_default();
            format!("{root}{accidental}{quality}{alteration}")
        })
        .to_string();

    let with_triads = if music_context {
        SIMPLE_TRIAD
            .replace_all(&with_chord_qualities, |captures: &regex::Captures<'_>| {
                if !should_compact_triad(&with_chord_qualities, captures) {
                    return captures.get(0).expect("triad capture").as_str().to_string();
                }
                let root = captures
                    .get(1)
                    .expect("triad root capture")
                    .as_str()
                    .to_ascii_uppercase();
                let accidental = captures.get(2).map_or("", |value| value.as_str());
                let quality = if captures
                    .get(3)
                    .expect("triad quality capture")
                    .as_str()
                    .eq_ignore_ascii_case("minor")
                {
                    "m"
                } else {
                    ""
                };
                format!("{root}{accidental}{quality}")
            })
            .to_string()
    } else {
        with_chord_qualities
    };

    let with_slash_chords = if music_context {
        SLASH_CHORD
            .replace_all(&with_triads, |captures: &regex::Captures<'_>| {
                let chord = captures.get(1).expect("slash chord capture").as_str();
                let bass = captures
                    .get(2)
                    .expect("slash bass capture")
                    .as_str()
                    .to_ascii_uppercase();
                let accidental = captures.get(3).map_or("", |value| value.as_str());
                let separator = captures.get(4).map_or("", |value| value.as_str());
                format!("{chord}/{bass}{accidental}{separator}")
            })
            .to_string()
    } else {
        with_triads
    };

    let with_time_signatures = SPOKEN_TIME_SIGNATURE
        .replace_all(&with_slash_chords, |captures: &regex::Captures<'_>| {
            format!(
                "{}/{} time",
                spoken_number(captures.get(1).expect("time signature numerator").as_str()),
                spoken_number(
                    captures
                        .get(2)
                        .expect("time signature denominator")
                        .as_str()
                )
            )
        })
        .to_string();

    let with_prefixed_time_signatures = PREFIXED_TIME_SIGNATURE
        .replace_all(&with_time_signatures, |captures: &regex::Captures<'_>| {
            format!(
                "time signature {}/{}",
                spoken_number(captures.get(1).expect("time signature numerator").as_str()),
                spoken_number(
                    captures
                        .get(2)
                        .expect("time signature denominator")
                        .as_str()
                )
            )
        })
        .to_string();

    let with_tempo = TEMPO_NOTE
        .replace_all(
            &with_prefixed_time_signatures,
            |captures: &regex::Captures<'_>| {
                let symbol = if captures
                    .get(2)
                    .expect("tempo note duration")
                    .as_str()
                    .eq_ignore_ascii_case("quarter")
                {
                    "♩"
                } else {
                    "♪"
                };
                let dot = if captures.get(1).is_some() { "." } else { "" };
                let bpm = captures.get(3).expect("tempo value").as_str();
                format!("{symbol}{dot} = {bpm}")
            },
        )
        .to_string();

    let with_bpm = BEATS_PER_MINUTE
        .replace_all(&with_tempo, |captures: &regex::Captures<'_>| {
            format!("{} BPM", captures.get(1).expect("BPM value").as_str())
        })
        .to_string();

    EXPLICIT_NOTE_OR_REST_SYMBOL
        .replace_all(&with_bpm, |captures: &regex::Captures<'_>| {
            note_or_rest_symbol(
                captures.get(1).expect("duration capture").as_str(),
                captures.get(2).expect("note/rest capture").as_str(),
            )
        })
        .to_string()
}

fn classify(app_name: &str, process_path: &str, title: &str) -> WritingMode {
    let haystack = format!("{app_name} {process_path} {title}").to_lowercase();

    if [
        "reaper",
        "musescore",
        "logic pro",
        "garageband",
        "ableton live",
        "cubase",
        "studio one",
        "pro tools",
        "dorico",
        "sibelius",
        "finale",
        "riff studio",
    ]
    .iter()
    .any(|needle| haystack.contains(needle))
    {
        return WritingMode::Music;
    }

    if [
        "whatsapp",
        "messages",
        "telegram",
        "signal",
        "slack",
        "discord",
        "microsoft teams",
    ]
    .iter()
    .any(|needle| haystack.contains(needle))
    {
        return WritingMode::Messaging;
    }

    if ["gmail", "outlook", "thunderbird", "apple mail", "mail.app"]
        .iter()
        .any(|needle| haystack.contains(needle))
    {
        return WritingMode::Email;
    }

    if [
        "claude",
        "chatgpt",
        "openai codex",
        "codex",
        "cursor",
        "windsurf",
        "antigravity",
        "manus",
    ]
    .iter()
    .any(|needle| haystack.contains(needle))
    {
        return WritingMode::AiPrompt;
    }

    if [
        "terminal",
        "iterm",
        "wezterm",
        "visual studio code",
        "vscode",
        "xcode",
        "android studio",
        "jetbrains",
    ]
    .iter()
    .any(|needle| haystack.contains(needle))
    {
        return WritingMode::Code;
    }

    if [
        "microsoft word",
        "pages",
        "notion",
        "notes",
        "google docs",
        "libreoffice",
    ]
    .iter()
    .any(|needle| haystack.contains(needle))
    {
        return WritingMode::Document;
    }

    WritingMode::General
}

pub fn capture_active_writing_mode() {
    let mode = get_active_window()
        .map(|window| {
            classify(
                &window.app_name,
                window.process_path.to_string_lossy().as_ref(),
                &window.title,
            )
        })
        .unwrap_or(WritingMode::General);

    match LAST_MODE.lock() {
        Ok(mut current) => *current = mode,
        Err(poisoned) => *poisoned.into_inner() = mode,
    }

    log::debug!("Captured app-aware writing mode: {:?}", mode);
}

pub fn current_writing_mode() -> WritingMode {
    match LAST_MODE.lock() {
        Ok(current) => *current,
        Err(poisoned) => *poisoned.into_inner(),
    }
}

pub fn resolve_prompt_id(selected_prompt_id: Option<&str>, mode: WritingMode) -> &str {
    match selected_prompt_id {
        Some("nsm_smart") | None => mode.prompt_id(),
        Some(id) => id,
    }
}

/// Safe local cleanup used when no LLM is configured. It only applies explicit
/// spoken formatting commands and whitespace normalization; it never invents
/// content or uploads text.
pub fn local_format(transcription: &str, mode: WritingMode) -> String {
    if mode == WritingMode::Code {
        return transcription.trim().to_string();
    }

    let with_email_subject = if mode == WritingMode::Email {
        EMAIL_SUBJECT_LINE
            .replace(transcription, "Subject: ")
            .to_string()
    } else {
        transcription.to_string()
    };
    let with_paragraphs = NEW_PARAGRAPH.replace_all(&with_email_subject, "\n\n");
    let with_lines = NEW_LINE.replace_all(&with_paragraphs, "\n");
    let with_bullets = BULLET_POINT.replace_all(&with_lines, "\n- ");
    let with_music = format_music_notation(&with_bullets, mode);

    let cleaned = with_music
        .lines()
        .map(|line| EXTRA_SPACES.replace_all(line.trim(), " "))
        .collect::<Vec<_>>()
        .join("\n")
        .trim()
        .to_string();
    EXTRA_NEWLINES.replace_all(&cleaned, "\n\n").to_string()
}

#[cfg(test)]
mod tests {
    use super::{classify, local_format, resolve_prompt_id, WritingMode};

    #[test]
    fn recognises_nsm_work_contexts() {
        assert_eq!(classify("Claude", "", ""), WritingMode::AiPrompt);
        assert_eq!(
            classify("Google Chrome", "", "WhatsApp"),
            WritingMode::Messaging
        );
        assert_eq!(classify("Microsoft Outlook", "", ""), WritingMode::Email);
        assert_eq!(classify("Terminal", "", ""), WritingMode::Code);
        assert_eq!(classify("REAPER", "", ""), WritingMode::Music);
        assert_eq!(
            classify("Google Chrome", "", "MuseScore Studio"),
            WritingMode::Music
        );
    }

    #[test]
    fn smart_prompt_routes_by_mode() {
        assert_eq!(
            resolve_prompt_id(Some("nsm_smart"), WritingMode::Messaging),
            "nsm_messaging"
        );
        assert_eq!(
            resolve_prompt_id(Some("custom_prompt"), WritingMode::Email),
            "custom_prompt"
        );
        assert_eq!(
            resolve_prompt_id(Some("nsm_smart"), WritingMode::Music),
            "nsm_music"
        );
    }

    #[test]
    fn local_cleanup_only_applies_spoken_formatting() {
        assert_eq!(
            local_format(
                "Please send this new paragraph bullet point First item new bullet Second item",
                WritingMode::Document,
            ),
            "Please send this\n\n- First item\n- Second item"
        );
    }

    #[test]
    fn email_subject_command_is_explicit_and_safe() {
        assert_eq!(
            local_format(
                "subject line is July workshop new paragraph Hi Chitra, new paragraph Here are the details.",
                WritingMode::Email,
            ),
            "Subject: July workshop\n\nHi Chitra,\n\nHere are the details."
        );
        assert_eq!(
            local_format(
                "The subject line is difficult to write.",
                WritingMode::Email,
            ),
            "The subject line is difficult to write."
        );
    }

    #[test]
    fn musical_notes_use_real_unicode_accidentals() {
        assert_eq!(
            local_format(
                "Play B flat major, E flat minor, F sharp 4, and C natural.",
                WritingMode::Email,
            ),
            "Play B♭, E♭m, F♯4, and C♮."
        );
        assert_eq!(
            local_format(
                "Resolve C double sharp to D and B double flat to A.",
                WritingMode::Music,
            ),
            "Resolve C𝄪 to D and B𝄫 to A."
        );
    }

    #[test]
    fn explicit_spoken_signs_become_symbols() {
        assert_eq!(
            local_format(
                "Use the flat sign, sharp sign, natural sign, double flat sign, and double sharp sign.",
                WritingMode::Document,
            ),
            "Use the ♭, ♯, ♮, 𝄫, and 𝄪."
        );
    }

    #[test]
    fn musical_formatting_is_context_safe() {
        assert_eq!(
            local_format(
                "A flat fee was fair, and a natural ability helped with the sharp reply.",
                WritingMode::General,
            ),
            "A flat fee was fair, and a natural ability helped with the sharp reply."
        );
        assert_eq!(
            local_format("Play A flat major, then sing A sharp.", WritingMode::Music,),
            "Play A♭, then sing A♯."
        );
        assert_eq!(
            local_format("const note = 'B flat';", WritingMode::Code),
            "const note = 'B flat';"
        );
    }

    #[test]
    fn chord_symbols_cover_core_teaching_language() {
        assert_eq!(
            local_format(
                "Play B flat major seven, E flat minor seven, G dominant seven flat nine, C sharp diminished seven, D half diminished seven, and A augmented.",
                WritingMode::Music,
            ),
            "Play B♭maj7, E♭m7, G7♭9, C♯°7, Dø7, and Aaug."
        );
        assert_eq!(
            local_format(
                "Practice D suspended four, G add nine, A power five, and F sharp minor nine.",
                WritingMode::Messaging,
            ),
            "Practice Dsus4, Gadd9, A5, and F♯m9."
        );
    }

    #[test]
    fn recognizer_ordinals_preserve_chord_quality() {
        assert_eq!(
            local_format(
                "Play C major 7th, F sharp minor 7th and B flat major",
                WritingMode::Music,
            ),
            "Play Cmaj7, F♯m7 and B♭"
        );
        assert_eq!(
            local_format(
                "Play C major seventh, D half diminished 7th, G dominant seventh flat nine, A minor 9th, and F major thirteenth.",
                WritingMode::Music,
            ),
            "Play Cmaj7, Dø7, G7♭9, Am9, and Fmaj13."
        );
    }

    #[test]
    fn classroom_keys_and_scales_keep_major_or_minor() {
        for mode in [
            WritingMode::General,
            WritingMode::Music,
            WritingMode::AiPrompt,
        ] {
            assert_eq!(
                local_format("What is the relative minor of E flat major?", mode),
                "What is the relative minor of E♭ major?"
            );
            assert_eq!(
                local_format("What is the relative major of C sharp minor?", mode),
                "What is the relative major of C♯ minor?"
            );
        }
        assert_eq!(
            local_format(
                "In E flat major, play C major and F sharp minor chords.",
                WritingMode::Music
            ),
            "In E♭ major, play C and F♯m chords."
        );
        assert_eq!(
            local_format(
                "Practice the A minor scale, then play C major chord.",
                WritingMode::Music
            ),
            "Practice the A minor scale, then play C."
        );
    }

    #[test]
    fn slash_chords_keep_the_bass_note_and_accidental() {
        assert_eq!(
            local_format(
                "Play C major over E, G seven over B, and D minor over F sharp.",
                WritingMode::Music,
            ),
            "Play C/E, G7/B, and Dm/F♯."
        );
    }

    #[test]
    fn chord_compaction_stays_safe_in_ordinary_prose() {
        assert_eq!(
            local_format(
                "A major problem caused a minor delay.",
                WritingMode::General,
            ),
            "A major problem caused a minor delay."
        );
        assert_eq!(
            local_format(
                "Please practice C major and A minor before class.",
                WritingMode::Email,
            ),
            "Please practice C and Am before class."
        );
    }

    #[test]
    fn time_tempo_and_rhythm_commands_use_standard_symbols() {
        assert_eq!(
            local_format(
                "Start in six eight time, then use time signature seven four at 120 beats per minute.",
                WritingMode::Music,
            ),
            "Start in 6/8 time, then use time signature 7/4 at 120 BPM."
        );
        assert_eq!(
            local_format(
                "Set dotted quarter note equals 96 and type the quarter note symbol, eighth note symbol, and quarter rest symbol.",
                WritingMode::Music,
            ),
            "Set ♩. = 96 and type the 𝅘𝅥, 𝅘𝅥𝅮, and 𝄽."
        );
    }
}
