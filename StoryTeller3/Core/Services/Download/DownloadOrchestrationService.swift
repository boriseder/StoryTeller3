import Foundation

// MARK: - Progress Callback Type

/// Progress callback type
typealias DownloadProgressCallback = (String, Double, String, DownloadStage) -> Void

// MARK: - Protocol

/// Service responsible for orchestrating the download process
protocol DownloadOrchestrationService {
    /// Downloads a book with all its components
    func downloadBook(_ book: Book, api: AudiobookshelfAPI, onProgress: @escaping DownloadProgressCallback) async throws
    
    /// Cancels an ongoing download
    func cancelDownload(for bookId: String)
}

// MARK: - Default Implementation

final class DefaultDownloadOrchestrationService: DownloadOrchestrationService {
    
    // MARK: - Properties
    private let networkService: DownloadNetworkService
    private let storageService: DownloadStorageService
    private let retryPolicy: RetryPolicyService
    private let validationService: DownloadValidationService
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    init(
        networkService: DownloadNetworkService,
        storageService: DownloadStorageService,
        retryPolicy: RetryPolicyService,
        validationService: DownloadValidationService
    ) {
        self.networkService = networkService
        self.storageService = storageService
        self.retryPolicy = retryPolicy
        self.validationService = validationService
    }
    
    // MARK: - DownloadOrchestrationService
    
    func downloadBook(_ book: Book, api: AudiobookshelfAPI, onProgress: @escaping DownloadProgressCallback) async throws {
        // Stage 1: Create directory
        onProgress(book.id, 0.05, "Creating download folder...", .preparing)
        let bookDir = try storageService.createBookDirectory(for: book.id)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Stage 2: Fetch metadata
        onProgress(book.id, 0.10, "Fetching book details...", .fetchingMetadata)
        let fullBook = try await api.fetchBookDetails(bookId: book.id)
        
        // Stage 3: Save metadata
        onProgress(book.id, 0.15, "Saving book information...", .fetchingMetadata)
        try storageService.saveBookMetadata(fullBook, to: bookDir)
        
        // Stage 4: Download cover
        if let coverPath = fullBook.coverPath {
            onProgress(book.id, 0.20, "Downloading cover...", .downloadingCover)
            try await downloadCoverWithRetry(
                bookId: fullBook.id,
                coverPath: coverPath,
                api: api,
                bookDir: bookDir
            )
        }
        
        // Stage 5: Download audio files
        onProgress(book.id, 0.25, "Downloading audio files...", .downloadingAudio)
        try await Task.sleep(nanoseconds: 200_000_000)
        try await downloadAudioFiles(
            for: fullBook,
            api: api,
            bookDir: bookDir,
            onProgress: onProgress
        )
        
        // Stage 6: Validate
        onProgress(book.id, 0.95, "Verifying download...", .finalizing)
        let validation = validationService.validateBookIntegrity(
            bookId: fullBook.id,
            storageService: storageService
        )
        
        guard validation.isValid else {
            throw DownloadError.verificationFailed
        }
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Stage 7: Complete
        onProgress(book.id, 1.0, "Download complete!", .complete)
        AppLogger.general.debug("[DownloadOrchestration] Successfully downloaded: \(fullBook.title)")
    }
    
    func cancelDownload(for bookId: String) {
        downloadTasks[bookId]?.cancel()
        downloadTasks.removeValue(forKey: bookId)
        AppLogger.general.debug("[DownloadOrchestration] Cancelled download: \(bookId)")
    }
    
    // MARK: - Private Methods
    
    private func downloadCoverWithRetry(
        bookId: String,
        coverPath: String,
        api: AudiobookshelfAPI,
        bookDir: URL
    ) async throws {
        guard let coverURL = URL(string: "\(api.baseURLString)\(coverPath)") else {
            throw DownloadError.invalidCoverURL
        }
        
        var lastError: Error?
        
        for attempt in 0..<retryPolicy.maxRetries {
            do {
                let data = try await networkService.downloadFile(from: coverURL, authToken: api.authToken)
                let coverFile = bookDir.appendingPathComponent("cover.jpg")
                try storageService.saveCoverImage(data, to: coverFile)
                
                AppLogger.general.debug("[DownloadOrchestration] Cover downloaded successfully")
                return
                
            } catch {
                lastError = error
                AppLogger.general.debug("[DownloadOrchestration] Cover download attempt \(attempt + 1) failed: \(error)")
                
                if retryPolicy.shouldRetry(attempt: attempt, error: error) {
                    let delay = retryPolicy.delay(for: attempt)
                    try await Task.sleep(nanoseconds: delay)
                } else {
                    break
                }
            }
        }
        
        throw DownloadError.coverDownloadFailed(underlying: lastError)
    }
    
    private func downloadAudioFiles(
        for book: Book,
        api: AudiobookshelfAPI,
        bookDir: URL,
        onProgress: @escaping DownloadProgressCallback
    ) async throws {
        guard let firstChapter = book.chapters.first,
              let libraryItemId = firstChapter.libraryItemId else {
            throw DownloadError.missingLibraryItemId
        }
        
        let audioDir = bookDir.appendingPathComponent("audio", isDirectory: true)
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        
        let session = try await networkService.createPlaybackSession(libraryItemId: libraryItemId, api: api)
        let totalTracks = session.audioTracks.count
        
        AppLogger.general.debug("[DownloadOrchestration] Downloading \(totalTracks) audio tracks")
        
        for (index, audioTrack) in session.audioTracks.enumerated() {
            let audioURL = URL(string: "\(api.baseURLString)\(audioTrack.contentUrl)")!
            let fileName = "chapter_\(index).mp3"
            let localURL = audioDir.appendingPathComponent(fileName)
            
            try await downloadAudioFileWithRetry(
                from: audioURL,
                to: localURL,
                api: api,
                bookId: book.id,
                totalTracks: totalTracks,
                currentTrack: index,
                onProgress: onProgress
            )
        }
    }
    
    private func downloadAudioFileWithRetry(
        from url: URL,
        to localURL: URL,
        api: AudiobookshelfAPI,
        bookId: String,
        totalTracks: Int,
        currentTrack: Int,
        onProgress: @escaping DownloadProgressCallback
    ) async throws {
        var lastError: Error?
        
        for attempt in 0..<retryPolicy.maxRetries {
            do {
                let chapterNum = currentTrack + 1
                let attemptInfo = attempt > 0 ? " (retry \(attempt))" : ""
                onProgress(bookId, 0.0, "Downloading chapter \(chapterNum)/\(totalTracks)\(attemptInfo)...", .downloadingAudio)
                
                let data = try await networkService.downloadFile(from: url, authToken: api.authToken)
                try storageService.saveAudioFile(data, to: localURL)
                
                let baseProgress = 0.25
                let audioProgress = 0.70 * (Double(currentTrack + 1) / Double(totalTracks))
                let percentComplete = Int((Double(chapterNum) / Double(totalTracks)) * 100)
                onProgress(bookId, baseProgress + audioProgress, "Downloaded chapter \(chapterNum)/\(totalTracks) (\(percentComplete)%)", .downloadingAudio)
                
                AppLogger.general.debug("[DownloadOrchestration] Chapter \(chapterNum)/\(totalTracks) downloaded")
                return
                
            } catch {
                lastError = error
                AppLogger.general.debug("[DownloadOrchestration] Chapter \(currentTrack + 1) attempt \(attempt + 1) failed: \(error)")
                
                if retryPolicy.shouldRetry(attempt: attempt, error: error) {
                    let delay = retryPolicy.delay(for: attempt)
                    try await Task.sleep(nanoseconds: delay)
                } else {
                    break
                }
            }
        }
        
        throw DownloadError.audioDownloadFailed(chapter: currentTrack + 1, underlying: lastError)
    }
}
