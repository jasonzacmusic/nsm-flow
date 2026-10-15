import Foundation

/// State shared between the NSM Flow app (which owns the microphone) and the
/// keyboard (which cannot record). They talk through the App Group defaults and
/// Darwin notifications, the same arrangement Wispr Flow's iOS keyboard uses.
enum Shared {
    static let appGroup = "group.com.nathanielschool.nsmflow"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    enum Key {
        /// Seconds since 1970, refreshed every second while a session is open.
        static let heartbeat = "sessionHeartbeat"
        static let phase = "flowPhase"
        static let transcript = "latestTranscript"
        static let transcriptID = "latestTranscriptID"
        static let emailSignoff = "emailSignoff"
        static let writingMode = "writingMode"
        static let history = "history"
    }

    enum Note {
        static let start = "com.nathanielschool.nsmflow.start"
        static let stop = "com.nathanielschool.nsmflow.stop"
        static let cancel = "com.nathanielschool.nsmflow.cancel"
        static let phaseChanged = "com.nathanielschool.nsmflow.phase"
        static let done = "com.nathanielschool.nsmflow.done"
    }

    static let defaultSignoff = "Warm regards,\n\nJason Zac\nDirector\nNathaniel School of Music"

    static var emailSignoff: String {
        get { defaults.string(forKey: Key.emailSignoff) ?? defaultSignoff }
        set { defaults.set(newValue, forKey: Key.emailSignoff) }
    }

    static var writingMode: WritingMode {
        get { WritingMode(rawValue: defaults.string(forKey: Key.writingMode) ?? "") ?? .message }
        set { defaults.set(newValue.rawValue, forKey: Key.writingMode) }
    }

    static var phase: FlowPhase {
        get { FlowPhase(rawValue: defaults.string(forKey: Key.phase) ?? "") ?? .off }
        set { defaults.set(newValue.rawValue, forKey: Key.phase) }
    }

    static var sessionIsAlive: Bool {
        let beat = defaults.double(forKey: Key.heartbeat)
        return beat > 0 && Date().timeIntervalSince1970 - beat < 3
    }

    static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString), nil, nil, true)
    }

    /// Every dictation is kept, newest first, so nothing spoken is ever lost.
    static func remember(_ text: String) {
        var items = defaults.stringArray(forKey: Key.history) ?? []
        items.insert(text, at: 0)
        defaults.set(Array(items.prefix(200)), forKey: Key.history)
    }

    static var history: [String] {
        defaults.stringArray(forKey: Key.history) ?? []
    }
}

enum FlowPhase: String {
    case off, ready, recording, processing
}

enum WritingMode: String, CaseIterable {
    case message, email

    var label: String {
        switch self {
        case .message: return "Message"
        case .email: return "Email"
        }
    }
}

/// Calls a closure when a Darwin notification arrives. Darwin notifications
/// carry no payload; the data travels through `Shared.defaults`.
final class DarwinObserver {
    private let name: String
    private let handler: () -> Void

    init(_ name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let me = Unmanaged<DarwinObserver>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { me.handler() }
            },
            name as CFString, nil, .deliverImmediately)
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(name as CFString), nil)
    }
}
