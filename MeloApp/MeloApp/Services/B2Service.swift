import Foundation
import CryptoKit

// MARK: - Configuration
// ⚠️  Change this URL to your Vercel deployment URL
let kAPIBase = "https://mosika-harienintsoa12.vercel.app/"

// Direct B2 constants (for streaming without proxy)
let kB2Endpoint = "https://s3.eu-central-003.backblazeb2.com"
let kBucket     = "melo-music-2026"

// MARK: - B2Service
class B2Service {
    static let shared = B2Service()
    private init() {}

    private let session = URLSession.shared

    // MARK: - Stream URL
    /// Returns the direct B2 URL for streaming (bypasses Vercel proxy)
    func streamURL(for key: String) -> URL {
        // Direct public bucket URL — works if bucket is public or with a download auth token
        let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        return URL(string: "\(kB2Endpoint)/file/\(kBucket)/\(encoded)")!
    }

    /// Proxy URL through Vercel (fallback)
    func proxyStreamURL(for key: String) -> URL {
        let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
        return URL(string: "\(kAPIBase)?action=stream&key=\(encoded)")!
    }

    // MARK: - Fetch Metadata
    func fetchMetadata() async throws -> MeloMetadata {
        let url = URL(string: "\(kAPIBase)?action=load-meta")!
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw B2Error.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoder = JSONDecoder()
        return try decoder.decode(MeloMetadata.self, from: data)
    }

    // MARK: - Save Metadata
    func saveMetadata(_ meta: MeloMetadata) async throws {
        let url = URL(string: "\(kAPIBase)?action=save-meta")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        req.httpBody = try encoder.encode(meta)
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw B2Error.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    // MARK: - Upload Audio File
    func uploadTrack(
        data: Data,
        filename: String,
        contentType: String,
        progress: @escaping (Double) -> Void
    ) async throws -> (key: String, fileId: String) {
        // We upload via multipart to the Vercel proxy which handles B2 auth
        let boundary = "MeloBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let url = URL(string: "\(kAPIBase)?action=upload")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        let disp = "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"
        body.append(disp.data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        // URLSession doesn't natively support upload progress for data tasks
        // Use a delegate-based approach via a small wrapper
        let delegate = UploadDelegate(progress: progress, total: Double(body.count))
        let uploadSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let (respData, response) = try await uploadSession.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw B2Error.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        struct UploadResponse: Decodable { let key: String; let fileId: String }
        let r = try JSONDecoder().decode(UploadResponse.self, from: respData)
        return (r.key, r.fileId)
    }

    // MARK: - Delete Track
    func deleteTrack(key: String, fileId: String) async throws {
        let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
        let f = fileId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileId
        let url = URL(string: "\(kAPIBase)?action=delete&key=\(k)&fileId=\(f)")!
        let (_, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw B2Error.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    // MARK: - Bucket Info
    struct BucketInfo: Decodable {
        let usedBytes: Int64
        let limitBytes: Int64
        let fileCount: Int
    }

    func fetchBucketInfo() async throws -> BucketInfo {
        let url = URL(string: "\(kAPIBase)?action=bucket-info")!
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw B2Error.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(BucketInfo.self, from: data)
    }
}

// MARK: - Upload Delegate (progress tracking)
private class UploadDelegate: NSObject, URLSessionTaskDelegate {
    let progress: (Double) -> Void
    let total: Double
    init(progress: @escaping (Double) -> Void, total: Double) {
        self.progress = progress
        self.total = total
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let p = total > 0 ? Double(totalBytesSent) / total : 0
        DispatchQueue.main.async { self.progress(min(p, 1.0)) }
    }
}

// MARK: - Error
enum B2Error: LocalizedError {
    case httpError(Int)
    case decodingError
    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "Erreur HTTP \(code)"
        case .decodingError: return "Erreur de décodage"
        }
    }
}
