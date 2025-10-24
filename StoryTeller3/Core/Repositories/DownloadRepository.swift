import Foundation

// MARK: - Protocol

/// Repository for managing download data and operations
protocol DownloadRepository {
    /// Downloads a book
    func downloadBook(_ book: Book, api: AudiobookshelfAPI) async throws
    
    /// Cancels a download
    func cancelDownload(for bookId: String)
    
    /// Cancels all downloads
    func cancelAllDownloads()
    
    /// Deletes a downloaded book
    func deleteBook(_ bookId: String)
    
    /// Deletes all downloaded books
    func deleteAllBooks()
    
    /// Gets all downloaded books
    func getDownloadedBooks() -> [Book]
    
    /// Checks if a book is downloaded
    func isBookDownloaded(_ bookId: String) -> Bool
    
    /// Gets the offline status of a book
    func getOfflineStatus(for bookId: String) -> OfflineStatus
    
    /// Gets the download status for a book
    func getDownloadStatus(for bookId: String) -> DownloadStatus

    /// Gets download progress for a book
    func getDownloadProgress(for bookId: String) -> Double
    
    /// Gets the local audio URL for a chapter
    func getLocalAudioURL(for bookId: String, chapterIndex: Int) -> URL?
    
    /// Gets the local cover URL for a book
    func getLocalCoverURL(for bookId: String) -> URL?
    
    /// Gets the total download size
    func getTotalDownloadSize() -> Int64
    
    /// Gets the storage size of a specific book
    func getBookStorageSize(_ bookId: String) -> Int64
    
    /// Gets the book directory URL for a given book ID
    func bookDirectory(for bookId: String) -> URL
    
    /// Sets the progress callback
    var onProgress: DownloadProgressCallback? { get set }
}

// MARK: - Default Implementation

final class DefaultDownloadRepository: DownloadRepository {
    
    // MARK: - Properties
    private let orchestrationService: DownloadOrchestrationService
    private let storageService: DownloadStorageService
    private let validationService: DownloadValidationService
    private let healingService: BackgroundHealingService
    private weak var downloadManager: DownloadManager?
    
    var onProgress: DownloadProgressCallback?
    
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    init(
        orchestrationService: DownloadOrchestrationService,
        storageService: DownloadStorageService,
        validationService: DownloadValidationService,
        healingService: BackgroundHealingService,
        downloadManager: DownloadManager
    ) {
        self.orchestrationService = orchestrationService
        self.storageService = storageService
        self.validationService = validationService
        self.healingService = healingService
        self.downloadManager = downloadManager
        
        // Load existing downloads
        loadDownloadedBooks()
        
        // Start background healing
        healingService.start()
    }
    
    // MARK: - DownloadRepository
    
    func downloadBook(_ book: Book, api: AudiobookshelfAPI) async throws {
        // Check storage
        guard storageService.checkAvailableStorage(requiredSpace: 500_000_000) else {
            throw DownloadError.insufficientStorage
        }
        
        // Check if already downloaded or downloading
        guard !isBookDownloaded(book.id),
              let manager = downloadManager,
              !manager.isDownloadingBook(book.id) else {
            AppLogger.general.debug("[DownloadRepository] Book already downloaded or downloading")
            return
        }
        
        let task = Task { @MainActor in
            guard let manager = downloadManager else { return }
            
            manager.isDownloading[book.id] = true
            manager.downloadProgress[book.id] = 0.0
            manager.downloadStage[book.id] = .preparing
            manager.downloadStatus[book.id] = "Preparing download..."
            
            do {
                try await orchestrationService.downloadBook(book, api: api) { [weak self, weak manager] bookId, progress, status, stage in
                    Task { @MainActor in
                        manager?.downloadProgress[bookId] = progress
                        manager?.downloadStatus[bookId] = status
                        manager?.downloadStage[bookId] = stage
                        self?.onProgress?(bookId, progress, status, stage)
                    }
                }
                
                // Success - load the book
                if let downloadedBook = loadBook(bookId: book.id) {
                    manager.downloadedBooks.append(downloadedBook)
                    manager.isDownloading[book.id] = false
                    manager.downloadProgress[book.id] = 1.0
                    manager.downloadStage[book.id] = .complete
                    manager.downloadStatus[book.id] = "Download complete!"
                    
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    
                    manager.downloadStatus.removeValue(forKey: book.id)
                    manager.downloadStage.removeValue(forKey: book.id)
                }
                
            } catch is CancellationError {
                AppLogger.general.debug("[DownloadRepository] Download cancelled: \(book.title)")
                
                manager.isDownloading[book.id] = false
                manager.downloadProgress[book.id] = 0.0
                manager.downloadStage[book.id] = .failed
                manager.downloadStatus[book.id] = "Download cancelled"
                
                cleanupFailedDownload(bookId: book.id)
                
            } catch let error as DownloadError {
                AppLogger.general.error("[DownloadRepository] Download failed: \(error.localizedDescription)")
                
                manager.isDownloading[book.id] = false
                manager.downloadProgress[book.id] = 0.0
                manager.downloadStage[book.id] = .failed
                manager.downloadStatus[book.id] = error.localizedDescription
                
                cleanupFailedDownload(bookId: book.id)
                
            } catch {
                AppLogger.general.error("[DownloadRepository] Download failed: \(error.localizedDescription)")
                
                manager.isDownloading[book.id] = false
                manager.downloadProgress[book.id] = 0.0
                manager.downloadStage[book.id] = .failed
                manager.downloadStatus[book.id] = "Download failed: \(error.localizedDescription)"
                
                cleanupFailedDownload(bookId: book.id)
            }
        }
        
        downloadTasks[book.id] = task
        await task.value
        downloadTasks.removeValue(forKey: book.id)
    }
    
    func cancelDownload(for bookId: String) {
        orchestrationService.cancelDownload(for: bookId)
        downloadTasks[bookId]?.cancel()
        downloadTasks.removeValue(forKey: bookId)
    }
    
    func cancelAllDownloads() {
        for bookId in downloadTasks.keys {
            cancelDownload(for: bookId)
        }
        
        Task { @MainActor in
            guard let manager = downloadManager else { return }
            manager.isDownloading.removeAll()
            manager.downloadProgress.removeAll()
            manager.downloadStatus.removeAll()
            manager.downloadStage.removeAll()
        }
    }
    
    func deleteBook(_ bookId: String) {
        let bookDir = storageService.bookDirectory(for: bookId)
        
        do {
            try storageService.deleteBookDirectory(at: bookDir)
            
            Task { @MainActor in
                guard let manager = downloadManager else { return }
                manager.downloadedBooks.removeAll { $0.id == bookId }
                manager.downloadProgress.removeValue(forKey: bookId)
                manager.isDownloading.removeValue(forKey: bookId)
            }
            
            AppLogger.general.debug("[DownloadRepository] Deleted book: \(bookId)")
        } catch {
            AppLogger.general.error("[DownloadRepository] Failed to delete book: \(error)")
        }
    }
    
    func deleteAllBooks() {
        let allBooks = getDownloadedBooks()
        
        for book in allBooks {
            deleteBook(book.id)
        }
        
        Task { @MainActor in
            guard let manager = downloadManager else { return }
            manager.downloadedBooks.removeAll()
            manager.downloadProgress.removeAll()
            manager.isDownloading.removeAll()
            manager.downloadStatus.removeAll()
            manager.downloadStage.removeAll()
        }
        
        AppLogger.general.debug("[DownloadRepository] Deleted all books")
    }
    
    func getDownloadedBooks() -> [Book] {
        return downloadManager?.downloadedBooks ?? []
    }
    
    func isBookDownloaded(_ bookId: String) -> Bool {
        let metadataFile = storageService.bookDirectory(for: bookId).appendingPathComponent("metadata.json")
        return FileManager.default.fileExists(atPath: metadataFile.path)
    }
    
    func getOfflineStatus(for bookId: String) -> OfflineStatus {
        if downloadManager?.isDownloadingBook(bookId) == true {
            return .downloading
        }
        
        if isBookDownloaded(bookId) {
            let validation = validationService.validateBookIntegrity(
                bookId: bookId,
                storageService: storageService
            )
            if validation.isValid {
                return .available
            }
        }
        
        return .notDownloaded
    }
    
    func getDownloadStatus(for bookId: String) -> DownloadStatus {
        let offlineStatus = getOfflineStatus(for: bookId)
        
        switch offlineStatus {
        case .notDownloaded:
            return DownloadStatus(isDownloaded: false, isDownloading: false)
        case .downloading:
            return DownloadStatus(isDownloaded: false, isDownloading: true)
        case .available:
            return DownloadStatus(isDownloaded: true, isDownloading: false)
        }
    }
    
    func getDownloadProgress(for bookId: String) -> Double {
        return downloadManager?.downloadProgress[bookId] ?? 0.0
    }
    
    func getLocalAudioURL(for bookId: String, chapterIndex: Int) -> URL? {
        return storageService.getLocalAudioURL(for: bookId, chapterIndex: chapterIndex)
    }
    
    func getLocalCoverURL(for bookId: String) -> URL? {
        return storageService.getLocalCoverURL(for: bookId)
    }
    
    func getTotalDownloadSize() -> Int64 {
        return storageService.getTotalDownloadSize()
    }
    
    func getBookStorageSize(_ bookId: String) -> Int64 {
        return storageService.getBookStorageSize(bookId)
    }
    
    func bookDirectory(for bookId: String) -> URL {
        return storageService.bookDirectory(for: bookId)
    }
    
    // MARK: - Private Methods
    
    private func loadDownloadedBooks() {
        let books = storageService.loadDownloadedBooks()
        
        // Filter only valid books
        let validBooks = books.filter { book in
            let validation = validationService.validateBookIntegrity(
                bookId: book.id,
                storageService: storageService
            )
            return validation.isValid
        }
        
        Task { @MainActor in
            guard let manager = downloadManager else { return }
            manager.downloadedBooks = validBooks
        }
        
        AppLogger.general.debug("[DownloadRepository] Loaded \(validBooks.count) valid books")
    }
    
    private func loadBook(bookId: String) -> Book? {
        let metadataFile = storageService.bookDirectory(for: bookId).appendingPathComponent("metadata.json")
        
        guard let data = try? Data(contentsOf: metadataFile),
              let book = try? JSONDecoder().decode(Book.self, from: data) else {
            return nil
        }
        
        return book
    }
    
    private func cleanupFailedDownload(bookId: String) {
        let bookDir = storageService.bookDirectory(for: bookId)
        try? storageService.deleteBookDirectory(at: bookDir)
    }
    
    deinit {
        healingService.stop()
        cancelAllDownloads()
    }
}
