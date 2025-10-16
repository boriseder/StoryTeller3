import Foundation
import AVFoundation
import Combine
import AVKit
import UIKit
import MediaPlayer

// MARK: - Audio Player
class AudioPlayer: NSObject, ObservableObject {
    @Published var book: Book?
    @Published var currentChapterIndex: Int = 0
    @Published var isPlaying = false
    @Published var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var playbackRate: Float = 1.0

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var currentPlaybackSession: PlaybackSessionResponse?
    private var baseURL: String = ""
    private var authToken: String = ""
    private var downloadManager: DownloadManager?
    private var isOfflineMode: Bool = false
    private var targetSeekTime: Double?
    private var observers: [NSObjectProtocol] = []
    private var preloader = AudioTrackPreloader()
    
    private static var observerContext = 0
    private var currentObservedItem: AVPlayerItem?
    private var hasAddedKVOObservers = false

    var currentChapter: Chapter? {
        guard let book = book, currentChapterIndex < book.chapters.count else { return nil }
        return book.chapters[currentChapterIndex]
    }
    
    // MARK: - Public Properties for UI Integration
    var downloadManagerReference: DownloadManager? {
        return downloadManager
    }
    
    override init() {
        super.init()
        setupPersistence()
    }

    // MARK: - Configuration
    func configure(baseURL: String, authToken: String, downloadManager: DownloadManager? = nil) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.authToken = authToken
        self.downloadManager = downloadManager
        
        // Setup player-specific features
        setupRemoteCommandCenter()
                
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    // MARK: - NEW: Interruption Handling
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began (phone call, alarm, etc.)
            AppLogger.general.debug("[AudioPlayer] 🔔 Interruption began - pausing")
            pause()
            
        case .ended:
            // Interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                // Resume playback after interruption
                AppLogger.general.debug("[AudioPlayer] 🔔 Interruption ended - resuming")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.play()
                }
            }
            
        @unknown default:
            break
        }
    }
    
    // MARK: - NEW: Remote Command Center Setup
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // Skip forward (15 seconds)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.seek15SecondsForward()
            return .success
        }
        
        // Skip backward (15 seconds)
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.seek15SecondsBack()
            return .success
        }
        
        // Next track (next chapter)
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextChapter()
            return .success
        }
        
        // Previous track (previous chapter)
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousChapter()
            return .success
        }
        
        // Change playback position (scrubbing)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
        
        // Change playback rate
        commandCenter.changePlaybackRateCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let self = self,
                  let rateEvent = event as? MPChangePlaybackRateCommandEvent else {
                return .commandFailed
            }
            self.setPlaybackRate(Double(rateEvent.playbackRate))
            return .success
        }
        
        AppLogger.general.debug("[AudioPlayer] Remote command center configured")
    }
    
    // MARK: - NEW: Now Playing Info
    private func updateNowPlayingInfo() {
        guard let book = book else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        let trackNumber = max(currentChapterIndex + 1, 1)
        let trackCount = max(book.chapters.count, 2) // mind. 2 für Prev/Next
        
        AppLogger.general.debug("[AudioPlayer] trackNumber: \(trackNumber)")
        AppLogger.general.debug("[AudioPlayer] trackCount: \(trackCount)")
        
        let trackName = "Unknown Title"
        AppLogger.general.debug("[AudioPlayer] trackName: \(trackName)")

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: currentChapter?.title ?? "Kapitel",
            MPMediaItemPropertyArtist: book.author ?? "Unknown Author",
            MPMediaItemPropertyAlbumTitle: book.title,
            MPMediaItemPropertyAlbumTrackNumber: trackNumber,
            MPMediaItemPropertyAlbumTrackCount: trackCount,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackRate) : 0.0
        ]
        
        // Add chapter info
        if let chapter = currentChapter {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = chapter.title
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        // Add artwork if available
        Task { @MainActor in
            if let downloadManager = downloadManager,
               let localCoverURL = downloadManager.getLocalCoverURL(for: book.id),
               let image = UIImage(contentsOfFile: localCoverURL.path) {
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            } else {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
        }
    }
    
    
    // MARK: - Book Loading

    @MainActor
    func load(book: Book, isOffline: Bool = false, restoreState: Bool = true) {
        self.book = book
        self.isOfflineMode = isOffline
        
        // Clear any existing preloaded tracks
        preloader.clearAll()
        
        // Restore saved state BEFORE loading chapter
        if restoreState {
            if let savedState = PlaybackPersistenceManager.shared.loadPlaybackState(for: book.id) {
                self.currentChapterIndex = min(savedState.chapterIndex, book.chapters.count - 1)
                self.targetSeekTime = savedState.currentTime
                AppLogger.general.debug("[AudioPlayer] Restored state: Chapter \(savedState.chapterIndex), Time: \(savedState.currentTime)s")
            }
        } else {
            self.currentChapterIndex = 0
            self.targetSeekTime = nil
        }
        
        loadChapter()
        
        // Update now playing info
        updateNowPlayingInfo()
    }

    func loadChapter(shouldResumePlayback: Bool = false) {
        guard let chapter = currentChapter else {
            AppLogger.general.debug("[AudioPlayer] ERROR: No current chapter found")
            errorMessage = "Kein Kapitel verfügbar"
            return
        }
        
        AppLogger.general.debug("[AudioPlayer] Loading chapter: \(chapter.title)")
        AppLogger.general.debug("[AudioPlayer] Chapter index: \(self.currentChapterIndex)")
        AppLogger.general.debug("[AudioPlayer] Offline mode: \(self.isOfflineMode)")
        AppLogger.general.debug("[AudioPlayer] Should resume playback: \(shouldResumePlayback)")
        AppLogger.general.debug("[AudioPlayer] Library item ID: \(chapter.libraryItemId ?? "nil")")

        // Try to use preloaded item first
        if let preloadedItem = preloader.getPreloadedItem(for: currentChapterIndex) {
            AppLogger.general.debug("[AudioPlayer] Using preloaded item for chapter \(currentChapterIndex)")
            let chapterDuration = (chapter.end ?? 0) - (chapter.start ?? 0)
            setupPlayerWithPreloadedItem(preloadedItem, duration: chapterDuration, shouldResumePlayback: shouldResumePlayback)
            startPreloadingNextChapter()
            return
        }

        isLoading = true
        errorMessage = nil
        
        // Check for offline mode first
        if self.isOfflineMode {
            loadOfflineChapter(chapter, shouldResumePlayback: shouldResumePlayback)
            return
        }
        
        // Online mode
        createPlaybackSession(for: chapter) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let session):
                    AppLogger.general.debug("[AudioPlayer] SUCCESS: Playback session created: \(session.id)")
                    self.currentPlaybackSession = session
                    self.setupPlayerWithSession(session, shouldResumePlayback: shouldResumePlayback)
                case .failure(let error):
                    AppLogger.general.debug("[AudioPlayer] ERROR: Failed to create playback session: \(error)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Enhanced Chapter Management
    func setCurrentChapter(index: Int) {
        guard let book = book else {
            AppLogger.general.debug("[AudioPlayer] ERROR: No book loaded")
            return
        }
        
        guard index >= 0 && index < book.chapters.count else {
            AppLogger.general.debug("[AudioPlayer] ERROR: Invalid chapter index: \(index) (valid range: 0-\(book.chapters.count - 1))")
            return
        }
        
        guard index != currentChapterIndex else {
            AppLogger.general.debug("[AudioPlayer] Chapter \(index) is already current")
            return
        }
        
        let wasPlaying = isPlaying
        let targetChapter = book.chapters[index]
        
        AppLogger.general.debug("[AudioPlayer] Switching to chapter \(index): \(targetChapter.title), wasPlaying: \(wasPlaying)")
        
        if isPlaying {
            pause()
        }
        
        currentChapterIndex = index
        loadChapter(shouldResumePlayback: wasPlaying)
        saveCurrentPlaybackState()
        
        // Update now playing info with new chapter
        updateNowPlayingInfo()
    }

    private func loadOfflineChapter(_ chapter: Chapter, shouldResumePlayback: Bool = false) {
        guard let book = book,
              let downloadManager = downloadManager else {
            isLoading = false
            errorMessage = "Download Manager nicht verfügbar"
            return
        }
        
        Task { @MainActor in
            if downloadManager.isBookDownloaded(book.id),
               let localURL = downloadManager.getLocalAudioURL(for: book.id, chapterIndex: self.currentChapterIndex) {
                
                AppLogger.general.debug("[AudioPlayer] Loading offline file: \(localURL)")
                AppLogger.general.debug("[AudioPlayer] File exists: \(FileManager.default.fileExists(atPath: localURL.path))")
                
                let playerItem = AVPlayerItem(url: localURL)
                let chapterDuration = (chapter.end ?? 0) - (chapter.start ?? 0)
                self.setupOfflinePlayer(playerItem: playerItem, duration: chapterDuration, shouldResumePlayback: shouldResumePlayback)
            } else {
                self.errorMessage = "Offline-Audiodatei nicht gefunden"
            }
            self.isLoading = false
        }
    }
    
    private func setupOfflinePlayer(playerItem: AVPlayerItem, duration: Double, shouldResumePlayback: Bool = false) {
        cleanupPlayer()
        player = AVPlayer(playerItem: playerItem)
        setupPlayerItemObservers(playerItem)
        addTimeObserver()
        self.duration = duration
        
        AppLogger.general.debug("[AudioPlayer] Offline player setup complete, duration: \(duration)")
        
        // Update now playing info
        updateNowPlayingInfo()
        
        // Start preloading next chapter
        startPreloadingNextChapter()
        
        // Handle delayed seek for restored state
        if let seekTime = targetSeekTime {
            let timeToSeek = seekTime
            self.targetSeekTime = nil
            
            AppLogger.general.debug("[AudioPlayer] Delayed seek to restored position: \(timeToSeek)s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.seek(to: timeToSeek)
                
                if shouldResumePlayback {
                    AppLogger.general.debug("[AudioPlayer] Auto-resuming playback after restoration")
                    self.play()
                }
            }
        } else if shouldResumePlayback {
            AppLogger.general.debug("[AudioPlayer] Auto-resuming playback for offline chapter")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.play()
            }
        }
    }

    // MARK: - Playback Session Management
    private func createPlaybackSession(for chapter: Chapter, completion: @escaping (Result<PlaybackSessionResponse, Error>) -> Void) {
        guard let libraryItemId = chapter.libraryItemId else {
            completion(.failure(AudiobookshelfError.missingLibraryItemId))
            return
        }
        
        var urlString = "\(baseURL)/api/items/\(libraryItemId)/play"
        if let episodeId = chapter.episodeId {
            urlString += "/\(episodeId)"
        }
        
        guard let url = URL(string: urlString) else {
            completion(.failure(AudiobookshelfError.invalidURL(urlString)))
            return
        }
        
        let requestBody = DeviceUtils.createPlaybackRequest()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        AppLogger.general.debug("[AudioPlayer] Creating playback session: \(url)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                completion(.failure(AudiobookshelfError.invalidResponse))
                return
            }
            
            do {
                let session = try JSONDecoder().decode(PlaybackSessionResponse.self, from: data)
                AppLogger.general.debug("[AudioPlayer] Playback session created: \(session.id)")
                completion(.success(session))
            } catch {
                AppLogger.general.debug("[AudioPlayer] ERROR: JSON decode error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func setupPlayerWithSession(_ session: PlaybackSessionResponse, shouldResumePlayback: Bool = false) {
        AppLogger.general.debug("[AudioPlayer] Setting up player with session: \(session.id)")
        AppLogger.general.debug("[AudioPlayer] Available tracks: \(session.audioTracks.count)")
        AppLogger.general.debug("[AudioPlayer] Current chapter index: \(self.currentChapterIndex)")
        
        guard self.currentChapterIndex < session.audioTracks.count else {
            AppLogger.general.debug("[AudioPlayer] ERROR: Chapter index out of bounds for available tracks")
            errorMessage = "Kapitel-Index ungültig"
            return
        }
        
        let audioTrack = session.audioTracks[self.currentChapterIndex]
        let fullURL = "\(baseURL)\(audioTrack.contentUrl)"

        AppLogger.general.debug("[AudioPlayer] Audio URL: \(fullURL)")
        AppLogger.general.debug("[AudioPlayer] Track duration: \(audioTrack.duration)")

        guard let audioURL = URL(string: fullURL) else {
            AppLogger.general.debug("[AudioPlayer] ERROR: Invalid audio URL: \(fullURL)")
            errorMessage = "Ungültige Audio-URL"
            return
        }
        
        let asset = createAuthenticatedAsset(url: audioURL)
        let playerItem = AVPlayerItem(asset: asset)
        
        cleanupPlayer()
        
        player = AVPlayer(playerItem: playerItem)
        setupPlayerItemObservers(playerItem)
        addTimeObserver()
        self.duration = audioTrack.duration
        
        AppLogger.general.debug("[AudioPlayer] Player created, duration set to: \(self.duration)")
        
        // Update now playing info
        updateNowPlayingInfo()
        
        // Start preloading next chapter
        startPreloadingNextChapter()
        
        if let seekTime = targetSeekTime {
            let timeToSeek = seekTime
            self.targetSeekTime = nil
            
            AppLogger.general.debug("[AudioPlayer] Delayed seek to restored position: \(timeToSeek)s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.seek(to: timeToSeek)
                
                if shouldResumePlayback {
                    AppLogger.general.debug("[AudioPlayer] Auto-resuming playback after restoration")
                    self.play()
                }
            }
        } else if shouldResumePlayback {
            AppLogger.general.debug("[AudioPlayer] Auto-resuming playback for online chapter")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.play()
            }
        }
    }

    private func createAuthenticatedAsset(url: URL) -> AVURLAsset {
        let headers = [
            "Authorization": "Bearer \(authToken)",
            "User-Agent": "AudioBook Client/1.0.0"
        ]
        
        return AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": headers
        ])
    }
    
    // MARK: - Preloading Helper Methods
    
    private func startPreloadingNextChapter() {
        guard let book = book else { return }
        
        preloader.preloadNext(
            chapterIndex: currentChapterIndex,
            book: book,
            isOffline: isOfflineMode,
            baseURL: baseURL,
            authToken: authToken,
            downloadManager: downloadManager
        ) { success in
            if success {
                AppLogger.general.debug("[AudioPlayer] Next chapter preloaded successfully")
            } else {
                AppLogger.general.debug("[AudioPlayer] Failed to preload next chapter")
            }
        }
    }
    
    private func setupPlayerWithPreloadedItem(_ playerItem: AVPlayerItem, duration: Double, shouldResumePlayback: Bool = false) {
        cleanupPlayer()
        
        player = AVPlayer(playerItem: playerItem)
        setupPlayerItemObservers(playerItem)
        addTimeObserver()
        self.duration = duration
        
        AppLogger.general.debug("[AudioPlayer] Player setup with preloaded item, duration: \(duration)")
        
        // Update now playing info
        updateNowPlayingInfo()
        
        // Start preloading next chapter
        startPreloadingNextChapter()
        
        // Handle delayed seek for restored state
        if let seekTime = targetSeekTime {
            let timeToSeek = seekTime
            self.targetSeekTime = nil
            
            AppLogger.general.debug("[AudioPlayer] Delayed seek to restored position: \(timeToSeek)s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                self.seek(to: timeToSeek)
                
                if shouldResumePlayback {
                    AppLogger.general.debug("[AudioPlayer] Auto-resuming playback after restoration")
                    self.play()
                }
            }
        } else if shouldResumePlayback {
            AppLogger.general.debug("[AudioPlayer] Auto-resuming playback with preloaded item")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.play()
            }
        }
    }
    
    // MARK: - Player Observer Management
    private func setupPlayerItemObservers(_ playerItem: AVPlayerItem) {
        if let previousItem = currentObservedItem {
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: previousItem
            )
            if hasAddedKVOObservers {
                previousItem.removeObserver(self, forKeyPath: "status", context: &AudioPlayer.observerContext)
                previousItem.removeObserver(self, forKeyPath: "loadedTimeRanges", context: &AudioPlayer.observerContext)
            }
        }
        
        playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: &AudioPlayer.observerContext)
        playerItem.addObserver(self, forKeyPath: "loadedTimeRanges", options: [.new], context: &AudioPlayer.observerContext)
        hasAddedKVOObservers = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        currentObservedItem = playerItem
    }
    
    private func cleanupPlayer() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        if let observedItem = currentObservedItem {
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: observedItem
            )
            
            if hasAddedKVOObservers {
                observedItem.removeObserver(self, forKeyPath: "status", context: &AudioPlayer.observerContext)
                observedItem.removeObserver(self, forKeyPath: "loadedTimeRanges", context: &AudioPlayer.observerContext)
                hasAddedKVOObservers = false
            }
        }
        currentObservedItem = nil
        
        player?.pause()
        player = nil
    }

    // MARK: - Playback Controls
    func play() {
        guard let player = player else {
            errorMessage = "Player nicht initialisiert"
            return
        }
        
        guard let currentItem = player.currentItem else {
            errorMessage = "Keine Audio-Datei geladen"
            return
        }
        
        AppLogger.general.debug("[AudioPlayer] Play requested - Status: \(currentItem.status.rawValue)")
        
        switch currentItem.status {
        case .readyToPlay:
            player.play()
            player.rate = self.playbackRate
            isPlaying = true
            updateNowPlayingInfo()
            AppLogger.general.debug("[AudioPlayer] Playback started at rate: \(self.playbackRate)")
        case .failed:
            let error = currentItem.error?.localizedDescription ?? "Unbekannter Fehler"
            errorMessage = "Playback failed: \(error)"
            AppLogger.general.debug("[AudioPlayer] Playback failed: \(error)")
        case .unknown:
            AppLogger.general.debug("[AudioPlayer] Player status unknown - waiting for ready state")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self,
                      let currentItem = self.player?.currentItem,
                      currentItem.status == .readyToPlay else {
                    self?.errorMessage = "Player nicht bereit"
                    return
                }
                self.play()
            }
        @unknown default:
            player.play()
            player.rate = self.playbackRate
            isPlaying = true
            updateNowPlayingInfo()
        }
    }
    
    func pause() {
        AppLogger.general.debug("[AudioPlayer] Pause requested")
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func togglePlayPause() {
        AppLogger.general.debug("[AudioPlayer] Toggle play/pause - currently playing: \(self.isPlaying)")
        self.isPlaying ? pause() : play()
        saveCurrentPlaybackState()
    }

    func nextChapter() {
        guard let book = book else {
            AppLogger.general.debug("[AudioPlayer] No book loaded for next chapter")
            return
        }
        
        guard self.currentChapterIndex + 1 < book.chapters.count else {
            AppLogger.general.debug("[AudioPlayer] Already at last chapter")
            pause()
            return
        }
        
        AppLogger.general.debug("[AudioPlayer] Moving to next chapter: \(self.currentChapterIndex + 1)")
        setCurrentChapter(index: self.currentChapterIndex + 1)
    }
    
    func previousChapter() {
        guard self.currentChapterIndex > 0 else {
            AppLogger.general.debug("[AudioPlayer] Already at first chapter")
            return
        }
        
        AppLogger.general.debug("[AudioPlayer] Moving to previous chapter: \(self.currentChapterIndex - 1)")
        setCurrentChapter(index: self.currentChapterIndex - 1)
    }

    func seek15SecondsBack() {
        let newTime = max(0, self.currentTime - 15)
        AppLogger.general.debug("[AudioPlayer] Seeking back 15s: \(self.currentTime) -> \(newTime)")
        seek(to: newTime)
    }

    func seek15SecondsForward() {
        let newTime = min(self.duration, self.currentTime + 15)
        AppLogger.general.debug("[AudioPlayer] Seeking forward 15s: \(self.currentTime) -> \(newTime)")
        seek(to: newTime)
    }

    func seek(to seconds: Double) {
        guard seconds >= 0 && seconds <= self.duration else {
            AppLogger.general.debug("[AudioPlayer] Invalid seek time: \(seconds) (duration: \(self.duration))")
            return
        }
        
        let time = CMTime(seconds: seconds, preferredTimescale: 1)
        AppLogger.general.debug("[AudioPlayer] Seeking to: \(seconds)s")
        player?.seek(to: time)
        
        if isPlaying {
            player?.rate = playbackRate
        }
        
        updateNowPlayingInfo()
        saveCurrentPlaybackState()
    }

    private func addTimeObserver() {
        guard let player = player else { return }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = CMTimeGetSeconds(time)
            
            // Update now playing info periodically (every 5 seconds)
            if Int(self.currentTime) % 5 == 0 {
                self.updateNowPlayingInfo()
            }
        }
    }
    
    // MARK: - Persistence Integration

    private func setupPersistence() {
        // Auto-save observer
        let autoSaveObserver = NotificationCenter.default.addObserver(
            forName: .playbackAutoSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveCurrentPlaybackState()
        }
        observers.append(autoSaveObserver)
        
        // Background observer
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveCurrentPlaybackState()
        }
        observers.append(backgroundObserver)
    }
    
    private func saveCurrentPlaybackState() {
        guard let book = book else { return }
        
        let state = PlaybackState(
            bookId: book.id,
            chapterIndex: currentChapterIndex,
            currentTime: currentTime,
            duration: duration,
            lastPlayed: Date(),
            isFinished: isBookFinished()
        )
        
        PlaybackPersistenceManager.shared.savePlaybackState(state)
    }

    private func isBookFinished() -> Bool {
        guard let book = book else { return false }
        
        let isLastChapter = currentChapterIndex >= book.chapters.count - 1
        let nearEnd = duration > 0 && (currentTime / duration) > 0.95
        
        return isLastChapter && nearEnd
    }
    
    // MARK: - Playback Speed
    func setPlaybackRate(_ rate: Double) {
        let floatRate = Float(rate)
        self.playbackRate = floatRate
        
        // Apply rate immediately if playing
        if self.isPlaying {
            player?.rate = floatRate
        }
        
        updateNowPlayingInfo()
        AppLogger.general.debug("[AudioPlayer] Playback rate set to: \(rate)x (applied: \(self.isPlaying))")
    }
    
    @objc private func playerItemDidFinishPlaying(_ notification: Notification) {
        AppLogger.general.debug("[AudioPlayer] Chapter finished - auto-advancing to next")
        
        guard let book = book, self.currentChapterIndex + 1 < book.chapters.count else {
            AppLogger.general.debug("[AudioPlayer] Book finished - stopping playback")
            DispatchQueue.main.async { [weak self] in
                self?.isPlaying = false
                self?.updateNowPlayingInfo()
            }
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.nextChapter()
        }
    }
    
    // MARK: - Observer
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &AudioPlayer.observerContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        guard let keyPath = keyPath, let playerItem = object as? AVPlayerItem else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch keyPath {
            case "status":
                switch playerItem.status {
                case .readyToPlay:
                    self.errorMessage = nil
                    AppLogger.general.debug("[AudioPlayer] Player item ready to play")
                case .failed:
                    let errorDescription = playerItem.error?.localizedDescription ?? "Unknown error"
                    self.errorMessage = errorDescription
                    AppLogger.general.debug("[AudioPlayer] Player item failed: \(errorDescription)")
                case .unknown:
                    AppLogger.general.debug("[AudioPlayer] Player item status unknown")
                @unknown default:
                    break
                }
                
            case "loadedTimeRanges":
                // Could implement buffering progress here
                break
            default:
                break
            }
        }
    }

    deinit {
        // Clean up player resources
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self)
        
        if let observedItem = currentObservedItem, hasAddedKVOObservers {
            observedItem.removeObserver(self, forKeyPath: "status", context: &AudioPlayer.observerContext)
            observedItem.removeObserver(self, forKeyPath: "loadedTimeRanges", context: &AudioPlayer.observerContext)
        }
        
        player?.pause()
        player = nil
        
        // Clear preloader
        preloader.clearAll()
        
        // Remove all observers
        observers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        
        // Clear now playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        AppLogger.general.debug("[AudioPlayer] Deinitialized and cleaned up")
    }
}
