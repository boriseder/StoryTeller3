import Foundation
import AVFoundation
import Combine
import AVKit  // ← Hinzufügen für AVRoutePickerView
import UIKit  // ← Hinzufügen für UIColor

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

    var currentChapter: Chapter? {
        guard let book = book, currentChapterIndex < book.chapters.count else { return nil }
        return book.chapters[currentChapterIndex]
    }
    
    // MARK: - Public Properties for UI Integration
    var downloadManagerReference: DownloadManager? {
        return downloadManager
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
    func load(book: Book, isOffline: Bool = false) {
        self.book = book
        self.currentChapterIndex = 0
        self.isOfflineMode = isOffline
        loadChapter()
    }

    func loadChapter() {
        guard let chapter = currentChapter else {
            #if DEBUG
            print("[AudioPlayer] ERROR: Kein aktuelles Kapitel gefunden")
            #endif
            errorMessage = "Kein Kapitel verfügbar"
            return
        }
        #if DEBUG
        print("[AudioPlayer] Lade Kapitel: \(chapter.title)")
        print("[AudioPlayer] Kapitel Index: \(currentChapterIndex)")
        print("[AudioPlayer] Offline Mode: \(isOfflineMode)")
        print("[AudioPlayer] Library Item ID: \(chapter.libraryItemId ?? "nil")")
        #endif

        isLoading = true
        errorMessage = nil
        
        // Check for offline mode first
        if isOfflineMode {
            loadOfflineChapter(chapter)
            return
        }
        
        // Online mode
        createPlaybackSession(for: chapter) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let session):
                    #if DEBUG
                    print("[AudioPlayer] SUCCESS: Playback Session erstellt: \(session.id)")
                    #endif
                    self?.currentPlaybackSession = session
                    self?.setupPlayerWithSession(session)
                case .failure(let error):
                    #if DEBUG
                    print("[AudioPlayer] ERROR: Fehler beim Erstellen der Playback Session: \(error)")
                    #endif
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Public Chapter Management
    func setCurrentChapter(index: Int) {
        guard let book = book, index >= 0, index < book.chapters.count else {
            #if DEBUG
            print("[AudioPlayer] ERROR: Ungültiger Kapitel-Index: \(index)")
            #endif
            return
        }
        
        let wasPlaying = isPlaying
        currentChapterIndex = index
        #if DEBUG
        print("[AudioPlayer] Wechsle zu Kapitel \(index): \(book.chapters[index].title)")
        #endif

        if wasPlaying {
            isPlaying = true
        }
        loadChapter()
    }
    
    private func loadOfflineChapter(_ chapter: Chapter) {
        guard let book = book,
              let downloadManager = downloadManager else {
            isLoading = false
            errorMessage = "Download Manager nicht verfügbar"
            return
        }
        
        Task { @MainActor in
            if downloadManager.isBookDownloaded(book.id),
               let localURL = downloadManager.getLocalAudioURL(for: book.id, chapterIndex: currentChapterIndex) {
                
                #if DEBUG
                print("[AudioPlayer] Datei URL: \(localURL)")
                print("[AudioPlayer] Existiert: \(FileManager.default.fileExists(atPath: localURL.path))")
                #endif
                
                let playerItem = AVPlayerItem(url: localURL)
                setupOfflinePlayer(playerItem: playerItem, duration: chapter.end ?? 3600)
            } else {
                errorMessage = "Offline-Audiodatei nicht gefunden"
            }
            isLoading = false
        }
    }
    
    private func setupOfflinePlayer(playerItem: AVPlayerItem, duration: Double) {
        cleanupPlayer()
        player = AVPlayer(playerItem: playerItem)
        setupPlayerItemObservers(playerItem)
        addTimeObserver()
        self.duration = duration
        
        if isPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.play()
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
        #if DEBUG
        print("[AudioPlayer] Erstelle Playback Session: \(url)")
        #endif
        
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
                #if DEBUG
                print("[AudioPlayer] Playback Session erstellt: \(session.id)")
                #endif
                completion(.success(session))
            } catch {
                #if DEBUG
                print("[AudioPlayer] ERROR: JSON Decode Fehler: \(error)")
                #endif
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func setupPlayerWithSession(_ session: PlaybackSessionResponse) {
        
        #if DEBUG
        print("[AudioPlayer] Setting up player with session: \(session.id)")
        print("[AudioPlayer] Available tracks: \(session.audioTracks.count)")
        print("[AudioPlayer] Current chapter index: \(currentChapterIndex)")
        #endif
        
        guard currentChapterIndex < session.audioTracks.count else {
            #if DEBUG
            print("[AudioPlayer] ERROR: Kapitel-Index außerhalb der verfügbaren Tracks")
            #endif
            errorMessage = "Kapitel-Index ungültig"
            return
        }
        
        let audioTrack = session.audioTracks[currentChapterIndex]
        let fullURL = "\(baseURL)\(audioTrack.contentUrl)"

        #if DEBUG
        print("[AudioPlayer] Audio URL: \(fullURL)")
        print("[AudioPlayer] Track duration: \(audioTrack.duration)")
        #endif

        guard let audioURL = URL(string: fullURL) else {
            #if DEBUG
            print("[AudioPlayer] ERROR: Ungültige Audio URL: \(fullURL)")
            #endif
            errorMessage = "Ungültige Audio-URL"
            return
        }
        
        let asset = createAuthenticatedAsset(url: audioURL)
        let playerItem = AVPlayerItem(asset: asset)
        
        cleanupPlayer()
        
        player = AVPlayer(playerItem: playerItem)
        setupPlayerItemObservers(playerItem)
        addTimeObserver()
        duration = audioTrack.duration
        
        #if DEBUG
        print("[AudioPlayer] Player created, duration set to: \(duration)")
        #endif
        
        if isPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                #if DEBUG
                print("[AudioPlayer] Auto-starting playback...")
                #endif
                
                self.play()
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
        
        #if DEBUG
        print("[AudioPlayer] Player Status: \(currentItem.status)")
        print("[AudioPlayer] Player Rate: \(player.rate)")
        print("[AudioPlayer] Current Time: \(CMTimeGetSeconds(player.currentTime()))")
        print("[AudioPlayer] Duration: \(duration)")
        #endif
        
        switch currentItem.status {
        case .readyToPlay:
            player.play()
            player.rate = playbackRate // Apply current playback rate
            isPlaying = true
        case .failed:
            let error = currentItem.error?.localizedDescription ?? "Unbekannter Fehler"
            errorMessage = "Playback failed: \(error)"
        case .unknown:
            player.play()
            player.rate = playbackRate // ← Hier auch hinzufügen
            isPlaying = true
        @unknown default:
            player.play()
            player.rate = playbackRate // Apply current playback rate
            isPlaying = true
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func nextChapter() {
        guard let book = book, currentChapterIndex + 1 < book.chapters.count else {
            #if DEBUG
            print("[AudioPlayer] INFO: Kein nächstes Kapitel verfügbar")
            #endif
            DispatchQueue.main.async { self.isPlaying = false }
            return
        }
        
        let wasPlaying = isPlaying
        currentChapterIndex += 1
        
        if wasPlaying { isPlaying = true }
        loadChapter()
    }
    
    func previousChapter() {
        guard currentChapterIndex > 0 else {
            return
        }
        currentChapterIndex -= 1
        loadChapter()
    }

    func seek15SecondsBack() {
        seek(to: max(0, currentTime - 15))
    }

    func seek15SecondsForward() {
        seek(to: min(duration, currentTime + 15))
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 1)
        player?.seek(to: time)
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
    
    // MARK: - Playback Speed
    func setPlaybackRate(_ rate: Double) {
        let floatRate = Float(rate)
        playbackRate = floatRate
        player?.rate = floatRate
        
        print("[AudioPlayer] Playback rate set to: \(rate)x")
    }
    
    @objc private func playerItemDidFinishPlaying(_ notification: Notification) {
        #if DEBUG
        print("[AudioPlayer] Kapitel zu Ende - wechsle automatisch zum nächsten")
        #endif
        
        guard let book = book, currentChapterIndex + 1 < book.chapters.count else {
            #if DEBUG
            print("[AudioPlayer] Buch komplett beendet")
            #endif
            DispatchQueue.main.async { self.isPlaying = false }
            return
        }
        
        DispatchQueue.main.async { self.nextChapter() }
    }
    
    // MARK: - Observer
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath, let playerItem = object as? AVPlayerItem else { return }
        
        DispatchQueue.main.async {
            switch keyPath {
            case "status":
                switch playerItem.status {
                case .readyToPlay:
                    self.errorMessage = nil
                case .failed:
                    let errorDescription = playerItem.error?.localizedDescription ?? "Unbekannter Fehler"
                    self.errorMessage = errorDescription
                case .unknown:
                    break
                @unknown default:
                    break
                }
                
            case "loadedTimeRanges":
                let timeRanges = playerItem.loadedTimeRanges
                if !timeRanges.isEmpty {
                    let timeRange = timeRanges[0].timeRangeValue
                  //  let loadedDuration = CMTimeGetSeconds(timeRange.duration)
                }
            default:
                break
            }
        }
    }

    deinit {
        cleanupPlayer()
        // Alle Observer explizit entfernen
        NotificationCenter.default.removeObserver(self)
    }
}
