import SwiftUI

struct ContentView: View {
    @StateObject private var library = LibraryStore.shared
    @StateObject private var player  = PlayerService.shared
    @State private var selectedTab: Tab = .home
    @State private var showPlayer = false
    @State private var showSplash = true

    enum Tab: String, CaseIterable {
        case home      = "house.fill"
        case playlists = "music.note.list"
        case artists   = "person.2.fill"
        case import_   = "square.and.arrow.down"
        case storage   = "externaldrive.fill"

        var label: String {
            switch self {
            case .home:      return "Accueil"
            case .playlists: return "Playlists"
            case .artists:   return "Artistes"
            case .import_:   return "Importer"
            case .storage:   return "Stockage"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - Tab Content
            Group {
                switch selectedTab {
                case .home:      HomeView()
                case .playlists: PlaylistsView()
                case .artists:   ArtistsView()
                case .import_:   ImportView()
                case .storage:   StorageView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // MARK: - Bottom Stack
            VStack(spacing: 0) {
                // Mini Player
                if player.currentTrack != nil {
                    MiniPlayerView(showPlayer: $showPlayer)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Tab Bar
                TabBarView(selectedTab: $selectedTab)
            }

            // MARK: - Full Screen Player
            if showPlayer {
                PlayerView(isPresented: $showPlayer)
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
            }

            // MARK: - Splash
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: player.currentTrack?.id)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showPlayer)
        .task {
            // Load local then sync from B2
            await library.sync()
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                showSplash = false
            }
        }
        .environmentObject(library)
        .environmentObject(player)
    }
}

// MARK: - Splash Screen
struct SplashView: View {
    @State private var animating = false

    var body: some View {
        ZStack {
            Color(hex: "#0D1421").ignoresSafeArea()
            HStack(spacing: 14) {
                // Animated bars
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array([20.0, 34, 48, 34, 48, 34, 48, 34, 20].enumerated()), id: \.offset) { i, h in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(i == 4 ? Color.meloOrange : Color.meloAccent.opacity(0.35 + Double(i) * 0.08))
                            .frame(width: 6, height: animating ? h : h * 0.6)
                            .animation(
                                .easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(Double(i) * 0.1),
                                value: animating
                            )
                    }
                }
                .frame(height: 48)

                Text("melo")
                    .font(.system(size: 42, weight: .heavy, design: .default))
                    .foregroundColor(.white)
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - Tab Bar
struct TabBarView: View {
    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                Button {
                    Haptics.selection()
                    selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.rawValue)
                            .font(.system(size: 20, weight: .semibold))
                            .scaleEffect(selectedTab == tab ? 1.08 : 1.0)
                        Text(tab.label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? .meloAccent : .meloSub)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.2), value: selectedTab)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.white.opacity(0.07)),
                    alignment: .top
                )
        )
        .padding(.bottom, 0)
    }
}

// MARK: - Mini Player
struct MiniPlayerView: View {
    @EnvironmentObject var player: PlayerService
    @Binding var showPlayer: Bool

    var body: some View {
        guard let track = player.currentTrack else { return AnyView(EmptyView()) }
        return AnyView(
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    showPlayer = true
                }
            } label: {
                HStack(spacing: 10) {
                    TrackArtView(track: track, size: 44, cornerRadius: 11)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(track.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.48))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Previous
                    Button {
                        Haptics.impact(.light)
                        player.previous()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .buttonStyle(.plain)

                    // Play/Pause
                    Button {
                        Haptics.impact(.medium)
                        player.togglePlayPause()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.meloAccent)
                                .frame(width: 36, height: 36)
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    // Next
                    Button {
                        Haptics.impact(.light)
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(height: 66)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(hex: "#121C2E").opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                        // Progress bar at bottom
                        .overlay(
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.meloAccent)
                                    .frame(width: geo.size.width * player.progress, height: 2)
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                    .padding(.bottom, 0)
                            }
                        )
                )
                .padding(.horizontal, 10)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        )
    }
}
