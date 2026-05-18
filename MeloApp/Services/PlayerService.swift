import AVFoundation
import MediaPlayer
import Combine

@MainActor
class PlayerService: NSObject, ObservableObject {
    static let shared = PlayerService()

    // MARK: - Published state
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var progress: Double = 0        // 0-1
    @Published var currentTime: Double = 0    // seconds
    @Published var duration: Double = 0        // seconds
    @Published var isShuffled = false
    @Published var repeatMode: RepeatMode = .none
    @Published var queue: [Track] = []
    @Published var currentQueueIndex: Int = 0

    enum RepeatMode { case none, one, all }

    // MARK: - Private
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    // LRC
    @Published var lrcLines: [LRCLine] = []
    @Published var activeLRCIndex: Int = -1

    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
    }

    // MARK: - Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetooth, .allowAirPlay]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.play(); return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause(); return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next(); return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous(); return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: e.positionTime)
            }
            return .success
        }
    }

    // MARK: - Play
    func play(track: Track, in queue: [Track]) {
        let idx = queue.firstIndex(of: track) ?? 0
        self.queue = queue
        self.currentQueueIndex = idx
        loadTrack(track)
    }

    func play(trackIndex: Int) {
        guard trackIndex >= 0 && trackIndex < queue.count else { return }
        currentQueueIndex = trackIndex
        loadTrack(queue[trackIndex])
    }

    private func loadTrack(_ track: Track) {
        currentTrack = track

        // Parse LRC
        lrcLines = track.lrc.isEmpty ? [] : parseLRC(track.lrc)
        activeLRCIndex = -1

        // Remove existing observer
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
        player?.pause()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        // Build URL — try cache first
        let url = B2Service.shared.streamURL(for: track.key)
        let item = AVPlayerItem(url: url)

        player = AVPlayer(playerItem: item)

        // Time observer
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let secs = CMTimeGetSeconds(time)
            self.currentTime = secs
            let dur = self.player?.currentItem?.duration
            let durSecs = dur.map { CMTimeGetSeconds($0) } ?? 0
            if durSecs > 0 {
                self.duration = durSecs
                self.progress = secs / durSecs
            }
            self.updateLRC(at: secs)
        }

        // End of track
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: item)

        player?.play()
        isPlaying = true
        updateNowPlaying()
    }

    @objc private func playerDidFinish() {
        switch repeatMode {
        case .one:
            seek(to: 0)
            player?.play()
        case .all:
            let next = (currentQueueIndex + 1) % max(1, queue.count)
            play(trackIndex: next)
        case .none:
            if currentQueueIndex < queue.count - 1 {
                play(trackIndex: currentQueueIndex + 1)
            } else {
                isPlaying = false
                progress = 0
                currentTime = 0
            }
        }
    }

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func next() {
        let count = queue.count
        guard count > 0 else { return }
        if isShuffled {
            let idx = Int.random(in: 0..<count)
            play(trackIndex: idx)
        } else {
            play(trackIndex: (currentQueueIndex + 1) % count)
        }
    }

    func previous() {
        if currentTime > 3 {
            seek(to: 0)
        } else {
            let idx = max(0, currentQueueIndex - 1)
            play(trackIndex: idx)
        }
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: time)
        currentTime = seconds
    }

    func seekToProgress(_ p: Double) {
        seek(to: p * duration)
    }

    // MARK: - LRC
    private func updateLRC(at time: Double) {
        guard !lrcLines.isEmpty else { return }
        var newIdx = -1
        for (i, line) in lrcLines.enumerated() {
            if line.time <= time { newIdx = i }
        }
        if newIdx != activeLRCIndex {
            activeLRCIndex = newIdx
        }
    }

    // MARK: - Now Playing Info
    private func updateNowPlaying() {
        guard let track = currentTrack else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.name,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// MARK: - Time formatting
extension Double {
    var timeString: String {
        let total = Int(max(0, self))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
