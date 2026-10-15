import CoreGraphics
import Foundation

/// Turns a finger path across the letter keys into likely words, in the spirit
/// of Apple's QuickPath: every dictionary word has an ideal path through its key
/// centres; the closest ideal paths, weighted by how common the word is, win.
final class SwipeDecoder {
    struct Entry {
        let word: String      // as it should be typed, e.g. "Konnakol"
        let letters: [Character]
        let logFrequency: Double
    }

    private var byFirstLetter: [Character: [Entry]] = [:]
    private static let samples = 32

    init(wordList: String) {
        let maxCount = 30_000_000.0
        for line in wordList.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard let raw = parts.first else { continue }
            let word = String(raw)
            let letters = Array(word.lowercased().filter { $0.isLetter })
            guard letters.count >= 2 || word.lowercased() == "a" || word.lowercased() == "i",
                  let first = letters.first else { continue }
            let count = parts.count > 1 ? Double(parts[1]) ?? 1 : 1
            let entry = Entry(word: word, letters: letters, logFrequency: log(max(count, 1)) / log(maxCount))
            byFirstLetter[first, default: []].append(entry)
        }
    }

    /// - Parameters:
    ///   - path: touch points in keyboard coordinates.
    ///   - keyCentres: centre of every letter key, lowercase.
    ///   - keyWidth: width of one letter key, used as the distance unit.
    func decode(path: [CGPoint], keyCentres: [Character: CGPoint], keyWidth: CGFloat, limit: Int = 4) -> [String] {
        guard path.count >= 2, keyWidth > 0 else { return [] }
        let userPath = Self.resample(path, count: Self.samples)
        let firsts = Self.nearestKeys(to: path[0], keyCentres: keyCentres, within: keyWidth * 1.1)
        let lastKeys = Self.nearestKeys(to: path[path.count - 1], keyCentres: keyCentres, within: keyWidth * 1.1)
        let lasts = Set(lastKeys)
        let userLength = Self.length(of: path) / keyWidth

        var scored: [(String, Double)] = []
        for first in firsts {
            for entry in byFirstLetter[first] ?? [] {
                guard let last = entry.letters.last, lasts.contains(last) else { continue }
                let centres = Self.collapse(entry.letters).compactMap { keyCentres[$0] }
                guard centres.count >= 1 else { continue }
                let ideal = centres.count == 1 ? [centres[0], centres[0]] : centres
                let idealLength = Self.length(of: ideal) / keyWidth
                // Cheap rejection before the full shape comparison.
                if abs(idealLength - userLength) > max(2.5, idealLength * 0.6) { continue }
                let idealPath = Self.resample(ideal, count: Self.samples)
                var distance = 0.0
                for i in 0..<Self.samples {
                    distance += Double(hypot(idealPath[i].x - userPath[i].x, idealPath[i].y - userPath[i].y))
                }
                distance /= Double(Self.samples) * Double(keyWidth)
                // Every key of the word must be passed reasonably closely.
                if !Self.passesNear(centres, path: path, radius: keyWidth * 0.9) { continue }
                // Lifting the finger is deliberate, so the key under it counts most.
                let endPenalty = last == lastKeys.first ? 0 : 0.2
                let score = distance + endPenalty - 0.55 * entry.logFrequency
                scored.append((entry.word, score))
            }
        }
        scored.sort { $0.1 < $1.1 }
        var seen = Set<String>()
        return scored.compactMap { seen.insert($0.0.lowercased()).inserted ? $0.0 : nil }.prefix(limit).map { $0 }
    }

    private static func collapse(_ letters: [Character]) -> [Character] {
        var out: [Character] = []
        for letter in letters where out.last != letter { out.append(letter) }
        return out
    }

    private static func nearestKeys(to point: CGPoint, keyCentres: [Character: CGPoint], within radius: CGFloat) -> [Character] {
        let sorted = keyCentres.map { ($0.key, hypot($0.value.x - point.x, $0.value.y - point.y)) }.sorted { $0.1 < $1.1 }
        return sorted.prefix(3).filter { $0.1 <= radius || $0.0 == sorted.first?.0 }.map { $0.0 }
    }

    /// The keys must be visited in order along the path.
    private static func passesNear(_ centres: [CGPoint], path: [CGPoint], radius: CGFloat) -> Bool {
        var index = 0
        for centre in centres {
            var found = false
            while index < path.count {
                if hypot(path[index].x - centre.x, path[index].y - centre.y) <= radius {
                    found = true
                    break
                }
                index += 1
            }
            if !found { return false }
        }
        return true
    }

    static func length(of points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    }

    static func resample(_ points: [CGPoint], count: Int) -> [CGPoint] {
        let total = length(of: points)
        guard total > 0, points.count > 1 else { return Array(repeating: points.first ?? .zero, count: count) }
        let step = total / CGFloat(count - 1)
        var result = [points[0]]
        var carried: CGFloat = 0
        var previous = points[0]
        for point in points.dropFirst() {
            var segment = hypot(point.x - previous.x, point.y - previous.y)
            var start = previous
            while segment > 0, carried + segment >= step, result.count < count {
                let t = (step - carried) / segment
                let next = CGPoint(x: start.x + t * (point.x - start.x), y: start.y + t * (point.y - start.y))
                result.append(next)
                start = next
                segment = hypot(point.x - start.x, point.y - start.y)
                carried = 0
            }
            carried += segment
            previous = point
        }
        while result.count < count { result.append(points[points.count - 1]) }
        return result
    }
}
