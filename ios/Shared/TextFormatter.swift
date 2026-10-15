import Foundation

/// Instant cleanup that runs on every dictation, with or without Apple
/// Intelligence: spoken corrections, filler words, spoken punctuation, music
/// accidentals and the email sign-off. Mirrors the Mac app's local rules.
enum TextFormatter {
    static func clean(_ raw: String) -> String {
        var text = " " + raw.trimmingCharacters(in: .whitespacesAndNewlines) + " "

        // "scratch that" / "delete that" removes the sentence or clause before it.
        let scratch = #"(?i)[^.!?\n]*[,;]?\s*\b(?:scratch that|delete that|strike that)\b[.,!]?"#
        text = text.replacingOccurrences(of: scratch, with: " ", options: .regularExpression)

        text = applyCorrections(text)

        let fillers = #"(?i)(?<=\s)(?:um+|uh+|erm|uhm)[,.]?\s"#
        text = text.replacingOccurrences(of: fillers, with: " ", options: .regularExpression)

        let spoken: [(String, String)] = [
            (#"(?i)\s*\bnew paragraph\b\s*"#, "\n\n"),
            (#"(?i)\s*\bnew line\b\s*"#, "\n"),
            (#"(?i)\s*\bbullet point\b\s*"#, "\n- "),
            (#"(?i)\s+\bquestion mark\b"#, "?"),
            (#"(?i)\s+\bexclamation mark\b"#, "!"),
            (#"(?i)\s+\bfull stop\b"#, "."),
        ]
        for (pattern, replacement) in spoken {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }

        text = musicNotation(text)
        text = text.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #" +([,.!?])"#, with: "$1", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = text.first, first.isLowercase {
            text = first.uppercased() + text.dropFirst()
        }
        return text
    }

    /// "on the twelfth, sorry, the fourteenth" becomes "on the fourteenth" and
    /// "at four, no wait, five" becomes "at five". "Sorry" only counts between
    /// commas, so "I'm sorry to hear" is untouched. Subtler corrections are left
    /// to Apple Intelligence.
    static func applyCorrections(_ text: String) -> String {
        let cue = #"(?i),\s*(?:sorry|no wait|wait no|i mean),\s*|\s+no wait,?\s+"#
        guard let regex = try? NSRegularExpression(pattern: cue) else { return text }
        var text = text
        while let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let cueRange = Range(match.range, in: text) {
            var before = text[..<cueRange.lowerBound].split(separator: " ", omittingEmptySubsequences: false).map(String.init)
            let after = String(text[cueRange.upperBound...])
            let firstAfter = after.split(separator: " ").first.map { $0.lowercased() } ?? ""
            let window = max(0, before.count - 3)
            if let j = before[window...].lastIndex(where: { $0.lowercased() == firstAfter }) {
                before.removeSubrange(j...)
            } else if !before.isEmpty {
                before.removeLast()
            }
            text = before.joined(separator: " ") + " " + after
        }
        return text
    }

    /// "B flat" becomes B♭. The note A is only converted when the next word is
    /// musical, so "a flat fee" and "a payment" stay as they are.
    static func musicNotation(_ text: String) -> String {
        var text = text
        let symbols: [(String, String)] = [
            ("double flat", "𝄫"), ("double sharp", "𝄪"), ("flat", "♭"), ("sharp", "♯"), ("natural", "♮"),
        ]
        for (word, symbol) in symbols {
            text = text.replacingOccurrences(
                of: #"\b([B-G])\s+"# + word + #"\b"#, with: "$1" + symbol, options: .regularExpression)
            text = text.replacingOccurrences(
                of: #"\bA\s+"# + word + #"\b(?=\s+(?:major|minor|chord|scale|key|note|seventh|7))"#,
                with: "A" + symbol, options: .regularExpression)
        }
        return text
    }

    static func withSignoff(_ text: String, mode: WritingMode) -> String {
        let signoff = Shared.emailSignoff.trimmingCharacters(in: .whitespacesAndNewlines)
        guard mode == .email, !signoff.isEmpty, !text.isEmpty else { return text }
        let firstLine = signoff.components(separatedBy: "\n").first ?? signoff
        if text.localizedCaseInsensitiveContains(firstLine) { return text }
        return text + "\n\n" + signoff
    }
}
