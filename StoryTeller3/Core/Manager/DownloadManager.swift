import Foundation
import AVFoundation
import SwiftUI

enum OfflineStatus {
    case notDownloaded
    case downloading
    case available
}

class DownloadManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var downloadedBooks: [Book] = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var isDownloading: [String: Bool] = [:]
    @Published var downloadStatus: [String: String] = [:]
    @Published var downloadStage: [String: DownloadStage] = [:]

    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private var backgroundRepairTask: Task<Void, Never>?
    
    // MARK: - Configuration
    private let maxRetries = 3
    private let retryDelays: [UInt64] = [
        2_000_000_000,  // 2 seconds
        5_000_000_000,  // 5 seconds
        10_000_000_000  // 10 seconds
    ]

    // MARK: - Directory URLs
    
    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var downloadsURL: URL {
        documentsURL.appendingPathComponent("Downloads", isDirectory: true)
    }
    
    func bookDirectory(for bookId: String) -> URL {
        downloadsURL.appendingPathComponent(bookId, isDirectory: true)
    }
    
    // MARK: - Initialization
    
    init() {
        createDownloadsDirectory()
        loadDownloadedBooks()
        startBackgroundHealing()
    }
    
    // MARK: - Directory Management
    
    private func createDownloadsDirectory() {
        if !fileManager.fileExists(atPath: downloadsURL.path) {
            do {
                try fileManager.createDirectory(at: downloadsURL, withIntermediateDirectories: true)
                AppLogger.general.debug("[DownloadManager] Created downloads directory")
            } catch {
                AppLogger.general.debug("[DownloadManager] Failed to create downloads directory: \(error)")
            }
        }
    }
    
    // MARK: - Background Healing System
    
    private func startBackgroundHealing() {
        backgroundRepairTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Wait for app to settle
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            
            await self.validateAndRepairDownloads()
            
            // Monitor network changes for healing opportunities
            for await _ in NotificationCenter.default.notifications(named: .networkConnectivityChanged) {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await self.validateAndRepairDownloads()
            }
        }
    }
    
    private func validateAndRepairDownloads() async {
        guard fileManager.fileExists(atPath: downloadsURL.path) else { return }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: downloadsURL,
                includingPropertiesForKeys: nil
            )
            
            for bookDir in contents where bookDir.hasDirectoryPath {
                let bookId = bookDir.lastPathComponent
                
                // Skip if currently downloading
                let isCurrentlyDownloading = await MainActor.run {
                    isDownloading[bookId] ?? false
                }
                if isCurrentlyDownloading { continue }
                
                // Check integrity
                if !validateBookIntegrity(bookId) {
                    AppLogger.general.debug("[DownloadManager] Found incomplete download: \(bookId)")
                    
                    // Delete incomplete downloads - they are useless
                    forceDeleteBookDirectory(bookDir)
                    
                    // Remove from UI if somehow loaded
                    await MainActor.run {
                        downloadedBooks.removeAll { $0.id == bookId }
                    }
                }
            }
        } catch {
            AppLogger.general.debug("[DownloadManager] Validation scan failed: \(error)")
        }
    }
    
    // MARK: - Query Methods
    
    func getOfflineStatus(for bookId: String) -> OfflineStatus {
        if isDownloading[bookId] == true {
            return .downloading
        }
        
        if isBookDownloaded(bookId) && validateBookIntegrity(bookId) {
            return .available
        }
        
        return .notDownloaded
    }

    func isBookAvailableOffline(_ bookId: String) -> Bool {
        return getOfflineStatus(for: bookId) == .available
    }
    
    func isBookDownloaded(_ bookId: String) -> Bool {
        let bookDir = bookDirectory(for: bookId)
        let metadataFile = bookDir.appendingPathComponent("metadata.json")
        return fileManager.fileExists(atPath: metadataFile.path)
    }
    
    func getDownloadProgress(for bookId: String) -> Double {
        downloadProgress[bookId] ?? 0.0
    }
    
    func isDownloadingBook(_ bookId: String) -> Bool {
        isDownloading[bookId] ?? false
    }
    
    // MARK: - Download Operations with Auto-Retry
    
    func downloadBook(_ book: Book, api: AudiobookshelfAPI) async {
        guard checkAvailableStorage() else {
            await MainActor.run {
                downloadStage[book.id] = .failed
                downloadStatus[book.id] = "Insufficient storage space. Please free up at least 500MB."
            }
            return
        }
        
        let isAlreadyProcessed = await MainActor.run {
            isBookDownloaded(book.id) || isDownloadingBook(book.id)
        }
        
        guard !isAlreadyProcessed else {
            AppLogger.general.debug("[DownloadManager] Book already downloaded or downloading")
            return
        }
        
        AppLogger.general.debug("[DownloadManager] Starting download: \(book.title)")
        
        let downloadTask = Task { @MainActor in
            await performDownload(book: book, api: api)
        }
        
        await MainActor.run {
            downloadTasks[book.id] = downloadTask
        }
        
        await downloadTask.value
        
        await MainActor.run {
            downloadTasks.removeValue(forKey: book.id)
        }
    }

    private func performDownload(book: Book, api: AudiobookshelfAPI) async {
        await MainActor.run {
            isDownloading[book.id] = true
            downloadProgress[book.id] = 0.0
            downloadStage[book.id] = .preparing
            downloadStatus[book.id] = "Preparing download..."
        }
        
        let bookDir = bookDirectory(for: book.id)
        
        do {
            try Task.checkCancellation()
            
            // Stage 1: Create directory
            await MainActor.run {
                downloadStage[book.id] = .preparing
                downloadStatus[book.id] = "Creating download folder..."
            }
            
            try fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)
            
            await MainActor.run {
                downloadProgress[book.id] = 0.05
            }
            
            try await Task.sleep(nanoseconds: 100_000_000)
            try Task.checkCancellation()
            
            // Stage 2: Fetch metadata
            await MainActor.run {
                downloadStage[book.id] = .fetchingMetadata
                downloadStatus[book.id] = "Fetching book details..."
            }
            
            let fullBook = try await api.fetchBookDetails(bookId: book.id)
            
            await MainActor.run {
                downloadProgress[book.id] = 0.10
            }
            
            try Task.checkCancellation()
            
            // Stage 3: Save metadata
            await MainActor.run {
                downloadStatus[book.id] = "Saving book information..."
            }
            
            try await saveBookMetadata(fullBook, to: bookDir)
            
            await MainActor.run {
                downloadProgress[book.id] = 0.15
            }
            
            try Task.checkCancellation()
            
            // Stage 4: Download cover with retry
            if let coverPath = fullBook.coverPath {
                await MainActor.run {
                    downloadStage[book.id] = .downloadingCover
                    downloadStatus[book.id] = "Downloading cover..."
                }
                
                try await downloadCoverWithRetry(
                    bookId: book.id,
                    coverPath: coverPath,
                    api: api,
                    bookDir: bookDir
                )
                
                await MainActor.run {
                    downloadProgress[book.id] = 0.20
                }
            }
            
            try Task.checkCancellation()
            
            // Stage 5: Download audio files with retry
            await MainActor.run {
                downloadStage[book.id] = .downloadingAudio
                downloadStatus[book.id] = "Downloading audio files..."
            }
            
            try await Task.sleep(nanoseconds: 200_000_000)
            
            try await downloadAudioFilesWithRetry(for: fullBook, api: api, bookDir: bookDir)
            
            try Task.checkCancellation()
            
            // Stage 6: Final verification
            await MainActor.run {
                downloadStage[book.id] = .finalizing
                downloadStatus[book.id] = "Verifying download..."
                downloadProgress[book.id] = 0.95
            }
            
            guard validateBookIntegrity(fullBook.id) else {
                throw DownloadError.verificationFailed
            }
            
            try await Task.sleep(nanoseconds: 500_000_000)
            try Task.checkCancellation()
            
            // Stage 7: Complete
            await MainActor.run {
                downloadedBooks.append(fullBook)
                isDownloading[book.id] = false
                downloadProgress[book.id] = 1.0
                downloadStage[book.id] = .complete
                downloadStatus[book.id] = "Download complete!"
                
                AppLogger.general.debug("[DownloadManager] Successfully downloaded: \(fullBook.title)")
            }
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                downloadStatus.removeValue(forKey: book.id)
                downloadStage.removeValue(forKey: book.id)
            }
            
        } catch is CancellationError {
            AppLogger.general.debug("[DownloadManager] Download cancelled: \(book.title)")
            
            await MainActor.run {
                isDownloading[book.id] = false
                downloadProgress[book.id] = 0.0
                downloadStage[book.id] = .failed
                downloadStatus[book.id] = "Download cancelled"
            }
            
            forceDeleteBookDirectory(bookDir)
            
        } catch let error as DownloadError {
            AppLogger.general.debug("[DownloadManager] Download failed: \(error.localizedDescription)")
            
            await MainActor.run {
                isDownloading[book.id] = false
                downloadProgress[book.id] = 0.0
                downloadStage[book.id] = .failed
                downloadStatus[book.id] = error.localizedDescription
            }
            
            forceDeleteBookDirectory(bookDir)
            
        } catch {
            AppLogger.general.debug("[DownloadManager] Download failed: \(error.localizedDescription)")
            
            await MainActor.run {
                isDownloading[book.id] = false
                downloadProgress[book.id] = 0.0
                downloadStage[book.id] = .failed
                downloadStatus[book.id] = "Download failed: \(error.localizedDescription)"
            }
            
            forceDeleteBookDirectory(bookDir)
        }
    }

    // MARK: - Resilient Download with Retry
    
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
        
        for attempt in 0..<maxRetries {
            do {
                try await downloadSingleFile(
                    from: coverURL,
                    to: bookDir.appendingPathComponent("cover.jpg"),
                    authToken: api.authToken,
                    fileDescription: "cover"
                )
                
                AppLogger.general.debug("[DownloadManager] Cover downloaded successfully")
                return
                
            } catch {
                lastError = error
                AppLogger.general.debug("[DownloadManager] Cover download attempt \(attempt + 1) failed: \(error)")
                
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: retryDelays[attempt])
                }
            }
        }
        
        throw DownloadError.coverDownloadFailed(underlying: lastError)
    }
    
    private func downloadAudioFilesWithRetry(
        for book: Book,
        api: AudiobookshelfAPI,
        bookDir: URL
    ) async throws {
        guard let firstChapter = book.chapters.first,
              let libraryItemId = firstChapter.libraryItemId else {
            throw DownloadError.missingLibraryItemId
        }
        
        let audioDir = bookDir.appendingPathComponent("audio", isDirectory: true)
        try fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
        
        let session = try await createPlaybackSession(libraryItemId: libraryItemId, api: api)
        let totalTracks = session.audioTracks.count
        
        AppLogger.general.debug("[DownloadManager] Downloading \(totalTracks) audio tracks")
        
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
                currentTrack: index
            )
        }
    }
    
    private func downloadAudioFileWithRetry(
        from url: URL,
        to localURL: URL,
        api: AudiobookshelfAPI,
        bookId: String,
        totalTracks: Int,
        currentTrack: Int
    ) async throws {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                await MainActor.run {
                    let chapterNum = currentTrack + 1
                    let attemptInfo = attempt > 0 ? " (retry \(attempt))" : ""
                    downloadStatus[bookId] = "Downloading chapter \(chapterNum)/\(totalTracks)\(attemptInfo)..."
                }
                
                try await downloadSingleFile(
                    from: url,
                    to: localURL,
                    authToken: api.authToken,
                    fileDescription: "chapter \(currentTrack + 1)"
                )
                
                await MainActor.run {
                    let baseProgress = 0.20
                    let audioProgress = 0.75 * (Double(currentTrack + 1) / Double(totalTracks))
                    downloadProgress[bookId] = baseProgress + audioProgress
                    
                    let chapterNum = currentTrack + 1
                    let percentComplete = Int((Double(chapterNum) / Double(totalTracks)) * 100)
                    downloadStatus[bookId] = "Downloaded chapter \(chapterNum)/\(totalTracks) (\(percentComplete)%)"
                }
                
                AppLogger.general.debug("[DownloadManager] Chapter \(currentTrack + 1)/\(totalTracks) downloaded")
                return
                
            } catch {
                lastError = error
                AppLogger.general.debug("[DownloadManager] Chapter \(currentTrack + 1) attempt \(attempt + 1) failed: \(error)")
                
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: retryDelays[attempt])
                }
            }
        }
        
        throw DownloadError.audioDownloadFailed(chapter: currentTrack + 1, underlying: lastError)
    }
    
    private func downloadSingleFile(
        from url: URL,
        to localURL: URL,
        authToken: String,
        fileDescription: String
    ) async throws {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw DownloadError.httpError(statusCode: httpResponse.statusCode)
        }
        
        guard data.count > 1024 else {
            throw DownloadError.fileTooSmall
        }
        
        try data.write(to: localURL)
    }

    // MARK: - Helper Methods
    
    private func saveBookMetadata(_ book: Book, to directory: URL) async throws {
        let metadataURL = directory.appendingPathComponent("metadata.json")
        let metadataData = try JSONEncoder().encode(book)
        try metadataData.write(to: metadataURL)
        
        AppLogger.general.debug("[DownloadManager] Saved metadata")
    }
    
    private func createPlaybackSession(libraryItemId: String, api: AudiobookshelfAPI) async throws -> PlaybackSessionResponse {
        let url = URL(string: "\(api.baseURLString)/api/items/\(libraryItemId)/play")!
        let requestBody = DeviceUtils.createPlaybackRequest()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(api.authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AudiobookshelfError.invalidResponse
        }
        
        return try JSONDecoder().decode(PlaybackSessionResponse.self, from: data)
    }
    
    private func checkAvailableStorage() -> Bool {
        guard let systemAttributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let freeSpace = systemAttributes[.systemFreeSize] as? Int64 else {
            return false
        }
        
        let requiredSpace: Int64 = 500_000_000
        return freeSpace > requiredSpace
    }
    
    // MARK: - Validation
    
    func validateBookIntegrity(_ bookId: String) -> Bool {
        let bookDir = bookDirectory(for: bookId)
        let metadataFile = bookDir.appendingPathComponent("metadata.json")
        
        guard fileManager.fileExists(atPath: metadataFile.path) else {
            return false
        }
        
        guard let data = try? Data(contentsOf: metadataFile),
              let book = try? JSONDecoder().decode(Book.self, from: data) else {
            return false
        }
        
        // Verify all audio files
        let audioDir = bookDir.appendingPathComponent("audio")
        for (index, _) in book.chapters.enumerated() {
            let audioFile = audioDir.appendingPathComponent("chapter_\(index).mp3")
            if !fileManager.fileExists(atPath: audioFile.path) {
                AppLogger.general.debug("[DownloadManager] Missing chapter \(index)")
                return false
            }
        }
        
        // Verify cover exists
        let coverFile = bookDir.appendingPathComponent("cover.jpg")
        if !fileManager.fileExists(atPath: coverFile.path) {
            AppLogger.general.debug("[DownloadManager] Missing cover")
            return false
        }
        
        return true
    }
    
    // MARK: - Local File Access
    
    func getLocalAudioURL(for bookId: String, chapterIndex: Int) -> URL? {
        let bookDir = bookDirectory(for: bookId)
        let audioDir = bookDir.appendingPathComponent("audio")
        let audioFile = audioDir.appendingPathComponent("chapter_\(chapterIndex).mp3")
        
        guard fileManager.fileExists(atPath: audioFile.path) else {
            return nil
        }
        
        return audioFile
    }
    
    func getLocalCoverURL(for bookId: String) -> URL? {
        let bookDir = bookDirectory(for: bookId)
        let coverFile = bookDir.appendingPathComponent("cover.jpg")
        
        guard fileManager.fileExists(atPath: coverFile.path) else {
            return nil
        }
        
        return coverFile
    }
    
    // MARK: - Delete Operations
    
    func deleteBook(_ bookId: String) {
        let bookDir = bookDirectory(for: bookId)
        forceDeleteBookDirectory(bookDir)
        
        Task { @MainActor in
            downloadedBooks.removeAll { $0.id == bookId }
            downloadProgress.removeValue(forKey: bookId)
            isDownloading.removeValue(forKey: bookId)
        }
        
        AppLogger.general.debug("[DownloadManager] Deleted book: \(bookId)")
    }
    
    func deleteAllBooks() {
        do {
            try fileManager.removeItem(at: downloadsURL)
            createDownloadsDirectory()
            
            Task { @MainActor in
                downloadedBooks.removeAll()
                downloadProgress.removeAll()
                isDownloading.removeAll()
                downloadStatus.removeAll()
                downloadStage.removeAll()
            }
            
            AppLogger.general.debug("[DownloadManager] Deleted all books")
            
        } catch {
            AppLogger.general.debug("[DownloadManager] Failed to delete all books: \(error)")
        }
    }
    
    private func forceDeleteBookDirectory(_ bookDir: URL) {
        do {
            if fileManager.fileExists(atPath: bookDir.path) {
                try fileManager.removeItem(at: bookDir)
                AppLogger.general.debug("[DownloadManager] Deleted directory: \(bookDir.lastPathComponent)")
            }
        } catch {
            AppLogger.general.debug("[DownloadManager] Delete failed, will retry on next launch: \(error)")
        }
    }
    
    // MARK: - Storage Management
    
    func getTotalDownloadSize() -> Int64 {
        guard fileManager.fileExists(atPath: downloadsURL.path) else {
            return 0
        }
        
        guard let enumerator = fileManager.enumerator(
            at: downloadsURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if values.isRegularFile == true, let fileSize = values.fileSize {
                    totalSize += Int64(fileSize)
                }
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    func getBookStorageSize(_ bookId: String) -> Int64 {
        let bookDir = bookDirectory(for: bookId)
        
        guard fileManager.fileExists(atPath: bookDir.path) else {
            return 0
        }
        
        guard let enumerator = fileManager.enumerator(
            at: bookDir,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if values.isRegularFile == true, let fileSize = values.fileSize {
                    totalSize += Int64(fileSize)
                }
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    // MARK: - Persistence & Loading
    
    private func loadDownloadedBooks() {
        guard fileManager.fileExists(atPath: downloadsURL.path) else {
            return
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: downloadsURL,
                includingPropertiesForKeys: nil
            )
            
            var loadedBooks: [Book] = []
            
            for bookDir in contents where bookDir.hasDirectoryPath {
                let metadataFile = bookDir.appendingPathComponent("metadata.json")
                
                if let data = try? Data(contentsOf: metadataFile),
                   let book = try? JSONDecoder().decode(Book.self, from: data) {
                    
                    // Only load books that pass integrity check
                    if validateBookIntegrity(book.id) {
                        loadedBooks.append(book)
                    } else {
                        AppLogger.general.debug("[DownloadManager] Skipping incomplete book: \(book.id)")
                    }
                }
            }
            
            Task { @MainActor in
                downloadedBooks = loadedBooks
            }
            
            AppLogger.general.debug("[DownloadManager] Loaded \(loadedBooks.count) complete books")
            
        } catch {
            AppLogger.general.debug("[DownloadManager] Failed to load books: \(error)")
        }
    }
    
    // MARK: - Cancellation
    
    func cancelDownload(for bookId: String) {
        AppLogger.general.debug("[DownloadManager] Cancelling download: \(bookId)")
        
        downloadTasks[bookId]?.cancel()
        downloadTasks.removeValue(forKey: bookId)
    }
    
    func cancelAllDownloads() {
        AppLogger.general.debug("[DownloadManager] Cancelling all downloads")
        
        downloadTasks.values.forEach { $0.cancel() }
        downloadTasks.removeAll()
        
        Task { @MainActor in
            isDownloading.removeAll()
            downloadProgress.removeAll()
            downloadStatus.removeAll()
            downloadStage.removeAll()
        }
    }
    
    deinit {
        backgroundRepairTask?.cancel()
        downloadTasks.values.forEach { $0.cancel() }
        downloadTasks.removeAll()
    }
}

// MARK: - Download Stage Enum
enum DownloadStage: String, Equatable {
    case preparing = "Preparing..."
    case fetchingMetadata = "Getting book info..."
    case downloadingCover = "Downloading cover..."
    case downloadingAudio = "Downloading audio..."
    case finalizing = "Almost done..."
    case complete = "Complete!"
    case failed = "Failed"
    
    var icon: String {
        switch self {
        case .preparing:
            return "clock.arrow.circlepath"
        case .fetchingMetadata:
            return "doc.text.magnifyingglass"
        case .downloadingCover:
            return "photo.on.rectangle.angled"
        case .downloadingAudio:
            return "waveform.circle"
        case .finalizing:
            return "checkmark.circle"
        case .complete:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .preparing, .fetchingMetadata, .downloadingCover, .downloadingAudio:
            return .accentColor
        case .finalizing:
            return .orange
        case .complete:
            return .green
        case .failed:
            return .red
        }
    }
}

// MARK: - Download Error Types
enum DownloadError: LocalizedError {
    case invalidCoverURL
    case coverDownloadFailed(underlying: Error?)
    case audioDownloadFailed(chapter: Int, underlying: Error?)
    case missingLibraryItemId
    case invalidResponse
    case httpError(statusCode: Int)
    case fileTooSmall
    case verificationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidCoverURL:
            return "Invalid cover URL"
        case .coverDownloadFailed:
            return "Failed to download cover after multiple attempts"
        case .audioDownloadFailed(let chapter, _):
            return "Failed to download chapter \(chapter) after multiple attempts"
        case .missingLibraryItemId:
            return "Book has no library item ID"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode):
            return "Server error (HTTP \(statusCode))"
        case .fileTooSmall:
            return "Downloaded file is too small (corrupted)"
        case .verificationFailed:
            return "Download verification failed - some files are missing"
        }
    }
}

// MARK: - Network Notification Extension
extension Notification.Name {
    static let networkConnectivityChanged = Notification.Name("networkConnectivityChanged")
}
