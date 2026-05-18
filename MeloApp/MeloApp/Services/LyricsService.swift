import Foundation

class LyricsService {
    static let shared = LyricsService()
    private init() {}

    private let session = URLSession.shared

    // MARK: - Auto-fetch from lrclib.net
    func fetchLyrics(track: String, artist: String) async throws -> String {
        // Try exact match first
        let t = track.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? track
        let a = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? artist

        let exactUrl = URL(string: "https://lrclib.net/api/get?track_name=\(t)&artist_name=\(a)")!
        var req = URLRequest(url: exactUrl)
        req.setValue("MeloApp/1.0 iOS", forHTTPHeaderField: "Lrclib-Client")

        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 200,
           let result = try? JSONDecoder().decode(LRCLibResult.self, from: data),
           let lrc = result.syncedLyrics, !lrc.isEmpty {
            return lrc
        }

        // Fallback to search
        let searchUrl = URL(string: "https://lrclib.net/api/search?q=\(t)+\(a)")!
        var req2 = URLRequest(url: searchUrl)
        req2.setValue("MeloApp/1.0 iOS", forHTTPHeaderField: "Lrclib-Client")
        let (data2, _) = try await session.data(for: req2)
        if let results = try? JSONDecoder().decode([LRCLibResult].self, from: data2),
           let first = results.first,
           let lrc = first.syncedLyrics, !lrc.isEmpty {
            return lrc
        }

        throw LyricsError.notFound
    }
}

struct LRCLibResult: Decodable {
    let syncedLyrics: String?
    let plainLyrics: String?
}

enum LyricsError: LocalizedError {
    case notFound
    var errorDescription: String? { "Paroles introuvables" }
}
