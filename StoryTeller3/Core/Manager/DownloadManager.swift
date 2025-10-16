import Foundation
import AVFoundation
import SwiftUI

enum OfflineStatus {
    case notDownloaded
    case incomplete
    case available
}

class DownloadManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var downloadedBooks: [Book] = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var isDownloading: [String: Bool] = [:]
    
    @Published var downloadStatus: [String: String] = [:]  // bookId → status message
    @Published var downloadStage: [String: DownloadStage] = [:] // bookId → current stage

    // MARK: - Private Properties
    private let fileManager = FileManager.default

    // Track download tasks for cancellation
    private var downloadTasks: [String: Task<Void, Never>] = [:]

    // MARK: - Directory URLs
    
    /// Main documents directory
    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Downloads root directory
    private var downloadsURL: URL {
        documentsURL.appendingPathComponent("Downloads", isDirectory: true)
    }
    
    // MARK: - Initialization
    
    init() {
        createDownloadsDirectory()
        loadDownloadedBooks()
    }
    
    // MARK: - Directory Management
    
    func getOfflineStatus(for bookId: String) -> OfflineStatus {
        if !isBookDownloaded(bookId) {
            return .notDownloaded
        }
        
        if !validateBookIntegrity(bookId) {
            return .incomplete
        }
        
        return .available
    }

    func isBookAvailableOffline(_ bookId: String) -> Bool {
        return getOfflineStatus(for: bookId) == .available
    }

    /// Creates the downloads directory if it doesn't exist
    private func createDownloadsDirectory() {
        if !fileManager.fileExists(atPath: downloadsURL.path) {
            do {
                try fileManager.createDirectory(at: downloadsURL, withIntermediateDirectories: true)
                AppLogger.general.debug("Created downloads directory")
            } catch {
                AppLogger.general.debug("Failed to create downloads directory: \(error)")
            }
        }
    }
    
    /// Returns the directory path for a specific book
    func bookDirectory(for bookId: String) -> URL {
        downloadsURL.appendingPathComponent(bookId, isDirectory: true)
    }
    
    // MARK: - Download Operations
    
    /**
     * Downloads a complete audiobook including metadata, cover, and audio files
     *
     * - Parameter book: The book to download
     * - Parameter api: API client for server communication
     */
    // MARK: - Download Book with Detailed Progress Tracking

    func downloadBook(_ book: Book, api: AudiobookshelfAPI) async {
        // Check available storage before starting
        guard checkAvailableStorage() else {
            await MainActor.run {
                AppLogger.general.debug("❌ Insufficient storage space for download")
                
                // Show error to user (you'll need to add @Published var for this)
                downloadStage[book.id] = .failed
                downloadStatus[book.id] = "Insufficient storage space. Please free up at least 500MB."
            }
            return
        }
        
        // Check memory before large download
        let availableMemory = ProcessInfo.processInfo.physicalMemory
        
        if availableMemory < 100_000_000 { // Less than 100MB
            AppLogger.general.debug("⚠️ Low memory detected - triggering cleanup")
            await MainActor.run {
                CoverCacheManager.shared.triggerCriticalCleanup()
            }
        }
        
        // Prevent duplicate downloads
        let isAlreadyDownloaded = await MainActor.run {
            isBookDownloaded(book.id) || isDownloadingBook(book.id)
        }
        
        guard !isAlreadyDownloaded else {
            AppLogger.general.debug("⚠️ Book \(book.title) is already downloaded or downloading")
            return
        }
        
        AppLogger.general.debug("📥 Starting download for: \(book.title)")
        
        // Create the download task (for cancellation support)
        let downloadTask = Task { @MainActor in
            await performDownload(book: book, api: api)
        }
        
        // Store task for cancellation
        await MainActor.run {
            downloadTasks[book.id] = downloadTask
        }
        
        // Wait for completion
        await downloadTask.value
        
        // Clean up task reference
        await MainActor.run {
            downloadTasks.removeValue(forKey: book.id)
        }
    }

    // MARK: - Perform Download (Separated for Better Task Management)

    private func performDownload(book: Book, api: AudiobookshelfAPI) async {
        // Stage 1: Initialize download state
        await MainActor.run {
            isDownloading[book.id] = true
            downloadProgress[book.id] = 0.0
            downloadStage[book.id] = .preparing
            downloadStatus[book.id] = "Preparing to download..."
        }
        
        let bookDir = bookDirectory(for: book.id)
        
        do {
            // Check if task was cancelled
            try Task.checkCancellation()
            
            // Stage 2: Create book directory
            await MainActor.run {
                downloadStage[book.id] = .preparing
                downloadStatus[book.id] = "Creating download folder..."
            }
            
            try fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)
            
            await MainActor.run {
                downloadProgress[book.id] = 0.05
            }
            
            // Small delay for visual feedback
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Check cancellation again
            try Task.checkCancellation()
            
            // Stage 3: Fetch detailed book information
            await MainActor.run {
                downloadStage[book.id] = .fetchingMetadata
                downloadStatus[book.id] = "Fetching book details from server..."
            }
            
            let fullBook = try await api.fetchBookDetails(bookId: book.id)
            
            await MainActor.run {
                downloadProgress[book.id] = 0.10
            }
            
            AppLogger.general.debug("Fetched book details: \(fullBook.chapters.count) chapters")
            
            try Task.checkCancellation()
            
            // Stage 4: Save book metadata
            await MainActor.run {
                downloadStatus[book.id] = "Saving book information..."
            }
            
            try await saveBookMetadata(fullBook, to: bookDir)
            
            await MainActor.run {
                downloadProgress[book.id] = 0.15
            }
            
            try Task.checkCancellation()
            
            // Stage 5: Download cover image
            if let coverPath = fullBook.coverPath {
                await MainActor.run {
                    downloadStage[book.id] = .downloadingCover
                    downloadStatus[book.id] = "Downloading cover image..."
                }
                
                await downloadCover(
                    bookId: book.id,
                    coverPath: coverPath,
                    api: api,
                    bookDir: bookDir
                )
                
                await MainActor.run {
                    downloadProgress[book.id] = 0.20
                }
                
                AppLogger.general.debug("[DownloadManager] Cover downloaded")
            }
            
            try Task.checkCancellation()
            
            // Stage 6: Download audio files (bulk of download time)
            await MainActor.run {
                downloadStage[book.id] = .downloadingAudio
                downloadStatus[book.id] = "Starting audio download..."
            }
            
            // Small delay for visual feedback
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            await downloadAudioFiles(for: fullBook, api: api, bookDir: bookDir)
            
            try Task.checkCancellation()
            
            // Stage 7: Finalizing
            await MainActor.run {
                downloadStage[book.id] = .finalizing
                downloadStatus[book.id] = "Verifying download..."
                downloadProgress[book.id] = 0.95
            }
            
            // Verify download integrity
            let isComplete = verifyDownloadIntegrity(bookId: fullBook.id, expectedChapters: fullBook.chapters.count)
            
            guard isComplete else {
                throw DownloadError.incompleteDownload
            }
            
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            try Task.checkCancellation()
            
            // Stage 8: Complete
            await MainActor.run {
                downloadedBooks.append(fullBook)
                isDownloading[book.id] = false
                downloadProgress[book.id] = 1.0
                downloadStage[book.id] = .complete
                downloadStatus[book.id] = "Download complete!"
                
                AppLogger.general.debug("[DownloadManager] Successfully downloaded: \(fullBook.title)")
            }
            
            // Clear status after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                downloadStatus.removeValue(forKey: book.id)
                downloadStage.removeValue(forKey: book.id)
            }
            
        } catch is CancellationError {
            // Handle cancellation gracefully
            AppLogger.general.debug("[DownloadManager] Download cancelled for: \(book.title)")
            
            await MainActor.run {
                isDownloading[book.id] = false
                downloadProgress[book.id] = 0.0
                downloadStage[book.id] = .failed
                downloadStatus[book.id] = "Download cancelled"
            }
            
            // Clean up partial download
            cleanupPartialDownload(bookDir: bookDir, bookId: book.id)
            
            // Clear status after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                downloadStatus.removeValue(forKey: book.id)
                downloadStage.removeValue(forKey: book.id)
            }
            
        } catch let error as DownloadError {
            // Handle custom download errors
            AppLogger.general.debug("[DownloadManager] Download error for \(book.title): \(error.localizedDescription)")
            
            await MainActor.run {
                isDownloading[book.id] = false
                downloadProgress[book.id] = 0.0
                downloadStage[book.id] = .failed
                downloadStatus[book.id] = error.localizedDescription
            }
            
            cleanupPartialDownload(bookDir: bookDir, bookId: book.id)
            
        } catch {
            // Handle all other errors
            AppLogger.general.debug("[DownloadManager] Download failed for \(book.title): \(error.localizedDescription)")
            
            await MainActor.run {
                isDownloading[book.id] = false
                downloadProgress[book.id] = 0.0
                downloadStage[book.id] = .failed
                
                // User-friendly error message
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        downloadStatus[book.id] = "Download timed out. Check your connection."
                    case .notConnectedToInternet:
                        downloadStatus[book.id] = "No internet connection"
                    case .networkConnectionLost:
                        downloadStatus[book.id] = "Connection lost during download"
                    default:
                        downloadStatus[book.id] = "Network error: \(urlError.localizedDescription)"
                    }
                } else {
                    downloadStatus[book.id] = "Download failed: \(error.localizedDescription)"
                }
            }
            
            cleanupPartialDownload(bookDir: bookDir, bookId: book.id)
        }
    }

    // MARK: - Storage Check

    private func checkAvailableStorage() -> Bool {
        let fileManager = FileManager.default
        guard let systemAttributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let freeSpace = systemAttributes[.systemFreeSize] as? Int64 else {
            return false
        }
        
        let requiredSpace: Int64 = 500_000_000 // 500MB minimum
        let hasSpace = freeSpace > requiredSpace
        
        if !hasSpace {
            AppLogger.general.debug("[DownloadManager] Insufficient storage - Available: \(freeSpace / 1_000_000)MB, Required: \(requiredSpace / 1_000_000)MB")
        }
        
        return hasSpace
    }

    // MARK: - Download Integrity Verification

    private func verifyDownloadIntegrity(bookId: String, expectedChapters: Int) -> Bool {
        let bookDir = bookDirectory(for: bookId)
        let audioDir = bookDir.appendingPathComponent("audio")
        
        // Check if audio directory exists
        guard fileManager.fileExists(atPath: audioDir.path) else {
            AppLogger.general.debug("[DownloadManager] Audio directory not found")
            return false
        }
        
        // Count audio files
        guard let audioFiles = try? fileManager.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil) else {
            AppLogger.general.debug("[DownloadManager] Cannot read audio directory")
            return false
        }
        
        let m4aFiles = audioFiles.filter { $0.pathExtension == "m4a" || $0.pathExtension == "mp3" }
        
        let isComplete = m4aFiles.count == expectedChapters
        
        if !isComplete {
            AppLogger.general.debug("[DownloadManageIncomplete download - Expected: \(expectedChapters), Found: \(m4aFiles.count)")
        }
        
        return isComplete
    }

    // MARK: - Cleanup Partial Download

    private func cleanupPartialDownload(bookDir: URL, bookId: String) {
        do {
            if fileManager.fileExists(atPath: bookDir.path) {
                try fileManager.removeItem(at: bookDir)
                AppLogger.general.debug("[DownloadManager] Cleaned up partial download for: \(bookId)")
            }
        } catch {
            AppLogger.general.debug("[DownloadManager] Failed to clean up partial download: \(error)")
            
            // Mark as corrupt for later cleanup
            var corruptDownloads = UserDefaults.standard.stringArray(forKey: "corrupt_downloads") ?? []
            if !corruptDownloads.contains(bookId) {
                corruptDownloads.append(bookId)
                UserDefaults.standard.set(corruptDownloads, forKey: "corrupt_downloads")
            }
        }
    }

    // MARK: - Download Error Types

    enum DownloadError: LocalizedError {
        case insufficientStorage
        case incompleteDownload
        case metadataSaveFailed
        case audioDownloadFailed(chapter: Int)
        
        var errorDescription: String? {
            switch self {
            case .insufficientStorage:
                return "Not enough storage space. Please free up at least 500MB."
            case .incompleteDownload:
                return "Download incomplete. Some files are missing."
            case .metadataSaveFailed:
                return "Failed to save book information."
            case .audioDownloadFailed(let chapter):
                return "Failed to download chapter \(chapter)."
            }
        }
    }

    // MARK: - Cancel Download

    func cancelDownload(for bookId: String) {
        AppLogger.general.debug("[DownloadManager] Cancelling download for: \(bookId)")
        
        // Cancel the task
        downloadTasks[bookId]?.cancel()
        downloadTasks.removeValue(forKey: bookId)
        
        // State will be cleaned up by the cancellation handler in performDownload
    }

    // MARK: - Cancel All Downloads

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
    

    /**
     * Saves book metadata to local storage
     */
    private func saveBookMetadata(_ book: Book, to directory: URL) async throws {
        let metadataURL = directory.appendingPathComponent("metadata.json")
        let metadataData = try JSONEncoder().encode(book)
        try metadataData.write(to: metadataURL)
        
        AppLogger.general.debug("[DownloadManager] Saved metadata for: \(book.title)")
    }
    
    /**
     * Downloads and saves book cover image
     */
    private func downloadCover(bookId: String, coverPath: String, api: AudiobookshelfAPI, bookDir: URL) async {
        guard let coverURL = URL(string: "\(api.baseURLString)\(coverPath)") else {
            AppLogger.general.debug("[DownloadManager] Invalid cover URL for book \(bookId)")
            return
        }
        
        var request = URLRequest(url: coverURL)
        request.setValue("Bearer \(api.authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                AppLogger.general.debug("[DownloadManager] Cover download failed - HTTP status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }
            
            let coverFile = bookDir.appendingPathComponent("cover.jpg")
            try data.write(to: coverFile)
            
            AppLogger.general.debug("[DownloadManager] Downloaded cover for book \(bookId)")
            
        } catch {
            AppLogger.general.debug("[DownloadManager] Cover download error: \(error)")
        }
    }
    
    /**
     * Downloads all audio files for a book
     */
    private func downloadAudioFiles(for book: Book, api: AudiobookshelfAPI, bookDir: URL) async {
        // Get the first chapter to determine library item ID
        guard let firstChapter = book.chapters.first,
              let libraryItemId = firstChapter.libraryItemId else {
            AppLogger.general.debug("[DownloadManager] No chapters or library item ID found")
            return
        }
        
        do {
            // Create audio subdirectory
            let audioDir = bookDir.appendingPathComponent("audio", isDirectory: true)
            try fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
            
            // Create playback session to get download URLs
            let session = try await createPlaybackSession(libraryItemId: libraryItemId, api: api)
            let totalTracks = session.audioTracks.count
            
            AppLogger.general.debug("[DownloadManager] Downloading \(totalTracks) audio tracks")
            
            // Download each audio track
            for (index, audioTrack) in session.audioTracks.enumerated() {
                let audioURL = URL(string: "\(api.baseURLString)\(audioTrack.contentUrl)")!
                let fileName = "chapter_\(index).mp3"
                let localURL = audioDir.appendingPathComponent(fileName)
                
                await downloadAudioFile(
                    from: audioURL,
                    to: localURL,
                    api: api,
                    bookId: book.id,
                    totalTracks: totalTracks,
                    currentTrack: index
                )
            }
            
        } catch {
            AppLogger.general.debug("[DownloadManager] Audio download failed: \(error)")
        }
    }
    
    /**
     * Downloads a single audio file and updates progress
     */
    private func downloadAudioFile(
        from url: URL,
        to localURL: URL,
        api: AudiobookshelfAPI,
        bookId: String,
        totalTracks: Int,
        currentTrack: Int
    ) async {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(api.authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300.0
        
        do {
            // Update status with current chapter
            await MainActor.run {
                let chapterNum = currentTrack + 1
                downloadStatus[bookId] = "Downloading chapter \(chapterNum) of \(totalTracks)..."
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                AppLogger.general.debug("[DownloadManager] Audio file download failed - HTTP status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }
            
            try data.write(to: localURL)
            
            // Update progress on main thread
            await MainActor.run {
                // Progress from 0.20 to 0.95 (75% of total)
                let baseProgress = 0.20
                let audioProgress = 0.75 * (Double(currentTrack + 1) / Double(totalTracks))
                downloadProgress[bookId] = baseProgress + audioProgress
                
                let chapterNum = currentTrack + 1
                let percentComplete = Int((Double(chapterNum) / Double(totalTracks)) * 100)
                downloadStatus[bookId] = "Downloaded chapter \(chapterNum)/\(totalTracks) (\(percentComplete)%)"
                
                AppLogger.general.debug("[DownloadManager] Downloaded audio file \(chapterNum)/\(totalTracks)")
            }
            
        } catch {
            AppLogger.general.debug("[DownloadManager] Audio file download error: \(error)")
            
            await MainActor.run {
                downloadStatus[bookId] = "Error downloading chapter \(currentTrack + 1): \(error.localizedDescription)"
            }
        }
    }

    /**
     * Creates a playback session to get audio file URLs
     */
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
    
    // MARK: - Query Methods
    
    /// Checks if a book is downloaded locally
    func isBookDownloaded(_ bookId: String) -> Bool {
        let bookDir = bookDirectory(for: bookId)
        let metadataFile = bookDir.appendingPathComponent("metadata.json")
        return fileManager.fileExists(atPath: metadataFile.path)
    }
    
    /// Gets current download progress for a book (0.0 to 1.0)
    func getDownloadProgress(for bookId: String) -> Double {
        downloadProgress[bookId] ?? 0.0
    }
    
    /// Checks if a book is currently being downloaded
    func isDownloadingBook(_ bookId: String) -> Bool {
        isDownloading[bookId] ?? false
    }
    
    // MARK: - Local File Access
    
    /**
     * Returns local URL for audio file of specific chapter
     *
     * - Parameter bookId: The book identifier
     * - Parameter chapterIndex: Zero-based chapter index
     * - Returns: Local file URL if exists, nil otherwise
     */
    func getLocalAudioURL(for bookId: String, chapterIndex: Int) -> URL? {
        let bookDir = bookDirectory(for: bookId)
        let audioDir = bookDir.appendingPathComponent("audio")
        let audioFile = audioDir.appendingPathComponent("chapter_\(chapterIndex).mp3")
        
        guard fileManager.fileExists(atPath: audioFile.path) else {
            AppLogger.general.debug("[DownloadManager] Audio file not found: \(audioFile.path)")
            return nil
        }
        
        return audioFile
    }
    
    /**
     * Returns local URL for book cover image
     *
     * - Parameter bookId: The book identifier
     * - Returns: Local cover URL if exists, nil otherwise
     */
    func getLocalCoverURL(for bookId: String) -> URL? {
        let bookDir = bookDirectory(for: bookId)
        let coverFile = bookDir.appendingPathComponent("cover.jpg")
        
        guard fileManager.fileExists(atPath: coverFile.path) else {
            return nil
        }
        
        return coverFile
    }
    
    // MARK: - Delete Operations
    
    /**
     * Deletes a downloaded book and all its associated files
     *
     * - Parameter bookId: The book identifier to delete
     */
    func deleteBook(_ bookId: String) {
        let bookDir = bookDirectory(for: bookId)
        
        do {
            try fileManager.removeItem(at: bookDir)
            
            // Update state on main actor
            Task { @MainActor in
                downloadedBooks.removeAll { $0.id == bookId }
                downloadProgress.removeValue(forKey: bookId)
                isDownloading.removeValue(forKey: bookId)
            }
            
            AppLogger.general.debug("[DownloadManager] Deleted downloaded book: \(bookId)")
            
        } catch {
            AppLogger.general.debug("[DownloadManager] Failed to delete book \(bookId): \(error)")
        }
    }
    
    /**
     * Deletes all downloaded books and clears storage
     */
    func deleteAllBooks() {
        do {
            try fileManager.removeItem(at: downloadsURL)
            createDownloadsDirectory()
            
            // Clear all state on main actor
            Task { @MainActor in
                downloadedBooks.removeAll()
                downloadProgress.removeAll()
                isDownloading.removeAll()
            }
            
            AppLogger.general.debug("[DownloadManager] Deleted all downloaded books")
            
        } catch {
            AppLogger.general.debug("[DownloadManager] Failed to delete all books: \(error)")
        }
    }
    
    // MARK: - Storage Management
    
    /**
     * Calculates total storage used by downloads
     *
     * - Returns: Total size in bytes
     */
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
                // Skip files that can't be read
            }
        }
        
        return totalSize
    }
    
    /**
     * Gets storage information for a specific book
     *
     * - Parameter bookId: The book identifier
     * - Returns: Size in bytes, or 0 if book not found
     */
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
                // Skip files that can't be read
            }
        }
        
        return totalSize
    }
    
    // MARK: - Persistence & Loading
    
    /**
     * Loads previously downloaded books from local storage
     */
    private func loadDownloadedBooks() {
        guard fileManager.fileExists(atPath: downloadsURL.path) else {
            AppLogger.general.debug("[DownloadManager] No downloads directory found")
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
                    loadedBooks.append(book)
                }
            }
            
            // Update published property on main actor
            Task { @MainActor in
                downloadedBooks = loadedBooks
            }
            
        } catch {
            AppLogger.general.debug("[DownloadManager] Failed to load downloaded books: \(error)")
        }
    }
    
    /**
     * Validates downloaded book integrity
     *
     * - Parameter bookId: The book to validate
     * - Returns: True if book files are intact
     */
    func validateBookIntegrity(_ bookId: String) -> Bool {
        let bookDir = bookDirectory(for: bookId)
        let metadataFile = bookDir.appendingPathComponent("metadata.json")
        
        // Check if metadata exists
        guard fileManager.fileExists(atPath: metadataFile.path) else {
            return false
        }
        
        // Load book metadata to check chapter count
        guard let data = try? Data(contentsOf: metadataFile),
              let book = try? JSONDecoder().decode(Book.self, from: data) else {
            return false
        }
        
        // Verify audio files exist for each chapter
        for (index, _) in book.chapters.enumerated() {
            let audioFile = bookDir.appendingPathComponent("chapter_\(index).mp3")
            if !fileManager.fileExists(atPath: audioFile.path) {
                AppLogger.general.debug("[DownloadManager] Missing audio file for chapter \(index) in book \(bookId)")
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Cleanup Operations
    
    /**
     * Removes incomplete or corrupted downloads
     */
    func cleanupIncompleteDownloads() {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: downloadsURL,
                includingPropertiesForKeys: nil
            )
            
            for bookDir in contents where bookDir.hasDirectoryPath {
                let bookId = bookDir.lastPathComponent
                
                // Check if download is incomplete (no metadata file)
                let metadataFile = bookDir.appendingPathComponent("metadata.json")
                if !fileManager.fileExists(atPath: metadataFile.path) {
                    try fileManager.removeItem(at: bookDir)
                    AppLogger.general.debug("[DownloadManager] Cleaned up incomplete download: \(bookId)")
                    continue
                }
                
                // Check integrity
                if !validateBookIntegrity(bookId) {
                    try fileManager.removeItem(at: bookDir)
                    
                    // Update state on main actor
                    Task { @MainActor in
                        downloadedBooks.removeAll { $0.id == bookId }
                    }
                    AppLogger.general.debug("[DownloadManager] Cleaned up corrupted download: \(bookId)")
                }
            }
        } catch {
            AppLogger.general.debug("[DownloadManager] Cleanup failed: \(error)")
        }
    }
    
    // Synchronous deinit
    deinit {
        downloadTasks.values.forEach { $0.cancel() }
        downloadTasks.removeAll()
    }
}

// MARK: - Download Stage Enum
enum DownloadStage: String, Equatable {
    case preparing = "[DownloadManager] Preparing..."
    case fetchingMetadata = "[DownloadManager] Getting book info..."
    case downloadingCover = "[DownloadManager] Downloading cover..."
    case downloadingAudio = "[DownloadManager] Downloading audio..."
    case finalizing = "[DownloadManager] Almost done..."
    case complete = "[DownloadManager] Complete!"
    case failed = "[DownloadManager] Failed"
    
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

    var description: String {
        return self.rawValue
    }
}
