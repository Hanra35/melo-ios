import SwiftUI

// MARK: - Playlists Screen
struct PlaylistsView: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var player: PlayerService
    @State private var showNewPlaylist = false
    @State private var newName = ""

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(library.playlists) { pl in
                        NavigationLink(destination: PlaylistDetailView(playlist: pl)) {
                            PlaylistBigCardView(playlist: pl)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .padding(.bottom, 140)
            }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewPlaylist = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Nouvelle playlist", isPresented: $showNewPlaylist) {
                TextField("Nom...", text: $newName)
                Button("Créer") {
                    if !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                        library.addPlaylist(name: newName)
                        newName = ""
                    }
                }
                Button("Annuler", role: .cancel) { newName = "" }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct PlaylistBigCardView: View {
    let playlist: Playlist
    @EnvironmentObject var library: LibraryStore

    var coverTracks: [Track] { playlist.trackIds.prefix(4).compactMap { id in library.tracks.first { $0.id == id } } }

    var body: some View {
        HStack(spacing: 14) {
            // Art
            ZStack {
                if coverTracks.count >= 4 {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                        ForEach(coverTracks, id: \.id) { t in
                            TrackArtView(track: t, size: 28, cornerRadius: 0)
                        }
                    }
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if let first = coverTracks.first {
                    TrackArtView(track: first, size: 58, cornerRadius: 12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.tertiarySystemBackground))
                        .frame(width: 58, height: 58)
                        .overlay(Image(systemName: playlist.isFavoris ? "heart.fill" : "music.note.list")
                            .foregroundColor(playlist.isFavoris ? .red : .secondary))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("\(playlist.trackIds.count) titres")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 13))
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
    }
}

// MARK: - Playlist Detail
struct PlaylistDetailView: View {
    @State var playlist: Playlist
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var player: PlayerService

    var tracks: [Track] { library.tracks(for: playlist) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero
                HStack(spacing: 16) {
                    // Art 88x88
                    let coverTracks = playlist.trackIds.prefix(4).compactMap { id in library.tracks.first { $0.id == id } }
                    ZStack {
                        if coverTracks.count >= 4 {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 1) {
                                ForEach(coverTracks, id: \.id) { t in
                                    TrackArtView(track: t, size: 43, cornerRadius: 0)
                                }
                            }
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else if let first = coverTracks.first {
                            TrackArtView(track: first, size: 88, cornerRadius: 16)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(width: 88, height: 88)
                        }
                    }
                    .shadow(color: .black.opacity(0.25), radius: 8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(playlist.name)
                            .font(.system(size: 20, weight: .heavy))
                        Text("\(playlist.trackIds.count) titres")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        if !tracks.isEmpty {
                            Button {
                                player.play(track: tracks[0], in: tracks)
                            } label: {
                                Label("Lire", systemImage: "play.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 9)
                                    .background(Color.meloAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 10)
                        }
                    }
                }
                .padding(14)

                // Tracks
                LazyVStack(spacing: 0) {
                    ForEach(tracks) { track in
                        TrackRowView(track: track, isActive: player.currentTrack?.id == track.id) {
                            player.play(track: track, in: tracks)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 140)
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Artists Screen
struct ArtistsView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var searchText = ""
    @State private var showNewArtist = false
    @State private var newName = ""

    var filtered: [Artist] {
        if searchText.isEmpty { return library.artists }
        return library.artists.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Rechercher un artiste...", text: $searchText).textFieldStyle(.plain)
                    }
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)

                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { artist in
                            NavigationLink(destination: ArtistDetailView(artist: artist)) {
                                ArtistCardView(artist: artist)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 140)
                }
            }
            .navigationTitle("Artistes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewArtist = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Nouvel artiste", isPresented: $showNewArtist) {
                TextField("Nom...", text: $newName)
                Button("Créer") {
                    if !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                        library.addArtist(name: newName)
                        newName = ""
                    }
                }
                Button("Annuler", role: .cancel) { newName = "" }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct ArtistCardView: View {
    let artist: Artist
    @EnvironmentObject var library: LibraryStore

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hue: artist.hue))
                    .frame(width: 60, height: 60)
                Text(String(artist.name.prefix(2)).uppercased())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(artist.name).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text("\(artist.trackIds.count) titres • \(artist.albumIds.count) albums")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right").foregroundColor(.secondary).font(.system(size: 13))
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
    }
}

// MARK: - Artist Detail
struct ArtistDetailView: View {
    let artist: Artist
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var player: PlayerService

    var tracks: [Track] { library.tracks(for: artist) }
    var albums: [Album] { library.albums(for: artist) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero avatar
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(hue: artist.hue)).frame(width: 100, height: 100)
                            .shadow(color: Color(hue: artist.hue).opacity(0.4), radius: 16)
                        Text(String(artist.name.prefix(2)).uppercased())
                            .font(.system(size: 38, weight: .bold)).foregroundColor(.white)
                    }
                    Text(artist.name).font(.system(size: 22, weight: .heavy))
                    Text("\(artist.trackIds.count) titres").font(.system(size: 13)).foregroundColor(.secondary)

                    if !tracks.isEmpty {
                        HStack(spacing: 10) {
                            Button {
                                player.play(track: tracks[0], in: tracks)
                            } label: {
                                Label("Lire", systemImage: "play.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.meloAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 20)

                // Albums
                if !albums.isEmpty {
                    HStack {
                        Text("Albums").font(.system(size: 16, weight: .bold)).padding(.leading, 14)
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 13) {
                            ForEach(albums) { album in
                                NavigationLink(destination: AlbumDetailView(album: album)) {
                                    PlaylistCardView(playlist: Playlist(id: album.id, name: album.name, trackIds: album.trackIds))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                    .padding(.bottom, 8)
                }

                // Tracks
                HStack {
                    Text("Titres").font(.system(size: 16, weight: .bold)).padding(.leading, 14)
                    Spacer()
                }
                .padding(.vertical, 8)

                LazyVStack(spacing: 0) {
                    ForEach(tracks) { track in
                        TrackRowView(track: track, isActive: player.currentTrack?.id == track.id) {
                            player.play(track: track, in: tracks)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 140)
            }
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Album Detail
struct AlbumDetailView: View {
    let album: Album
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var player: PlayerService

    var tracks: [Track] { library.tracks(for: album) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero
                HStack(spacing: 16) {
                    let coverTracks = album.trackIds.prefix(4).compactMap { id in library.tracks.first { $0.id == id } }
                    ZStack {
                        if coverTracks.count >= 4 {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                                ForEach(coverTracks, id: \.id) { t in
                                    TrackArtView(track: t, size: 43, cornerRadius: 0)
                                }
                            }
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else if let first = coverTracks.first {
                            TrackArtView(track: first, size: 88, cornerRadius: 16)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(width: 88, height: 88)
                        }
                    }
                    .shadow(color: .black.opacity(0.25), radius: 8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(album.name).font(.system(size: 20, weight: .heavy))
                        Text("\(album.trackIds.count) titres").font(.system(size: 12)).foregroundColor(.secondary)
                        if !tracks.isEmpty {
                            Button {
                                player.play(track: tracks[0], in: tracks)
                            } label: {
                                Label("Lire", systemImage: "play.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20).padding(.vertical, 9)
                                    .background(Color.meloAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 10)
                        }
                    }
                }
                .padding(14)

                LazyVStack(spacing: 0) {
                    ForEach(tracks) { track in
                        TrackRowView(track: track, isActive: player.currentTrack?.id == track.id) {
                            player.play(track: track, in: tracks)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 140)
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
