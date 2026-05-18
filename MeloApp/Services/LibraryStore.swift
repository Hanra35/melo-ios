import SwiftUI
import Combine

@MainActor
class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    // MARK: - Published
    @Published var tracks: [Track] = []
    @Published var playlists: [Playlist] = []
    @Published var albums: [Album] = []
    @Published var artists: [Artist] = []
    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var lastSyncDate: Date?

    // Sort
    @Published var sortMode: SortMode = .recent

    enum SortMode: String, CaseIterable {
        case recent = "Récents"
        case nameAZ = "A → Z"
        case artist = "Artiste"
    }

    private init() {
        loadLocal()
    }

    // MARK: - Computed
    var sortedTracks: [Track] {
        switch sortMode {
        case .recent:   return tracks
        case .nameAZ:   return tracks.sorted { $0.name < $1.name }
        case .artist:   return tracks.sorted { $0.artist < $1.artist }
        }
    }

    var favorisPlaylist: Playlist? { playlists.first { $0.isFavoris } }

    func tracks(for playlist: Playlist) -> [Track] {
        playlist.trackIds.compactMap { id in tracks.first { $0.id == id } }
    }

    func tracks(for album: Album) -> [Track] {
        album.trackIds.compactMap { id in tracks.first { $0.id == id } }
    }

    func tracks(for artist: Artist) -> [Track] {
        artist.trackIds.compactMap { id in tracks.first { $0.id == id } }
    }

    func albums(for artist: Artist) -> [Album] {
        artist.albumIds.compactMap { id in albums.first { $0.id == id } }
    }

    func isLiked(_ track: Track) -> Bool {
        favorisPlaylist?.trackIds.contains(track.id) ?? false
    }

    // MARK: - Sync with B2
    func sync() async {
        isSyncing = true
        syncError = nil
        do {
            let meta = try await B2Service.shared.fetchMetadata()
            // Merge: remote wins for metadata
            tracks = meta.tracks
            playlists = ensureFavoris(meta.playlists)
            albums = meta.albums
            artists = meta.artists
            saveLocal()
            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
        }
        isSyncing = false
    }

    func save() async {
        isSyncing = true
        do {
            var meta = MeloMetadata()
            meta.tracks = tracks
            meta.playlists = playlists
            meta.albums = albums
            meta.artists = artists
            meta.lastModified = Date().timeIntervalSince1970
            try await B2Service.shared.saveMetadata(meta)
            saveLocal()
        } catch {
            syncError = error.localizedDescription
        }
        isSyncing = false
    }

    // MARK: - Local persistence
    private let localMetaKey = "melo_local_meta"

    func saveLocal() {
        var meta = MeloMetadata()
        meta.tracks = tracks
        meta.playlists = playlists
        meta.albums = albums
        meta.artists = artists
        if let data = try? JSONEncoder().encode(meta) {
            UserDefaults.standard.set(data, forKey: localMetaKey)
        }
    }

    func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: localMetaKey),
              let meta = try? JSONDecoder().decode(MeloMetadata.self, from: data) else { return }
        tracks = meta.tracks
        playlists = ensureFavoris(meta.playlists)
        albums = meta.albums
        artists = meta.artists
    }

    private func ensureFavoris(_ pls: [Playlist]) -> [Playlist] {
        if pls.contains(where: { $0.isFavoris }) { return pls }
        var result = pls
        result.insert(Playlist(id: genId(), name: "Favoris", trackIds: [], isFavoris: true), at: 0)
        return result
    }

    // MARK: - Mutations
    func toggleLike(_ track: Track) {
        guard let idx = playlists.firstIndex(where: { $0.isFavoris }) else { return }
        let tid = track.id
        if playlists[idx].trackIds.contains(tid) {
            playlists[idx].trackIds.removeAll { $0 == tid }
        } else {
            playlists[idx].trackIds.append(tid)
        }
        Task { await save() }
    }

    func addPlaylist(name: String) {
        playlists.append(Playlist(id: genId(), name: name, trackIds: []))
        Task { await save() }
    }

    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        Task { await save() }
    }

    func addTrack(_ trackId: String, to playlist: Playlist) {
        guard let idx = playlists.firstIndex(of: playlist) else { return }
        if !playlists[idx].trackIds.contains(trackId) {
            playlists[idx].trackIds.append(trackId)
        }
        Task { await save() }
    }

    func removeTrack(_ trackId: String, from playlist: Playlist) {
        guard let idx = playlists.firstIndex(of: playlist) else { return }
        playlists[idx].trackIds.removeAll { $0 == trackId }
        Task { await save() }
    }

    func addAlbum(name: String) {
        albums.append(Album(id: genId(), name: name, trackIds: []))
        Task { await save() }
    }

    func addArtist(name: String) {
        artists.append(Artist(id: genId(), name: name, hue: trackHue(from: name), trackIds: [], albumIds: []))
        Task { await save() }
    }

    func deleteTrack(_ track: Track) async {
        // Delete from B2
        try? await B2Service.shared.deleteTrack(key: track.key, fileId: track.fileId)
        // Remove from library
        tracks.removeAll { $0.id == track.id }
        playlists.indices.forEach { playlists[$0].trackIds.removeAll { $0 == track.id } }
        albums.indices.forEach { albums[$0].trackIds.removeAll { $0 == track.id } }
        artists.indices.forEach { artists[$0].trackIds.removeAll { $0 == track.id } }
        await save()
    }

    func updateLyrics(_ lrc: String, for trackId: String) {
        guard let idx = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        tracks[idx].lrc = lrc
        Task { await save() }
    }

    func search(_ query: String) -> [Track] {
        guard !query.isEmpty else { return sortedTracks }
        let q = query.lowercased()
        return tracks.filter { $0.name.lowercased().contains(q) || $0.artist.lowercased().contains(q) }
    }
}
