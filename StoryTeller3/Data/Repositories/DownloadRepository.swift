import Foundation

// MARK: - Download Status
struct DownloadStatus {
    let bookId: String
    let isDownloaded: Bool
    let isDownloading: Bool
    let progress: Double
    let stage: DownloadStage?
    let statusMessage: String?
    
    var isAvailableOffline: Bool {
        isDownloaded
    }
}

// MARK: - Repository Protocol
protocol DownloadRepositoryProtocol {
    func getDownloadedBooks() -> [Book]
    func getDownloadStatus(for bookId: String) -> DownloadStatus
    func startDownload(book: Book) async throws
    func cancelDownload(for bookId: String)
    func deleteDownload(for bookId: String)
    func deleteAllDownloads()
    func getLocalAudioURL(for bookId: String, chapterIndex: Int) -> URL?
    func getLocalCoverURL(for bookId: String) -> URL?
    func getTotalDownloadSize() -> Int64
    func getBookStorageSize(for bookId: String) -> Int64
    func validateIntegrity(for bookId: String) -> Bool
}

// MARK: - Download Repository Implementation
class DownloadRepository: DownloadRepositoryProtocol {
    
    private let downloadManager: DownloadManager
    private let storageMonitor: StorageMonitoring
    
    init(
        downloadManager: DownloadManager,
        storageMonitor: StorageMonitoring = StorageMonitor()
    ) {
        self.downloadManager = downloadManager
        self.storageMonitor = storageMonitor
    }
    
    // MARK: - Query Methods
    
    func getDownloadedBooks() -> [Book] {
        downloadManager.downloadedBooks
    }
    
    func getDownloadStatus(for bookId: String) -> DownloadStatus {
        DownloadStatus(
            bookId: bookId,
            isDownloaded: downloadManager.isBookDownloaded(bookId),
            isDownloading: downloadManager.isDownloadingBook(bookId),
            progress: downloadManager.getDownloadProgress(for: bookId),
            stage: downloadManager.downloadStage[bookId],
            statusMessage: downloadManager.downloadStatus[bookId]
        )
    }
    
    // MARK: - Download Operations
    
    func startDownload(book: Book) async throws {
        guard storageMonitor.hasEnoughSpace(required: 500_000_000) else {
            throw DownloadRepositoryError.insufficientStorage
        }
        
        guard let api = getAPIClient() else {
            throw DownloadRepositoryError.noAPIClient
        }
        
        await downloadManager.downloadBook(book, api: api)
    }
    
    func cancelDownload(for bookId: String) {
        downloadManager.cancelDownload(for: bookId)
    }
    
    func deleteDownload(for bookId: String) {
        downloadManager.deleteBook(bookId)
        AppLogger.debug.debug("[DownloadRepository] Deleted download for book: \(bookId)")
    }
    
    func deleteAllDownloads() {
        downloadManager.deleteAllBooks()
        AppLogger.debug.debug("[DownloadRepository] Deleted all downloads")
    }
    
    // MARK: - File Access
    
    func getLocalAudioURL(for bookId: String, chapterIndex: Int) -> URL? {
        downloadManager.getLocalAudioURL(for: bookId, chapterIndex: chapterIndex)
    }
    
    func getLocalCoverURL(for bookId: String) -> URL? {
        downloadManager.getLocalCoverURL(for: bookId)
    }
    
    // MARK: - Storage Info
    
    func getTotalDownloadSize() -> Int64 {
        downloadManager.getTotalDownloadSize()
    }
    
    func getBookStorageSize(for bookId: String) -> Int64 {
        downloadManager.getBookStorageSize(bookId)
    }
    
    // MARK: - Validation
    
    func validateIntegrity(for bookId: String) -> Bool {
        downloadManager.validateBookIntegrity(bookId)
    }
    
    // MARK: - Private Helpers
    
    private func getAPIClient() -> AudiobookshelfAPI? {
        guard let baseURL = UserDefaults.standard.string(forKey: "baseURL"),
              let apiKey = UserDefaults.standard.string(forKey: "apiKey") else {
            return nil
        }
        
        return AudiobookshelfAPI(baseURL: baseURL, apiKey: apiKey)
    }
}

// MARK: - Download Repository Errors
enum DownloadRepositoryError: LocalizedError {
    case insufficientStorage
    case noAPIClient
    case downloadFailed(Error)
    case integrityCheckFailed
    
    var errorDescription: String? {
        switch self {
        case .insufficientStorage:
            return "Not enough storage space available"
        case .noAPIClient:
            return "No API configuration found"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .integrityCheckFailed:
            return "Downloaded files are incomplete or corrupted"
        }
    }
}
