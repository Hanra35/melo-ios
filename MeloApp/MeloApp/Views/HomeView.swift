import SwiftUI

struct HomeView: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var player: PlayerService
    @State private var selectedTab: HomeTab = .overview
    @State private var searchText = ""
    @State private var showSortMenu = false

    enum HomeTab: String, CaseIterable {
        case overview = "Accueil"
        case tracks   = "Titres"
        case albums   = "Albums"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Melo")
                        .font(.system(size: 28, weight: .heavy))
                    Spacer()
                    Button { library.sortMode = library.sortMode == .nameAZ ? .recent : .nameAZ } label: {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    NavigationLink(destination: ImportView()) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(HomeTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                            } label: {
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 7)
                                    .background(selectedTab == tab ? Color.meloAccent : Color.clear)
                                    .foregroundColor(selectedTab == tab ? .white : .secondary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }

                // Content
                ScrollView {
                    switch selectedTab {
                    case .overview: overviewContent
                    case .tracks:   tracksContent
                    case .albums:   albumsContent
                    }
                }
                .padding(.bottom, 140) // space for mini player + tab bar
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Overview
    var overviewContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero / Logo
            heroSection

            // Playlists row
            if !library.playlists.filter({ !$0.isFavoris }).isEmpty {
                sectionHeader("Mes playlists", linkLabel: "Tout voir")
                playlistsRow
            }

            // Recent tracks
            HStack {
                Text("Récents")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Button {
                    guard !library.tracks.isEmpty else { return }
                    let shuffled = library.tracks.shuffled()
                    player.play(track: shuffled[0], in: shuffled)
                } label: {
                    Label("Aléatoire", systemImage: "shuffle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.meloAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 10)

            tracksList(library.tracks.prefix(20).map { $0 })
        }
    }

    // MARK: - Tracks
    var tracksContent: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Rechercher un titre, un artiste...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(14)
            .padding(.horizontal, 18)
            .padding(.vertical, 4)

            HStack {
                Text("Tous les titres")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Button {
                    let sorted = library.sortedTracks
                    guard !sorted.isEmpty else { return }
                    let shuffled = sorted.shuffled()
                    player.play(track: shuffled[0], in: shuffled)
                } label: {
                    Label("Aléatoire", systemImage: "shuffle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Color.meloAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Text("\(filteredTracks.count)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Menu {
                    ForEach(LibraryStore.SortMode.allCases, id: \.self) { mode in
                        Button(mode.rawValue) { library.sortMode = mode }
                    }
                } label: {
                    Label(library.sortMode.rawValue, systemImage: "line.3.horizontal.decrease")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            tracksList(filteredTracks)
        }
    }

    var filteredTracks: [Track] {
        library.search(searchText)
    }

    // MARK: - Albums
    var albumsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Albums")
                    .font(.system(size: 17, weight: .bold))
                    .padding(.leading, 20)
                Spacer()
                Button("+ Nouveau") { library.addAlbum(name: "Nouvel album") }
                    .foregroundColor(.meloAccent)
                    .font(.system(size: 13))
                    .padding(.trailing, 20)
            }
            .padding(.vertical, 10)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(library.albums) { album in
                    NavigationLink(destination: AlbumDetailView(album: album)) {
                        AlbumCardView(album: album)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Hero
    var heroSection: some View {
        Group {
            if let track = library.tracks.first {
                // Feature track hero
                ZStack(alignment: .bottomLeading) {
                    TrackArtView(track: track, size: UIScreen.main.bounds.width - 36, cornerRadius: 22)
                    LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                        .cornerRadius(22)
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DERNIER AJOUT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.72))
                                .kerning(1.5)
                            Text(track.name)
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.68))
                        }
                        Spacer()
                        Button {
                            player.play(track: track, in: library.tracks)
                        } label: {
                            ZStack {
                                Circle().fill(Color.meloOrange)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color.meloOrange.opacity(0.45), radius: 8)
                                Image(systemName: "play.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(18)
                }
                .frame(height: 162)
                .padding(.horizontal, 18)
                .padding(.top, 6)
            } else {
                // Empty hero
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.meloAccent.opacity(0.22), lineWidth: 1.5)
                        )
                    VStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.meloAccent)
                        Text("MELO")
                            .font(.system(size: 28, weight: .heavy))
                        Text("STREAMING")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.meloAccent.opacity(0.45))
                            .kerning(3.5)
                    }
                }
                .frame(height: 162)
                .padding(.horizontal, 18)
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Playlists row
    var playlistsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 13) {
                ForEach(library.playlists.filter { !$0.isFavoris }) { pl in
                    NavigationLink(destination: PlaylistDetailView(playlist: pl)) {
                        PlaylistCardView(playlist: pl)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Tracks list
    func tracksList(_ tracks: [Track]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, track in
                TrackRowView(track: track, isActive: player.currentTrack?.id == track.id) {
                    Haptics.impact(.light)
                    player.play(track: track, in: tracks)
                }
            }
        }
        .padding(.horizontal, 14)
    }

    func sectionHeader(_ title: String, linkLabel: String = "") -> some View {
        HStack {
            Text(title).font(.system(size: 17, weight: .bold))
            Spacer()
            if !linkLabel.isEmpty {
                Text(linkLabel).font(.system(size: 13)).foregroundColor(.meloAccent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}

// MARK: - Track Row
struct TrackRowView: View {
    let track: Track
    let isActive: Bool
    let onTap: () -> Void

    @EnvironmentObject var library: LibraryStore
    @State private var showMenu = false

    var body: some View {
        HStack(spacing: 12) {
            // Art
            ZStack {
                TrackArtView(track: track, size: 50, cornerRadius: 13)
                if isActive {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(.black.opacity(0.4))
                    // EQ bars
                    EQBarsView()
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isActive ? .meloAccent : .primary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Menu
            Button {
                showMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .confirmationDialog(track.name, isPresented: $showMenu, titleVisibility: .visible) {
                Button("Ajouter aux favoris") { library.toggleLike(track) }
                Button("Voir les paroles") { }
                Button("Supprimer", role: .destructive) {
                    Task { await library.deleteTrack(track) }
                }
                Button("Annuler", role: .cancel) { }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isActive ? Color.meloAccent.opacity(0.07) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - EQ Bars
struct EQBarsView: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.meloAccent)
                    .frame(width: 3, height: animating ? [16.0, 5, 14][i] : [4.0, 12, 8][i])
                    .animation(
                        .easeInOut(duration: [0.7, 0.7, 0.7][i]).repeatForever(autoreverses: true).delay(Double(i) * 0.18),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - Playlist Card
struct PlaylistCardView: View {
    let playlist: Playlist
    @EnvironmentObject var library: LibraryStore

    var coverTracks: [Track] {
        playlist.trackIds.prefix(4).compactMap { id in library.tracks.first { $0.id == id } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Art
            ZStack {
                if coverTracks.count >= 4 {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 1) {
                        ForEach(coverTracks, id: \.id) { t in
                            TrackArtView(track: t, size: 60, cornerRadius: 0)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if let first = coverTracks.first {
                    TrackArtView(track: first, size: 122, cornerRadius: 16)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(Image(systemName: "music.note.list").foregroundColor(.secondary))
                }
            }
            .frame(width: 122, height: 122)
            .shadow(color: .black.opacity(0.25), radius: 8)

            Text(playlist.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text("\(playlist.trackIds.count) titres")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(width: 122)
    }
}

// MARK: - Album Card
struct AlbumCardView: View {
    let album: Album
    @EnvironmentObject var library: LibraryStore

    var coverTracks: [Track] {
        album.trackIds.prefix(4).compactMap { id in library.tracks.first { $0.id == id } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if coverTracks.count >= 4 {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                        ForEach(coverTracks, id: \.id) { t in
                            TrackArtView(track: t, size: 80, cornerRadius: 0)
                        }
                    }
                } else if let first = coverTracks.first {
                    TrackArtView(track: first, size: 160, cornerRadius: 0)
                } else {
                    Color(UIColor.tertiarySystemBackground)
                        .overlay(Image(systemName: "opticaldisc").foregroundColor(.secondary))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(Rectangle())

            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text("\(album.trackIds.count) titres")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(10)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}
