import UIKit

/// The NSM Flow keyboard: tap or swipe to type, and a mic key that dictates
/// through the NSM Flow app (keyboards are not allowed to use the microphone).
final class KeyboardViewController: UIInputViewController {
    private let keyboard = KeyboardView()
    private var observers: [DarwinObserver] = []
    private var lastInsertedID = Shared.defaults.string(forKey: Shared.Key.transcriptID)
    private var heightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        keyboard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboard)
        NSLayoutConstraint.activate([
            keyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboard.topAnchor.constraint(equalTo: view.topAnchor),
            keyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        let height = view.heightAnchor.constraint(equalToConstant: 268)
        height.priority = .defaultHigh
        height.isActive = true
        heightConstraint = height

        keyboard.delegate = self
        observers = [
            DarwinObserver(Shared.Note.phaseChanged) { [weak self] in self?.refreshMic() },
            DarwinObserver(Shared.Note.done) { [weak self] in self?.insertLatestTranscript() },
        ]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyboard.showsGlobe = needsInputModeSwitchKey
        keyboard.mode = Shared.writingMode
        refreshMic()
        updateShift()
        // A dictation that finished while the keyboard was hidden still lands.
        insertLatestTranscript()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateShift()
    }

    private func updateShift() {
        guard !keyboard.capsLock else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let trimmed = before.trimmingCharacters(in: .whitespaces)
        let autocap = textDocumentProxy.autocapitalizationType ?? .sentences
        keyboard.shifted = autocap != .none && (trimmed.isEmpty || trimmed.hasSuffix(".") || trimmed.hasSuffix("?")
            || trimmed.hasSuffix("!") || before.hasSuffix("\n"))
    }

    private func refreshMic() {
        if !hasFullAccess {
            keyboard.micState = .needsAccess
            return
        }
        switch Shared.phase {
        case .recording where Shared.sessionIsAlive: keyboard.micState = .recording
        case .processing where Shared.sessionIsAlive: keyboard.micState = .processing
        default: keyboard.micState = .idle
        }
    }

    private func insertLatestTranscript() {
        guard let id = Shared.defaults.string(forKey: Shared.Key.transcriptID), id != lastInsertedID else { return }
        lastInsertedID = id
        refreshMic()
        guard let text = Shared.defaults.string(forKey: Shared.Key.transcript), !text.isEmpty else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let needsSpace = !(before.isEmpty || before.hasSuffix(" ") || before.hasSuffix("\n"))
        textDocumentProxy.insertText((needsSpace ? " " : "") + text)
    }

    /// Opens the NSM Flow app to start a session. Keyboards have no public way
    /// to open URLs, so this walks the responder chain to the host application,
    /// as other dictation keyboards do.
    private func openHostApp() {
        guard let url = URL(string: "nsmflow://start"),
              let applicationClass = NSClassFromString("UIApplication") else { return }
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        typealias OpenURL = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
        var responder: UIResponder? = self
        while let current = responder {
            if current.isKind(of: applicationClass), current.responds(to: selector),
               let method = current.method(for: selector) {
                let open = unsafeBitCast(method, to: OpenURL.self)
                open(current, selector, url as NSURL, NSDictionary(), nil)
                return
            }
            responder = current.next
        }
    }
}

extension KeyboardViewController: KeyboardViewDelegate {
    func keyboard(_ view: KeyboardView, insert text: String) {
        textDocumentProxy.insertText(text)
    }

    func keyboardDeleteBackward(_ view: KeyboardView, count: Int) {
        for _ in 0..<count { textDocumentProxy.deleteBackward() }
    }

    func keyboardContextBefore(_ view: KeyboardView) -> String {
        textDocumentProxy.documentContextBeforeInput ?? ""
    }

    func keyboardNextInputMode(_ view: KeyboardView) {
        advanceToNextInputMode()
    }

    func keyboardReturn(_ view: KeyboardView) {
        textDocumentProxy.insertText("\n")
    }

    func keyboardMic(_ view: KeyboardView) {
        guard hasFullAccess else { return }
        switch Shared.phase {
        case .recording where Shared.sessionIsAlive:
            keyboard.micState = .processing
            Shared.post(Shared.Note.stop)
        case .processing where Shared.sessionIsAlive:
            break
        default:
            Shared.writingMode = keyboard.mode
            if Shared.sessionIsAlive {
                keyboard.micState = .recording
                Shared.post(Shared.Note.start)
            } else {
                openHostApp()
            }
        }
    }

    func keyboardModeChanged(_ view: KeyboardView, to mode: WritingMode) {
        Shared.writingMode = mode
    }
}
