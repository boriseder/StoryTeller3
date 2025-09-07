import Foundation
import AVFoundation

/**
 * DownloadManager handles offline storage of audiobooks
 *
 * Features:
 * - Downloads complete audiobooks with metadata and cover images
 * - Tracks download progress and status
 * - Provides local file access for offline playback
 * - Manages storage cleanup and organization
 */
@MainActor
class DownloadManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var downloadedBooks: [Book] = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var isDownloading: [String: Bool] = [:]
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    
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
    
    /// Creates the downloads directory if it doesn't exist
    private func createDownloadsDirectory() {
        if !fileManager.fileExists(atPath: downloadsURL.path) {
            do {
                try fileManager.createDirectory(at: downloadsURL, withIntermediateDirectories: true)
                print("Created downloads directory")
            } catch {
                print("Failed to create downloads directory: \(error)")
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
    func downloadBook(_ book: Book, api: AudiobookshelfAPI) async {
        // Prevent duplicate downloads
        guard !isBookDownloaded(book.id), !isDownloadingBook(book.id) else {
            print("⚠️ Book \(book.title) is already downloaded or downloading")
            return
        }
        
        print("📥 Starting download for: \(book.title)")
        
        // Initialize download state
        isDownloading[book.id] = true
        downloadProgress[book.id] = 0.0
        
        let bookDir = bookDirectory(for: book.id)
        
        do {
            // Create book directory
            try fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)
            
            // Download detailed book information
            let fullBook = try await api.fetchBookDetails(bookId: book.id)
            
            // Save book metadata
            try await saveBookMetadata(fullBook, to: bookDir)
            
            // Download cover image if available
            if let coverPath = fullBook.coverPath {
                await downloadCover(
                    bookId: book.id,
                    coverPath: coverPath,
                    api: api,
                    bookDir: bookDir
                )
            }
            
            // Download audio files
            await downloadAudioFiles(for: fullBook, api: api, bookDir: bookDir)
            
            // Update completion state
            await MainActor.run {
                downloadedBooks.append(fullBook)
                isDownloading[book.id] = false
                downloadProgress[book.id] = 1.0
                
                print("Successfully downloaded: \(fullBook.title)")
            }
            
        } catch {
            // Handle download failure
            await MainActor.run {
                isDownloading[book.id] = false
                downloadProgress[book.id] = 0.0
                
                print("Download failed for \(book.title): \(error)")
            }
            
            // Clean up partial download
            try? fileManager.removeItem(at: bookDir)
        }
    }
    
    /**
     * Saves book metadata to local storage
     */
    private func saveBookMetadata(_ book: Book, to directory: URL) async throws {
        let metadataURL = directory.appendingPathComponent("metadata.json")
        let metadataData = try JSONEncoder().encode(book)
        try metadataData.write(to: metadataURL)
        
        print("💾 Saved metadata for: \(book.title)")
    }
    
    /**
     * Downloads and saves book cover image
     */
    private func downloadCover(bookId: String, coverPath: String, api: AudiobookshelfAPI, bookDir: URL) async {
        guard let coverURL = URL(string: "\(api.baseURLString)\(coverPath)") else {
            print("⚠️ Invalid cover URL for book \(bookId)")
            return
        }
        
        var request = URLRequest(url: coverURL)
        request.setValue("Bearer \(api.authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("⚠️ Cover download failed - HTTP status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }
            
            let coverFile = bookDir.appendingPathComponent("cover.jpg")
            try data.write(to: coverFile)
            
            print("🖼️ Downloaded cover for book \(bookId)")
            
        } catch {
            print("❌ Cover download error: \(error)")
        }
    }
    
    /**
     * Downloads all audio files for a book
     */
    private func downloadAudioFiles(for book: Book, api: AudiobookshelfAPI, bookDir: URL) async {
        // Get the first chapter to determine library item ID
        guard let firstChapter = book.chapters.first,
              let libraryItemId = firstChapter.libraryItemId else {
            print("⚠️ No chapters or library item ID found")
            return
        }
        
        do {
            // Create playback session to get download URLs
            let session = try await createPlaybackSession(libraryItemId: libraryItemId, api: api)
            let totalTracks = session.audioTracks.count
            
            print("🎵 Downloading \(totalTracks) audio tracks")
            
            // Download each audio track
            for (index, audioTrack) in session.audioTracks.enumerated() {
                let audioURL = URL(string: "\(api.baseURLString)\(audioTrack.contentUrl)")!
                let fileName = "chapter_\(index).mp3"
                let localURL = bookDir.appendingPathComponent(fileName)
                
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
            print("❌ Audio download failed: \(error)")
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
        request.timeoutInterval = 300.0 // 5 minutes for audio files
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("⚠️ Audio file download failed - HTTP status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }
            
            try data.write(to: localURL)
            
            // Update progress on main thread
            await MainActor.run {
                let progress = Double(currentTrack + 1) / Double(totalTracks)
                downloadProgress[bookId] = progress
                
                print("🎵 Downloaded audio file \(currentTrack + 1)/\(totalTracks)")
            }
            
        } catch {
            print("❌ Audio file download error: \(error)")
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
        let audioFile = bookDir.appendingPathComponent("chapter_\(chapterIndex).mp3")
        
        guard fileManager.fileExists(atPath: audioFile.path) else {
            print("⚠️ Audio file not found: \(audioFile.path)")
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
            
            // Update state
            downloadedBooks.removeAll { $0.id == bookId }
            downloadProgress.removeValue(forKey: bookId)
            isDownloading.removeValue(forKey: bookId)
            
            print("🗑️ Deleted downloaded book: \(bookId)")
            
        } catch {
            print("❌ Failed to delete book \(bookId): \(error)")
        }
    }
    
    /**
     * Deletes all downloaded books and clears storage
     */
    func deleteAllBooks() {
        do {
            try fileManager.removeItem(at: downloadsURL)
            createDownloadsDirectory()
            
            // Clear all state
            downloadedBooks.removeAll()
            downloadProgress.removeAll()
            isDownloading.removeAll()
            
            print("🗑️ Deleted all downloaded books")
            
        } catch {
            print("❌ Failed to delete all books: \(error)")
        }
    }
    
    // MARK: - Storage Management
    
    /**
     * Calculates total storage used by downloads
     *
     * - Returns: Total size in bytes
     */
    func getTotalDownloadSize() -> Int64 {
        do {
            let resourceValues = try downloadsURL.resourceValues(forKeys: [.totalFileSizeKey])
            return Int64(resourceValues.totalFileSize ?? 0)
        } catch {
            return 0
        }
    }
    
    /**
     * Gets storage information for a specific book
     *
     * - Parameter bookId: The book identifier
     * - Returns: Size in bytes, or 0 if book not found
     */
    func getBookStorageSize(_ bookId: String) -> Int64 {
        let bookDir = bookDirectory(for: bookId)
        
        do {
            let resourceValues = try bookDir.resourceValues(forKeys: [.totalFileSizeKey])
            return Int64(resourceValues.totalFileSize ?? 0)
        } catch {
            return 0
        }
    }
    
    // MARK: - Persistence & Loading
    
    /**
     * Loads previously downloaded books from local storage
     */
    private func loadDownloadedBooks() {
        guard fileManager.fileExists(atPath: downloadsURL.path) else {
            print("📂 No downloads directory found")
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
                    print("📚 Loaded downloaded book: \(book.title)")
                }
            }
            
            downloadedBooks = loadedBooks
            print("Loaded \(loadedBooks.count) downloaded books")
            
        } catch {
            print("Failed to load downloaded books: \(error)")
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
                print("⚠️ Missing audio file for chapter \(index) in book \(bookId)")
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
                    print("🧹 Cleaned up incomplete download: \(bookId)")
                    continue
                }
                
                // Check integrity
                if !validateBookIntegrity(bookId) {
                    try fileManager.removeItem(at: bookDir)
                    downloadedBooks.removeAll { $0.id == bookId }
                    print("🧹 Cleaned up corrupted download: \(bookId)")
                }
            }
        } catch {
            print("❌ Cleanup failed: \(error)")
        }
    }
}
