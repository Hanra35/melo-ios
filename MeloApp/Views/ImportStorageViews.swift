import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct ImportView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var isImporting = false
    @State private var uploadItems: [UploadItem] = []
    @State private var isDragging = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Drop zone / Pick button
                    Button {
                        isImporting = true
                    } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.meloAccent.opacity(0.14))
                                    .frame(width: 54, height: 54)
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 26))
                                    .foregroundColor(.meloAccent)
                            }
                            Text("Ajouter des musiques")
                                .font(.system(size: 15, weight: .bold))
                            Text("Appuyez pour parcourir vos fichiers")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text("MP3 · WAV · FLAC · OGG · AAC · M4A")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(34)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isDragging ? Color.meloAccent : Color(UIColor.separator), lineWidth: isDragging ? 2 : 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    // Upload list
                    ForEach(uploadItems) { item in
                        UploadItemView(item: item)
                    }

                    Spacer().frame(height: 80)
                }
                .padding(16)
            }
            .navigationTitle("Importer")
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: audioTypes,
                allowsMultipleSelection: true
            ) { result in
                handleImport(result: result)
            }
        }
        .navigationViewStyle(.stack)
    }

    private var audioTypes: [UTType] {
        [.mp3, .wav, .aiff, UTType(mimeType: "audio/flac") ?? .audio,
         UTType(mimeType: "audio/ogg") ?? .audio, UTType(mimeType: "audio/aac") ?? .audio,
         UTType(mimeType: "audio/m4a") ?? .audio, .audio]
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                uploadFile(url: url)
            }
        case .failure(let error):
            print("Import error: \(error)")
        }
    }

    private func uploadFile(url: URL) {
        let filename = url.lastPathComponent
        let item = UploadItem(id: UUID().uuidString, filename: filename)
        uploadItems.append(item)
        let itemId = item.id

        Task {
            do {
                // Read data (may require security-scoped access)
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let ext = url.pathExtension.lowercased()
                let ct = mimeType(for: ext)

                // Get duration & metadata
                let asset = AVURLAsset(url: url)
                let duration: Double
                if #available(iOS 16, *) {
                    let dur = try await asset.load(.duration)
                    duration = CMTimeGetSeconds(dur)
                } else {
                    duration = CMTimeGetSeconds(asset.duration)
                }

                // Extract ID3 tags
                var trackName = url.deletingPathExtension().lastPathComponent
                var artistName = "Artiste inconnu"
                for format in try await asset.loadMetadata(for: .id3Metadata) {
                    if let key = format.commonKey {
                        let val = try? await format.load(.stringValue)
                        if key == .commonKeyTitle, let v = val { trackName = v }
                        if key == .commonKeyArtist, let v = val { artistName = v }
                    }
                }

                // Update UI
                await MainActor.run {
                    if let idx = uploadItems.firstIndex(where: { $0.id == itemId }) {
                        uploadItems[idx].state = .uploading(progress: 0)
                    }
                }

                // Upload to B2
                let (key, fileId) = try await B2Service.shared.uploadTrack(
                    data: data,
                    filename: filename,
                    contentType: ct
                ) { progress in
                    Task { @MainActor in
                        if let idx = self.uploadItems.firstIndex(where: { $0.id == itemId }) {
                            self.uploadItems[idx].state = .uploading(progress: progress)
                        }
                    }
                }

                // Add to library
                let newTrack = Track(
                    id: genId(),
                    key: key,
                    name: trackName,
                    artist: artistName,
                    hue: trackHue(from: trackName),
                    imgUrl: "",
                    lrc: "",
                    fileId: fileId,
                    duration: duration
                )

                await MainActor.run {
                    library.tracks.insert(newTrack, at: 0)
                    if let idx = uploadItems.firstIndex(where: { $0.id == itemId }) {
                        uploadItems[idx].state = .done
                    }
                }
                await library.save()

            } catch {
                await MainActor.run {
                    if let idx = uploadItems.firstIndex(where: { $0.id == itemId }) {
                        uploadItems[idx].state = .error(error.localizedDescription)
                    }
                }
            }
        }
    }

    private func mimeType(for ext: String) -> String {
        switch ext {
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "flac": return "audio/flac"
        case "ogg": return "audio/ogg"
        case "aac": return "audio/aac"
        case "m4a": return "audio/m4a"
        default: return "audio/mpeg"
        }
    }
}

// MARK: - Upload Item
struct UploadItem: Identifiable {
    let id: String
    let filename: String
    var state: State = .pending

    enum State {
        case pending
        case uploading(progress: Double)
        case done
        case error(String)
    }
}

struct UploadItemView: View {
    let item: UploadItem

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(item.filename)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                stateLabel
            }
            if case .uploading(let progress) = item.state {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color(UIColor.tertiarySystemBackground)).frame(height: 3)
                        RoundedRectangle(cornerRadius: 3).fill(Color.meloAccent)
                            .frame(width: geo.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
    }

    @ViewBuilder var stateLabel: some View {
        switch item.state {
        case .pending:
            Text("En attente").font(.system(size: 12)).foregroundColor(.secondary)
        case .uploading(let p):
            Text("\(Int(p * 100))%").font(.system(size: 12, weight: .semibold)).foregroundColor(.meloAccent)
        case .done:
            Text("✓ Envoyé").font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: "#34C759"))
        case .error(let msg):
            Text(msg).font(.system(size: 11)).foregroundColor(.red).lineLimit(1)
        }
    }
}

// MARK: - Storage View
struct StorageView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var bucketInfo: B2Service.BucketInfo?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Bucket card
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "externaldrive.fill")
                                .foregroundColor(.meloAccent)
                            Text("Bucket Backblaze B2")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            if isLoading {
                                ProgressView().scaleEffect(0.8)
                            } else if let info = bucketInfo {
                                Text("En ligne").font(.system(size: 12)).foregroundColor(Color(hex: "#34C759"))
                            }
                        }

                        if let info = bucketInfo {
                            let usedGB  = Double(info.usedBytes) / 1_000_000_000
                            let limitGB = Double(info.limitBytes) / 1_000_000_000
                            let pct = limitGB > 0 ? usedGB / limitGB : 0

                            HStack(alignment: .bottom, spacing: 4) {
                                Text(String(format: "%.2f", usedGB))
                                    .font(.system(size: 30, weight: .heavy))
                                Text("GB")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 4)
                                Spacer()
                                Text("/ \(String(format: "%.0f", limitGB)) GB")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color(UIColor.tertiarySystemBackground)).frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(pct > 0.9 ? Color.red : pct > 0.7 ? Color.orange : Color.meloAccent)
                                        .frame(width: geo.size.width * pct, height: 8)
                                }
                            }
                            .frame(height: 8)

                            HStack {
                                Text("\(info.fileCount) fichiers").font(.system(size: 12)).foregroundColor(.secondary)
                                Spacer()
                                let freeGB = limitGB - usedGB
                                Text("\(String(format: "%.2f", freeGB)) GB libre").font(.system(size: 12)).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(18)

                    // Library stats
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        statCard(icon: "music.note", value: "\(library.tracks.count)", label: "Titres")
                        statCard(icon: "music.note.list", value: "\(library.playlists.count)", label: "Playlists")
                        statCard(icon: "opticaldisc", value: "\(library.albums.count)", label: "Albums")
                        statCard(icon: "person.2.fill", value: "\(library.artists.count)", label: "Artistes")
                    }

                    // Sync button
                    Button {
                        Task { await library.sync() }
                    } label: {
                        HStack {
                            if library.isSyncing {
                                ProgressView().tint(.white).scaleEffect(0.9)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(library.isSyncing ? "Synchronisation..." : "Synchroniser")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.meloAccent)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .disabled(library.isSyncing)

                    if let err = library.syncError {
                        Text(err).font(.system(size: 13)).foregroundColor(.red)
                    }

                    Spacer().frame(height: 80)
                }
                .padding(16)
            }
            .navigationTitle("Stockage")
            .task {
                await loadBucketInfo()
            }
        }
        .navigationViewStyle(.stack)
    }

    func loadBucketInfo() async {
        isLoading = true
        do {
            bucketInfo = try await B2Service.shared.fetchBucketInfo()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.meloAccent).font(.system(size: 22))
            Text(value).font(.system(size: 24, weight: .heavy))
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}
