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
        .filter(|word| !word.is_empty())
        .next_back()
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

fn format_music_notation(text: &str) -> String {
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

    MUSICAL_SIGN
        .replace_all(&with_notes, |captures: &regex::Captures<'_>| {
            accidental_symbol(captures.get(1).expect("musical sign capture").as_str())
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
    let with_music = format_music_notation(&with_bullets);

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
            "Play B♭ major, E♭ minor, F♯4, and C♮."
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
            "Play A♭ major, then sing A♯."
        );
        assert_eq!(
            local_format("const note = 'B flat';", WritingMode::Code),
            "const note = 'B flat';"
        );
    }
}
