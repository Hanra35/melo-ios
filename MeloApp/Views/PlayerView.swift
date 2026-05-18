import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var player: PlayerService
    @EnvironmentObject var library: LibraryStore
    @Binding var isPresented: Bool
    @State private var showLyrics = false
    @State private var showQueue = false
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Background - blurred art color
            if let track = player.currentTrack {
                Color(hue: track.hue)
                    .opacity(0.15)
                    .ignoresSafeArea()
            }
            Color(UIColor.systemBackground).opacity(0.92).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 34, height: 34)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                    Text("LECTURE EN COURS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .kerning(1.2)
                    Spacer()

                    Button {
                        showQueue = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                            .frame(width: 34, height: 34)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                ScrollView {
                    VStack(spacing: 0) {
                        // Album Art
                        artSection

                        // Meta
                        metaSection

                        // Seek bar
                        seekSection

                        // Controls
                        controlsSection

                        // Volume
                        volumeSection

                        // Lyrics
                        lyricsSection
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isPresented = false
                        }
                    }
                }
        )
        .sheet(isPresented: $showQueue) {
            QueueView()
        }
    }

    // MARK: - Art
    var artSection: some View {
        HStack {
            if let track = player.currentTrack {
                TrackArtView(track: track, size: min(UIScreen.main.bounds.width - 60, 300), cornerRadius: 28)
                    .shadow(color: .black.opacity(0.32), radius: 24, y: 12)
                    .scaleEffect(player.isPlaying ? 1.0 : 0.9)
                    .animation(.spring(response: 0.5), value: player.isPlaying)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 30)
    }

    // MARK: - Meta
    var metaSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentTrack?.name ?? "")
                    .font(.system(size: 22, weight: .heavy))
                    .lineLimit(1)
                Text(player.currentTrack?.artist ?? "")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Like button
            if let track = player.currentTrack {
                Button {
                    Haptics.impact(.medium)
                    library.toggleLike(track)
                } label: {
                    Image(systemName: library.isLiked(track) ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundColor(library.isLiked(track) ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 26)
    }

    // MARK: - Seek
    var seekSection: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(UIColor.tertiarySystemBackground))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.meloAccent)
                        .frame(width: geo.size.width * player.progress, height: 3)
                }
                .contentShape(Rectangle().size(CGSize(width: geo.size.width, height: 20)))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let p = max(0, min(1, value.location.x / geo.size.width))
                            player.seekToProgress(p)
                        }
                )
            }
            .frame(height: 3)

            HStack {
                Text(player.currentTime.timeString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text(player.duration.timeString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
    }

    // MARK: - Controls
    var controlsSection: some View {
        HStack(spacing: 0) {
            // Shuffle
            Button {
                Haptics.impact(.light)
                player.isShuffled.toggle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 20))
                    .foregroundColor(player.isShuffled ? .meloAccent : .secondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            // Previous
            Button {
                Haptics.impact(.medium)
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 26))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            // Play/Pause
            Button {
                Haptics.impact(.medium)
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.meloOrange)
                        .frame(width: 62, height: 62)
                        .shadow(color: Color.meloOrange.opacity(0.45), radius: 8, y: 4)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            // Next
            Button {
                Haptics.impact(.medium)
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 26))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            // Repeat
            Button {
                Haptics.impact(.light)
                switch player.repeatMode {
                case .none: player.repeatMode = .all
                case .all:  player.repeatMode = .one
                case .one:  player.repeatMode = .none
                }
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 20))
                    .foregroundColor(player.repeatMode != .none ? .meloAccent : .secondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    // MARK: - Volume
    var volumeSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 13))
            // System volume slider (MPVolumeView would be ideal but needs UIViewRepresentable)
            VolumeSlider()
            Image(systemName: "speaker.wave.3.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
    }

    // MARK: - Lyrics
    var lyricsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PAROLES")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .kerning(0.08)
                Spacer()
                if let track = player.currentTrack {
                    Button("Modifier") {
                        // TODO: show lyrics editor
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            if player.lrcLines.isEmpty {
                Text("Aucune parole disponible.\nAppuyez sur \"Modifier\" pour en ajouter.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                LyricsScrollView()
                    .frame(height: 280)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 40)
    }
}

// MARK: - Lyrics Scroll View
struct LyricsScrollView: View {
    @EnvironmentObject var player: PlayerService

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 30)
                    ForEach(Array(player.lrcLines.enumerated()), id: \.element.id) { i, line in
                        Button {
                            player.seek(to: line.time)
                        } label: {
                            Text(line.text)
                                .font(.system(size: i == player.activeLRCIndex ? 22 : 18, weight: .semibold))
                                .foregroundColor(i == player.activeLRCIndex ? .primary : (i < player.activeLRCIndex ? .secondary.opacity(0.3) : .secondary.opacity(0.45)))
                                .scaleEffect(i == player.activeLRCIndex ? 1.03 : 1.0, anchor: .leading)
                                .animation(.easeInOut(duration: 0.3), value: player.activeLRCIndex)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .id(i)
                    }
                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 20)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.12),
                        .init(color: .black, location: 0.8),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onChange(of: player.activeLRCIndex) { idx in
                withAnimation { proxy.scrollTo(idx, anchor: .center) }
            }
        }
    }
}

// MARK: - Volume Slider (UIKit bridge)
struct VolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let v = MPVolumeView()
        v.showsRouteButton = false
        return v
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

// MARK: - Queue View
struct QueueView: View {
    @EnvironmentObject var player: PlayerService
    @Environment(\.presentationMode) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(player.queue.enumerated()), id: \.element.id) { i, track in
                    HStack(spacing: 12) {
                        TrackArtView(track: track, size: 42, cornerRadius: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.name)
                                .font(.system(size: 14, weight: player.currentQueueIndex == i ? .bold : .medium))
                                .foregroundColor(player.currentQueueIndex == i ? .meloAccent : .primary)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if player.currentQueueIndex == i {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.meloAccent)
                                .font(.system(size: 14))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        player.play(trackIndex: i)
                    }
                }
                .onMove { from, to in
                    player.queue.move(fromOffsets: from, toOffset: to)
                }
            }
            .navigationTitle("À suivre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") { dismiss.wrappedValue.dismiss() }
                }
            }
        }
    }
}
