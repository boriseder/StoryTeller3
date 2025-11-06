import Foundation

// MARK: - Progress Callback Type

/// Progress callback type
typealias DownloadProgressCallback = (String, Double, String, DownloadStage) -> Void

// MARK: - Protocol

/// Service responsible for orchestrating the download process
protocol DownloadOrchestrationService {
    /// Downloads a book with all its components
    func downloadBook(_ book: Book, api: AudiobookshelfClient, onProgress: @escaping DownloadProgressCallback) async throws
    
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
    
    func downloadBook(_ book: Book, api: AudiobookshelfClient, onProgress: @escaping DownloadProgressCallback) async throws {
        // Stage 1: Create directory
        onProgress(book.id, 0.05, "Creating download folder...", .preparing)
        let bookDir = try storageService.createBookDirectory(for: book.id)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Stage 2: Fetch metadata
        onProgress(book.id, 0.10, "Fetching book details...", .fetchingMetadata)
        let fullBook = try await api.books.fetchBookDetails(bookId: book.id, retryCount: 3)

        // Stage 3: Save metadata
        onProgress(book.id, 0.15, "Saving book information...", .fetchingMetadata)
        try storageService.saveBookMetadata(fullBook, to: bookDir)
        
        // Stage 4: Download cover
        
        if let coverPath = fullBook.coverPath {
            onProgress(book.id, 0.20, "Downloading cover...", .downloadingCover)
            try await downloadCoverWithRetry(
                bookId: book.id, // FIXED: Use book.id consistently
                coverPath: coverPath,
                api: api,
                bookDir: bookDir
            )
        }
        
        // Stage 5: Download audio files
        onProgress(book.id, 0.25, "Downloading audio files...", .downloadingAudio)
        try await Task.sleep(nanoseconds: 200_000_000)
        let audioTrackCount = try await downloadAudioFiles(
            for: fullBook,
            api: api,
            bookDir: bookDir,
            onProgress: onProgress
        )
        
        // Stage 5.5: Save audio info for validation
        let audioInfo = AudioInfo(audioTrackCount: audioTrackCount)
        try storageService.saveAudioInfo(audioInfo, to: bookDir)
        AppLogger.general.debug("[DownloadOrchestration] Saved audio info: \(audioTrackCount) tracks")
        
        // RACE CONDITION FIX: Ensure all file operations are flushed to disk
        // This is especially important on iOS where file writes may be buffered
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second buffer
        
        // Stage 6: Validate
        onProgress(book.id, 0.95, "Verifying download...", .finalizing)
        let validation = validationService.validateBookIntegrity(
            bookId: book.id, // FIXED: Use book.id consistently
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
    
    // Downloads cover to book directory for offline use
    // Separate from CoverCacheManager which handles UI caching
    
    private func downloadCoverWithRetry(
        bookId: String,
        coverPath: String,
        api: AudiobookshelfClient,
        bookDir: URL
    ) async throws {
        
        // WRONG ENDPOINT
        /*
        guard let coverURL = URL(string: "\(api.baseURLString)\(coverPath)") else {
            throw DownloadError.invalidCoverURL
        }
         */
        
        // PATCH
        //new endpoint as
        let coverURLString = "\(api.baseURLString)/api/items/\(bookId)/cover"
        guard let url = URL(string: coverURLString) else {
            throw DownloadError.invalidCoverURL
        }
        
        AppLogger.general.debug("#### DIRTY HACK - coverURLString: \(coverURLString)")
                
        var lastError: Error?
        
        for attempt in 0..<retryPolicy.maxRetries {
            do {
                // PATCH
                // actual fix - use the correct endpoint
                // but needs refactoring as redundant!!!
                // old -1 line
                // let data = try await networkService.downloadFile(from: coverURL, authToken: api.authToken)
                // new +1 line
                let data = try await networkService.downloadFile(from: url, authToken: api.authToken)

                let coverFile = bookDir.appendingPathComponent("cover.jpg")

                try storageService.saveCoverImage(data, to: coverFile)
                
                
                AppLogger.general.debug("#### DIRTY HACK - Download of cover.jpg successful")
 
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
        api: AudiobookshelfClient,
        bookDir: URL,
        onProgress: @escaping DownloadProgressCallback
    ) async throws -> Int {
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
        
        return totalTracks
    }
    
    private func downloadAudioFileWithRetry(
        from url: URL,
        to localURL: URL,
        api: AudiobookshelfClient,
        bookId: String,
        totalTracks: Int,
        currentTrack: Int,
        onProgress: @escaping DownloadProgressCallback
    ) async throws {
        var lastError: Error?
        
        // Calculate progress range for this chapter (0.25 to 0.95 for all audio files)
        let baseProgress = 0.25
        let audioProgressRange = 0.70
        let chapterStartProgress = baseProgress + (audioProgressRange * Double(currentTrack) / Double(totalTracks))
        let chapterEndProgress = baseProgress + (audioProgressRange * Double(currentTrack + 1) / Double(totalTracks))
        
        for attempt in 0..<retryPolicy.maxRetries {
            do {
                let chapterNum = currentTrack + 1
                let attemptInfo = attempt > 0 ? " (retry \(attempt))" : ""
                
                // Report start of chapter download with proper incremental progress
                onProgress(bookId, chapterStartProgress, "Downloading chapter \(chapterNum)/\(totalTracks)\(attemptInfo)...", .downloadingAudio)
                
                let data = try await networkService.downloadFile(from: url, authToken: api.authToken)
                try storageService.saveAudioFile(data, to: localURL)
                
                // Report completion of chapter download
                let percentComplete = Int((Double(chapterNum) / Double(totalTracks)) * 100)
                onProgress(bookId, chapterEndProgress, "Downloaded chapter \(chapterNum)/\(totalTracks) (\(percentComplete)%)", .downloadingAudio)
                
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
