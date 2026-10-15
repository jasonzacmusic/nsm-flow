import UIKit

protocol KeyboardViewDelegate: AnyObject {
    func keyboard(_ view: KeyboardView, insert text: String)
    func keyboardDeleteBackward(_ view: KeyboardView, count: Int)
    func keyboardContextBefore(_ view: KeyboardView) -> String
    func keyboardNextInputMode(_ view: KeyboardView)
    func keyboardReturn(_ view: KeyboardView)
    func keyboardMic(_ view: KeyboardView)
    func keyboardModeChanged(_ view: KeyboardView, to mode: WritingMode)
}

enum MicState { case idle, recording, processing, needsAccess }

/// One view draws every key and handles every touch, so a finger can slide
/// across keys for swipe typing.
final class KeyboardView: UIView {
    weak var delegate: KeyboardViewDelegate?

    var showsGlobe = true { didSet { setNeedsLayout() } }
    var shifted = false { didSet { refreshLabels() } }
    var capsLock = false { didSet { refreshLabels() } }
    var mode: WritingMode = .message { didSet { modeButton.setTitle(mode.label, for: .normal) } }
    var micState: MicState = .idle { didSet { refreshMic() } }

    private enum Kind: Equatable {
        case character(String), shift, delete, space, enter, layer, globe
    }

    private struct Key {
        let kind: Kind
        let view: UILabel
        var frame: CGRect = .zero
    }

    private enum Layer { case letters, numbers, symbols }

    private var keySet: Layer = .letters { didSet { buildKeys() } }
    private var keys: [Key] = []
    private let barHeight: CGFloat = 46
    private let modeButton = UIButton(type: .system)
    private let micButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private var suggestionButtons: [UIButton] = []
    private let trail = CAShapeLayer()

    private var decoder: SwipeDecoder?

    // Touch tracking
    private var touchPath: [CGPoint] = []
    private var touchKey: Int?
    private var swiping = false
    private var deleteTimer: Timer?
    private var lastSwipedWord: String?
    private var lastSpaceTap = Date.distantPast

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        backgroundColor = .clear
        setUpBar()
        trail.strokeColor = UIColor.systemPink.withAlphaComponent(0.55).cgColor
        trail.fillColor = UIColor.clear.cgColor
        trail.lineWidth = 7
        trail.lineCap = .round
        trail.lineJoin = .round
        self.layer.addSublayer(trail)
        buildKeys()
        // Load the word list off the main thread so the keyboard appears at once.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let url = Bundle.main.url(forResource: "words", withExtension: "txt"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            let decoder = SwipeDecoder(wordList: text)
            DispatchQueue.main.async { self?.decoder = decoder }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Top bar

    private func setUpBar() {
        modeButton.setTitle(mode.label, for: .normal)
        modeButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        modeButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.mode = self.mode == .message ? .email : .message
            self.delegate?.keyboardModeChanged(self, to: self.mode)
        }, for: .touchUpInside)
        addSubview(modeButton)

        for _ in 0..<3 {
            let button = UIButton(type: .system)
            button.titleLabel?.font = .systemFont(ofSize: 16)
            button.tintColor = .label
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let word = button?.title(for: .normal), !word.isEmpty else { return }
                self.replaceLastSwipe(with: word)
            }, for: .touchUpInside)
            suggestionButtons.append(button)
            addSubview(button)
        }

        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.isHidden = true
        addSubview(statusLabel)

        micButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        micButton.tintColor = .white
        micButton.backgroundColor = .systemPink
        micButton.layer.cornerRadius = 17
        micButton.accessibilityLabel = "Dictate"
        micButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.delegate?.keyboardMic(self)
        }, for: .touchUpInside)
        addSubview(micButton)
    }

    private func refreshMic() {
        let (symbol, colour, status): (String, UIColor, String?) = {
            switch micState {
            case .idle: return ("mic.fill", .systemPink, nil)
            case .recording: return ("stop.fill", .systemRed, "Listening… tap ■ to finish")
            case .processing: return ("ellipsis", .systemOrange, "Writing it up…")
            case .needsAccess: return ("mic.slash", .systemGray, "Turn on Allow Full Access in Settings")
            }
        }()
        micButton.setImage(UIImage(systemName: symbol), for: .normal)
        micButton.backgroundColor = colour
        statusLabel.text = status
        statusLabel.isHidden = status == nil
        suggestionButtons.forEach { $0.isHidden = status != nil }
    }

    private func showSuggestions(_ words: [String]) {
        for (index, button) in suggestionButtons.enumerated() {
            button.setTitle(index < words.count ? words[index] : nil, for: .normal)
        }
    }

    // MARK: Keys

    private func rows() -> [[Kind]] {
        let chars: (String) -> [Kind] = { $0.map { Kind.character(String($0)) } }
        var bottom: [Kind] = [.layer]
        if showsGlobe { bottom.append(.globe) }
        bottom += [.space, .enter]
        switch keySet {
        case .letters:
            return [chars("qwertyuiop"), chars("asdfghjkl"), [.shift] + chars("zxcvbnm") + [.delete], bottom]
        case .numbers:
            return [chars("1234567890"), chars("-/:;()₹&@\""), [.shift] + chars(".,?!'") + [.delete], bottom]
        case .symbols:
            return [chars("[]{}#%^*+="), chars("_\\|~<>$€£•"), [.shift] + chars(".,?!'") + [.delete], bottom]
        }
    }

    private func buildKeys() {
        keys.forEach { $0.view.removeFromSuperview() }
        keys = rows().flatMap { $0 }.map { kind in
            let label = UILabel()
            label.textAlignment = .center
            label.layer.cornerRadius = 5
            label.layer.masksToBounds = true
            label.isUserInteractionEnabled = false
            addSubview(label)
            return Key(kind: kind, view: label)
        }
        refreshLabels()
        setNeedsLayout()
    }

    private func refreshLabels() {
        let upper = shifted || capsLock
        for key in keys {
            let label = key.view
            let isSpecial: Bool
            switch key.kind {
            case .character(let c):
                label.text = keySet == .letters && upper ? c.uppercased() : c
                label.font = .systemFont(ofSize: 23)
                isSpecial = false
            case .shift:
                label.text = keySet == .letters ? (capsLock ? "⇪" : "⇧") : (keySet == .numbers ? "#+=" : "123")
                label.font = .systemFont(ofSize: keySet == .letters ? 20 : 15)
                isSpecial = true
            case .delete:
                label.text = "⌫"; label.font = .systemFont(ofSize: 20); isSpecial = true
            case .space:
                label.text = "space"; label.font = .systemFont(ofSize: 16); isSpecial = false
            case .enter:
                label.text = "return"; label.font = .systemFont(ofSize: 16); isSpecial = true
            case .layer:
                label.text = keySet == .letters ? "123" : "ABC"; label.font = .systemFont(ofSize: 16); isSpecial = true
            case .globe:
                label.text = "🌐"; label.font = .systemFont(ofSize: 18); isSpecial = true
            }
            let active = key.kind == .shift && keySet == .letters && upper
            label.backgroundColor = active ? .white : (isSpecial ? Self.specialKeyColour : Self.keyColour)
            label.textColor = active ? .black : .label
        }
    }

    static let keyColour = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white }
    static let specialKeyColour = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.27, alpha: 1) : UIColor(white: 0.68, alpha: 1) }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        modeButton.frame = CGRect(x: 6, y: 6, width: 76, height: 34)
        micButton.frame = CGRect(x: width - 58, y: 6, width: 52, height: 34)
        let middle = CGRect(x: 88, y: 6, width: width - 152, height: 34)
        statusLabel.frame = middle
        let slot = middle.width / 3
        for (index, button) in suggestionButtons.enumerated() {
            button.frame = CGRect(x: middle.minX + CGFloat(index) * slot, y: middle.minY, width: slot, height: middle.height)
        }

        let rowSet = rows()
        let gap: CGFloat = 6
        let rowHeight = (bounds.height - barHeight - 4) / CGFloat(rowSet.count)
        let unit = (width - gap) / 10   // one letter key plus its gap
        var index = 0
        for (rowIndex, row) in rowSet.enumerated() {
            let y = barHeight + CGFloat(rowIndex) * rowHeight
            let widths: [CGFloat] = row.map { kind in
                switch kind {
                case .character: return rowIndex == 2 && keySet != .letters ? unit * 1.4 : unit
                case .shift, .delete: return unit * 1.35
                case .space: return .nan
                case .enter: return unit * 2
                case .layer, .globe: return unit * 1.25
                }
            }
            let fixed = widths.filter { !$0.isNaN }.reduce(0, +)
            let flexible = max(unit, width - gap - fixed)
            let rowWidth = widths.map { $0.isNaN ? flexible : $0 }.reduce(0, +)
            var x = (width - rowWidth) / 2
            if rowIndex == 2 && row.first == .shift {
                x = gap / 2
            }
            for (column, kind) in row.enumerated() {
                var w = widths[column].isNaN ? flexible : widths[column]
                if rowIndex == 2, kind == .delete { x = width - gap / 2 - w }
                if rowIndex == 2, kind == .shift { w = unit * 1.35 }
                let frame = CGRect(x: x, y: y, width: w, height: rowHeight)
                keys[index].frame = frame
                keys[index].view.frame = frame.insetBy(dx: gap / 2, dy: 5)
                x += w
                if rowIndex == 2, kind == .shift {
                    // Centre the letters between shift and delete.
                    let letters = row.filter { if case .character = $0 { return true } else { return false } }
                    let lettersWidth = CGFloat(letters.count) * (keySet == .letters ? unit : unit * 1.4)
                    x = (width - lettersWidth) / 2
                }
                index += 1
            }
        }
        trail.frame = bounds
    }

    // MARK: Touches

    private func keyIndex(at point: CGPoint) -> Int? {
        if let hit = keys.firstIndex(where: { $0.frame.contains(point) }) { return hit }
        // Points between keys go to the nearest key in the keyboard area.
        guard point.y > barHeight else { return nil }
        return keys.indices.min {
            hypot(keys[$0].frame.midX - point.x, keys[$0].frame.midY - point.y)
                < hypot(keys[$1].frame.midX - point.x, keys[$1].frame.midY - point.y)
        }
    }

    private var letterKeyWidth: CGFloat {
        keys.first { if case .character = $0.kind { return true } else { return false } }?.frame.width ?? 1
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), let index = keyIndex(at: point) else { return }
        touchPath = [point]
        touchKey = index
        swiping = false
        highlight(index, on: true)
        if keys[index].kind == .delete {
            deleteBackward()
            deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                self?.deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                    self?.delegate.map { $0.keyboardDeleteBackward(self!, count: 1) }
                }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), let start = touchKey else { return }
        touchPath.append(point)
        guard keySet == .letters, case .character = keys[start].kind else { return }
        if !swiping, SwipeDecoder.length(of: touchPath) > letterKeyWidth * 0.9 {
            swiping = true
            highlight(start, on: false)
        }
        if swiping {
            let path = UIBezierPath()
            path.move(to: touchPath[0])
            touchPath.dropFirst().forEach { path.addLine(to: $0) }
            trail.path = path.cgPath
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        deleteTimer?.invalidate()
        deleteTimer = nil
        trail.path = nil
        guard let start = touchKey else { return }
        touchKey = nil
        highlight(start, on: false)
        if swiping {
            finishSwipe()
        } else {
            tap(keys[start].kind)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        deleteTimer?.invalidate()
        deleteTimer = nil
        trail.path = nil
        if let start = touchKey { highlight(start, on: false) }
        touchKey = nil
    }

    private func highlight(_ index: Int, on: Bool) {
        guard case .character = keys[index].kind else { return }
        keys[index].view.backgroundColor = on ? Self.specialKeyColour : Self.keyColour
    }

    private func tap(_ kind: Kind) {
        guard let delegate else { return }
        switch kind {
        case .character(var c):
            if keySet == .letters && (shifted || capsLock) { c = c.uppercased() }
            delegate.keyboard(self, insert: c)
            lastSwipedWord = nil
            if shifted && !capsLock { shifted = false }
        case .space:
            let before = delegate.keyboardContextBefore(self)
            // Double space ends the sentence, as on the Apple keyboard.
            if Date().timeIntervalSince(lastSpaceTap) < 0.4, before.hasSuffix(" "),
               let last = before.dropLast().last, last.isLetter || last.isNumber {
                delegate.keyboardDeleteBackward(self, count: 1)
                delegate.keyboard(self, insert: ". ")
                shifted = true
            } else {
                delegate.keyboard(self, insert: " ")
            }
            lastSpaceTap = Date()
            lastSwipedWord = nil
        case .enter:
            delegate.keyboardReturn(self)
            lastSwipedWord = nil
        case .shift:
            switch keySet {
            case .letters:
                if Date().timeIntervalSince(lastShiftTap) < 0.3 { capsLock = true; shifted = true }
                else if capsLock { capsLock = false; shifted = false }
                else { shifted.toggle() }
                lastShiftTap = Date()
            case .numbers: keySet = .symbols
            case .symbols: keySet = .numbers
            }
        case .delete:
            break // handled on touch down
        case .layer:
            keySet = keySet == .letters ? .numbers : .letters
        case .globe:
            delegate.keyboardNextInputMode(self)
        }
    }

    private var lastShiftTap = Date.distantPast

    private func deleteBackward() {
        if let word = lastSwipedWord {
            // Like QuickPath, one delete removes the whole swiped word.
            delegate?.keyboardDeleteBackward(self, count: word.count)
            lastSwipedWord = nil
            showSuggestions([])
        } else {
            delegate?.keyboardDeleteBackward(self, count: 1)
        }
    }

    private func finishSwipe() {
        guard let delegate, let decoder else { return }
        var centres: [Character: CGPoint] = [:]
        for key in keys {
            if case .character(let c) = key.kind, let letter = c.first {
                centres[letter] = CGPoint(x: key.frame.midX, y: key.frame.midY)
            }
        }
        let words = decoder.decode(path: touchPath, keyCentres: centres, keyWidth: letterKeyWidth)
        guard var word = words.first else { return }
        let before = delegate.keyboardContextBefore(self)
        if shifted || capsLock { word = capsLock ? word.uppercased() : word.prefix(1).uppercased() + word.dropFirst() }
        let space = before.isEmpty || before.hasSuffix(" ") || before.hasSuffix("\n") ? "" : " "
        delegate.keyboard(self, insert: space + word)
        lastSwipedWord = word
        if shifted && !capsLock { shifted = false }
        showSuggestions(Array(words.dropFirst()))
    }

    private func replaceLastSwipe(with word: String) {
        guard let delegate, let current = lastSwipedWord else { return }
        delegate.keyboardDeleteBackward(self, count: current.count)
        let replacement = current.first?.isUppercase == true ? word.prefix(1).uppercased() + word.dropFirst() : word
        delegate.keyboard(self, insert: replacement)
        lastSwipedWord = replacement
        showSuggestions([])
    }
}
