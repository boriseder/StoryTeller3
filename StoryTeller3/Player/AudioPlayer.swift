import Foundation
import AVFoundation
import Combine
import AVKit
import UIKit

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
    @Published var availableAudioRoutes: [AVAudioSessionPortDescription] = []
    @Published var currentAudioRoute: String = "iPhone"

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var currentPlaybackSession: PlaybackSessionResponse?
    private var baseURL: String = ""
    private var authToken: String = ""
    private var downloadManager: DownloadManager?
    private var isOfflineMode: Bool = false
    private var targetSeekTime: Double?

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
        
        // Configure audio session
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try audioSession.setActive(true)
            
            // Listen for route changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(audioRouteChanged),
                name: AVAudioSession.routeChangeNotification,
                object: nil
            )
            
            updateAudioRoutes()
        } catch {
            errorMessage = "Audio session configuration failed: \(error.localizedDescription)"
        }
    }
    
    @objc private func audioRouteChanged(notification: Notification) {
        updateAudioRoutes()
    }
    
    private func updateAudioRoutes() {
        let session = AVAudioSession.sharedInstance()
        availableAudioRoutes = session.currentRoute.outputs
        
        if let output = session.currentRoute.outputs.first {
            currentAudioRoute = output.portName
        }
    }

    // MARK: - Book Loading

    func load(book: Book, isOffline: Bool = false, restoreState: Bool = true) {
        self.book = book
        self.isOfflineMode = isOffline
        
        // Restore saved state BEFORE loading chapter
        if restoreState {
            if let savedState = PlaybackPersistenceManager.shared.loadPlaybackState(for: book.id) {
                self.currentChapterIndex = min(savedState.chapterIndex, book.chapters.count - 1)
                self.targetSeekTime = savedState.currentTime
                AppLogger.debug.debug("[AudioPlayer] Restored state: Chapter \(savedState.chapterIndex), Time: \(savedState.currentTime)s")
            }
        } else {
            self.currentChapterIndex = 0
            self.targetSeekTime = nil
        }
        
        loadChapter()
    }
    func loadChapter(shouldResumePlayback: Bool = false) {
        guard let chapter = currentChapter else {
            AppLogger.debug.debug("[AudioPlayer] ERROR: No current chapter found")
            errorMessage = "Kein Kapitel verfügbar"
            return
        }
        
        AppLogger.debug.debug("[AudioPlayer] Loading chapter: \(chapter.title)")
        AppLogger.debug.debug("[AudioPlayer] Chapter index: \(self.currentChapterIndex)")
        AppLogger.debug.debug("[AudioPlayer] Offline mode: \(self.isOfflineMode)")
        AppLogger.debug.debug("[AudioPlayer] Should resume playback: \(shouldResumePlayback)")
        AppLogger.debug.debug("[AudioPlayer] Library item ID: \(chapter.libraryItemId ?? "nil")")

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
                    AppLogger.debug.debug("[AudioPlayer] SUCCESS: Playback session created: \(session.id)")
                    self.currentPlaybackSession = session
                    self.setupPlayerWithSession(session, shouldResumePlayback: shouldResumePlayback)
                case .failure(let error):
                    AppLogger.debug.debug("[AudioPlayer] ERROR: Failed to create playbook session: \(error)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Enhanced Chapter Management
    func setCurrentChapter(index: Int) {
        guard let book = book else {
            AppLogger.debug.debug("[AudioPlayer] ERROR: No book loaded")
            return
        }
        
        guard index >= 0 && index < book.chapters.count else {
            AppLogger.debug.debug("[AudioPlayer] ERROR: Invalid chapter index: \(index) (valid range: 0-\(book.chapters.count - 1))")
            return
        }
        
        guard index != currentChapterIndex else {
            AppLogger.debug.debug("[AudioPlayer] Chapter \(index) is already current")
            return
        }
        
        let wasPlaying = isPlaying
        let targetChapter = book.chapters[index]
        
        AppLogger.debug.debug("[AudioPlayer] Switching to chapter \(index): \(targetChapter.title), wasPlaying: \(wasPlaying)")
        
        if isPlaying {
            pause()
        }
        
        currentChapterIndex = index
        loadChapter(shouldResumePlayback: wasPlaying)
        saveCurrentPlaybackState()
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
                
                AppLogger.debug.debug("[AudioPlayer] Loading offline file: \(localURL)")
                AppLogger.debug.debug("[AudioPlayer] File exists: \(FileManager.default.fileExists(atPath: localURL.path))")
                
                let playerItem = AVPlayerItem(url: localURL)
                self.setupOfflinePlayer(playerItem: playerItem, duration: chapter.end ?? 3600, shouldResumePlayback: shouldResumePlayback)
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
        
        AppLogger.debug.debug("[AudioPlayer] Offline player setup complete, duration: \(duration)")
        
        // Handle delayed seek for restored state
        if let seekTime = targetSeekTime {
            AppLogger.debug.debug("[AudioPlayer] Delayed seek to restored position: \(seekTime)s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.seek(to: seekTime)
                self.targetSeekTime = nil
                
                if shouldResumePlayback {
                    AppLogger.debug.debug("[AudioPlayer] Auto-resuming playback after restoration")
                    self.play()
                }
            }
        } else if shouldResumePlayback {
            AppLogger.debug.debug("[AudioPlayer] Auto-resuming playback for offline chapter")
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
        
        AppLogger.debug.debug("[AudioPlayer] Creating playback session: \(url)")
        
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
                AppLogger.debug.debug("[AudioPlayer] Playback session created: \(session.id)")
                completion(.success(session))
            } catch {
                AppLogger.debug.debug("[AudioPlayer] ERROR: JSON decode error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func setupPlayerWithSession(_ session: PlaybackSessionResponse, shouldResumePlayback: Bool = false) {
        AppLogger.debug.debug("[AudioPlayer] Setting up player with session: \(session.id)")
        AppLogger.debug.debug("[AudioPlayer] Available tracks: \(session.audioTracks.count)")
        AppLogger.debug.debug("[AudioPlayer] Current chapter index: \(self.currentChapterIndex)")
        
        guard self.currentChapterIndex < session.audioTracks.count else {
            AppLogger.debug.debug("[AudioPlayer] ERROR: Chapter index out of bounds for available tracks")
            errorMessage = "Kapitel-Index ungültig"
            return
        }
        
        let audioTrack = session.audioTracks[self.currentChapterIndex]
        let fullURL = "\(baseURL)\(audioTrack.contentUrl)"

        AppLogger.debug.debug("[AudioPlayer] Audio URL: \(fullURL)")
        AppLogger.debug.debug("[AudioPlayer] Track duration: \(audioTrack.duration)")

        guard let audioURL = URL(string: fullURL) else {
            AppLogger.debug.debug("[AudioPlayer] ERROR: Invalid audio URL: \(fullURL)")
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
        
        AppLogger.debug.debug("[AudioPlayer] Player created, duration set to: \(self.duration)")
        
        // Handle delayed seek for restored state
        if let seekTime = targetSeekTime {
            AppLogger.debug.debug("[AudioPlayer] Delayed seek to restored position: \(seekTime)s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.seek(to: seekTime)
                self.targetSeekTime = nil
                
                if shouldResumePlayback {
                    AppLogger.debug.debug("[AudioPlayer] Auto-resuming playback after restoration")
                    self.play()
                }
            }
        } else if shouldResumePlayback {
            AppLogger.debug.debug("[AudioPlayer] Auto-resuming playback for online chapter")
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
    
    // MARK: - Player Observer Management
    private func setupPlayerItemObservers(_ playerItem: AVPlayerItem) {
        playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        playerItem.addObserver(self, forKeyPath: "loadedTimeRanges", options: [.new], context: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }
    
    private func cleanupPlayer() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        if let currentItem = player?.currentItem {
            currentItem.removeObserver(self, forKeyPath: "status", context: nil)
            currentItem.removeObserver(self, forKeyPath: "loadedTimeRanges", context: nil)
        }
        
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
        
        AppLogger.debug.debug("[AudioPlayer] Play requested - Status: \(currentItem.status.rawValue)")
        
        switch currentItem.status {
        case .readyToPlay:
            player.play()
            player.rate = self.playbackRate
            isPlaying = true
            AppLogger.debug.debug("[AudioPlayer] Playback started at rate: \(self.playbackRate)")
        case .failed:
            let error = currentItem.error?.localizedDescription ?? "Unbekannter Fehler"
            errorMessage = "Playback failed: \(error)"
            AppLogger.debug.debug("[AudioPlayer] Playback failed: \(error)")
        case .unknown:
            player.play()
            player.rate = self.playbackRate
            isPlaying = true
            AppLogger.debug.debug("[AudioPlayer] Playback started (unknown status)")
        @unknown default:
            player.play()
            player.rate = self.playbackRate
            isPlaying = true
        }
    }
    
    func pause() {
        AppLogger.debug.debug("[AudioPlayer] Pause requested")
        player?.pause()
        isPlaying = false
    }
    
    func togglePlayPause() {
        AppLogger.debug.debug("[AudioPlayer] Toggle play/pause - currently playing: \(self.isPlaying)")
        self.isPlaying ? pause() : play()
        saveCurrentPlaybackState()
    }


    func nextChapter() {
        guard let book = book else {
            AppLogger.debug.debug("[AudioPlayer] No book loaded for next chapter")
            return
        }
        
        guard self.currentChapterIndex + 1 < book.chapters.count else {
            AppLogger.debug.debug("[AudioPlayer] Already at last chapter")
            pause()
            return
        }
        
        AppLogger.debug.debug("[AudioPlayer] Moving to next chapter: \(self.currentChapterIndex + 1)")
        setCurrentChapter(index: self.currentChapterIndex + 1)
    }
    
    func previousChapter() {
        guard self.currentChapterIndex > 0 else {
            AppLogger.debug.debug("[AudioPlayer] Already at first chapter")
            return
        }
        
        AppLogger.debug.debug("[AudioPlayer] Moving to previous chapter: \(self.currentChapterIndex - 1)")
        setCurrentChapter(index: self.currentChapterIndex - 1)
    }

    func seek15SecondsBack() {
        let newTime = max(0, self.currentTime - 15)
        AppLogger.debug.debug("[AudioPlayer] Seeking back 15s: \(self.currentTime) -> \(newTime)")
        seek(to: newTime)
    }

    func seek15SecondsForward() {
        let newTime = min(self.duration, self.currentTime + 15)
        AppLogger.debug.debug("[AudioPlayer] Seeking forward 15s: \(self.currentTime) -> \(newTime)")
        seek(to: newTime)
    }

    func seek(to seconds: Double) {
        guard seconds >= 0 && seconds <= self.duration else {
            AppLogger.debug.debug("[AudioPlayer] Invalid seek time: \(seconds) (duration: \(self.duration))")
            return
        }
        
        let time = CMTime(seconds: seconds, preferredTimescale: 1)
        AppLogger.debug.debug("[AudioPlayer] Seeking to: \(seconds)s")
        player?.seek(to: time)
        saveCurrentPlaybackState()
    }


    private func addTimeObserver() {
        guard let player = player else { return }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = CMTimeGetSeconds(time)
        }
    }
    
    // MARK: - Persistence Integration

    private func setupPersistence() {
        // Listen for auto-save notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoSave),
            name: .playbackAutoSave,
            object: nil
        )
        
        // Save when app goes to background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func handleAutoSave() {
        saveCurrentPlaybackState()
    }

    @objc private func handleAppBackground() {
        saveCurrentPlaybackState()
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
        
        AppLogger.debug.debug("[AudioPlayer] Playback rate set to: \(rate)x (applied: \(self.isPlaying))")
    }
    
    @objc private func playerItemDidFinishPlaying(_ notification: Notification) {
        AppLogger.debug.debug("[AudioPlayer] Chapter finished - auto-advancing to next")
        
        guard let book = book, self.currentChapterIndex + 1 < book.chapters.count else {
            AppLogger.debug.debug("[AudioPlayer] Book finished - stopping playback")
            DispatchQueue.main.async { [weak self] in
                self?.isPlaying = false
            }
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.nextChapter()
        }
    }
    
    // MARK: - Observer
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath, let playerItem = object as? AVPlayerItem else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch keyPath {
            case "status":
                switch playerItem.status {
                case .readyToPlay:
                    self.errorMessage = nil
                    AppLogger.debug.debug("[AudioPlayer] Player item ready to play")
                case .failed:
                    let errorDescription = playerItem.error?.localizedDescription ?? "Unknown error"
                    self.errorMessage = errorDescription
                    AppLogger.debug.debug("[AudioPlayer] Player item failed: \(errorDescription)")
                case .unknown:
                    AppLogger.debug.debug("[AudioPlayer] Player item status unknown")
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
        cleanupPlayer()
        NotificationCenter.default.removeObserver(self)
    }
}
