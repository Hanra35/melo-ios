import Foundation

// MARK: - Track
struct Track: Identifiable, Codable, Equatable {
    var id: String
    var key: String           // B2 object key (path in bucket)
    var name: String
    var artist: String
    var hue: Double
    var imgUrl: String        // cover art URL
    var lrc: String           // LRC lyrics
    var fileId: String        // B2 file ID (for delete)
    var duration: Double?
    var liked: Bool = false

    static func == (lhs: Track, rhs: Track) -> Bool { lhs.id == rhs.id }
}

// MARK: - Playlist
struct Playlist: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var trackIds: [String]
    var isFavoris: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, trackIds
        case isFavoris = "_favoris"
    }

    static func == (lhs: Playlist, rhs: Playlist) -> Bool { lhs.id == rhs.id }
}

// MARK: - Album
struct Album: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var trackIds: [String]
    var imgUrl: String = ""

    static func == (lhs: Album, rhs: Album) -> Bool { lhs.id == rhs.id }
}

// MARK: - Artist
struct Artist: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var hue: Double
    var trackIds: [String]
    var albumIds: [String]

    static func == (lhs: Artist, rhs: Artist) -> Bool { lhs.id == rhs.id }
}

// MARK: - Metadata (synced with B2)
struct MeloMetadata: Codable {
    var tracks: [Track] = []
    var playlists: [Playlist] = []
    var albums: [Album] = []
    var artists: [Artist] = []
    var lastModified: Double = 0
}

// MARK: - LRC Line
struct LRCLine: Identifiable {
    let id = UUID()
    let time: Double   // seconds
    let text: String
}

// MARK: - Helpers
func genId() -> String {
    UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(12).description
}

func trackHue(from name: String) -> Double {
    let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    return Double(sum % 360)
}

func parseLRC(_ lrc: String) -> [LRCLine] {
    let pattern = #"\[(\d+):(\d+\.\d+)\]\s*(.*)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    var lines: [LRCLine] = []
    for rawLine in lrc.components(separatedBy: "\n") {
        let range = NSRange(rawLine.startIndex..., in: rawLine)
        if let match = regex.firstMatch(in: rawLine, range: range) {
            func g(_ i: Int) -> String {
                guard let r = Range(match.range(at: i), in: rawLine) else { return "" }
                return String(rawLine[r])
            }
            let min = Double(g(1)) ?? 0
            let sec = Double(g(2)) ?? 0
            let text = g(3)
            if !text.isEmpty {
                lines.append(LRCLine(time: min * 60 + sec, text: text))
            }
        }
    }
    return lines.sorted { $0.time < $1.time }
}
