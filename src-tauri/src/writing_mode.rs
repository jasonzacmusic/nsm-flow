use active_win_pos_rs::get_active_window;
use once_cell::sync::Lazy;
use regex::Regex;
use std::sync::Mutex;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WritingMode {
    AiPrompt,
    Email,
    Messaging,
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

static EXTRA_SPACES: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"[ \t]{2,}").expect("valid whitespace regex"));
static EXTRA_NEWLINES: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"\n{3,}").expect("valid newline regex"));

fn classify(app_name: &str, process_path: &str, title: &str) -> WritingMode {
    let haystack = format!("{app_name} {process_path} {title}").to_lowercase();

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

    let with_paragraphs = NEW_PARAGRAPH.replace_all(transcription, "\n\n");
    let with_lines = NEW_LINE.replace_all(&with_paragraphs, "\n");
    let with_bullets = BULLET_POINT.replace_all(&with_lines, "\n- ");

    let cleaned = with_bullets
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
}
