import Foundation

// MARK: - Protocol

/// Service responsible for file system operations
protocol DownloadStorageService {
    /// Creates a directory for a book
    func createBookDirectory(for bookId: String) throws -> URL
    
    /// Saves book metadata to disk
    func saveBookMetadata(_ book: Book, to directory: URL) throws
    
    /// Saves audio info (technical metadata) to disk
    func saveAudioInfo(_ audioInfo: AudioInfo, to directory: URL) throws
    
    /// Loads audio info from disk
    func loadAudioInfo(for bookId: String) -> AudioInfo?
    
    /// Saves audio file data to disk
    func saveAudioFile(_ data: Data, to url: URL) throws
    
    /// Saves cover image data to disk
    func saveCoverImage(_ data: Data, to url: URL) throws
    
    /// Deletes a book directory
    func deleteBookDirectory(at url: URL) throws
    
    /// Gets the book directory URL for a given book ID
    func bookDirectory(for bookId: String) -> URL
    
    /// Gets the audio directory URL for a given book ID
    func audioDirectory(for bookId: String) -> URL
    
    /// Gets the local audio file URL
    func getLocalAudioURL(for bookId: String, chapterIndex: Int) -> URL?
    
    /// Gets the local cover image URL
    func getLocalCoverURL(for bookId: String) -> URL?
    
    /// Loads all downloaded books from disk
    func loadDownloadedBooks() -> [Book]
    
    /// Checks if sufficient storage space is available
    func checkAvailableStorage(requiredSpace: Int64) -> Bool
    
    /// Gets the total size of all downloads
    func getTotalDownloadSize() -> Int64
    
    /// Gets the storage size of a specific book
    func getBookStorageSize(_ bookId: String) -> Int64
}

// MARK: - Default Implementation

final class DefaultDownloadStorageService: DownloadStorageService {
    
    // MARK: - Properties
    private let fileManager: FileManager
    private let downloadsURL: URL
    
    // MARK: - Initialization
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.downloadsURL = documentsURL.appendingPathComponent("Downloads", isDirectory: true)
        
        createDownloadsDirectoryIfNeeded()
    }
    
    // MARK: - Private Methods
    
    private func createDownloadsDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: downloadsURL.path) {
            do {
                try fileManager.createDirectory(at: downloadsURL, withIntermediateDirectories: true)
                AppLogger.general.debug("[DownloadStorage] Created downloads directory")
            } catch {
                AppLogger.general.error("[DownloadStorage] Failed to create downloads directory: \(error)")
            }
        }
    }
    
    // MARK: - DownloadStorageService
    
    func createBookDirectory(for bookId: String) throws -> URL {
        let bookDir = bookDirectory(for: bookId)
        try fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)
        return bookDir
    }
    
    func saveBookMetadata(_ book: Book, to directory: URL) throws {
        let metadataURL = directory.appendingPathComponent("metadata.json")
        let metadataData = try JSONEncoder().encode(book)
        try metadataData.write(to: metadataURL)
        AppLogger.general.debug("[DownloadStorage] Saved metadata for book: \(book.id)")
    }
    
    func saveAudioInfo(_ audioInfo: AudioInfo, to directory: URL) throws {
        let audioInfoURL = directory.appendingPathComponent("audio_info.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let audioInfoData = try encoder.encode(audioInfo)
        try audioInfoData.write(to: audioInfoURL)
        AppLogger.general.debug("[DownloadStorage] Saved audio info: \(audioInfo.audioTrackCount) tracks")
    }
    
    func loadAudioInfo(for bookId: String) -> AudioInfo? {
        let audioInfoFile = bookDirectory(for: bookId).appendingPathComponent("audio_info.json")
        
        guard let data = try? Data(contentsOf: audioInfoFile) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AudioInfo.self, from: data)
    }
    
    func saveAudioFile(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }
    
    func saveCoverImage(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }
    
    func deleteBookDirectory(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
            AppLogger.general.debug("[DownloadStorage] Deleted directory: \(url.lastPathComponent)")
        }
    }
    
    func bookDirectory(for bookId: String) -> URL {
        downloadsURL.appendingPathComponent(bookId, isDirectory: true)
    }
    
    func audioDirectory(for bookId: String) -> URL {
        bookDirectory(for: bookId).appendingPathComponent("audio", isDirectory: true)
    }
    
    func getLocalAudioURL(for bookId: String, chapterIndex: Int) -> URL? {
        let audioFile = audioDirectory(for: bookId).appendingPathComponent("chapter_\(chapterIndex).mp3")
        guard fileManager.fileExists(atPath: audioFile.path) else { return nil }
        return audioFile
    }
    
    func getLocalCoverURL(for bookId: String) -> URL? {
        let coverFile = bookDirectory(for: bookId).appendingPathComponent("cover.jpg")
        guard fileManager.fileExists(atPath: coverFile.path) else { return nil }
        return coverFile
    }
    
    func loadDownloadedBooks() -> [Book] {
        guard fileManager.fileExists(atPath: downloadsURL.path) else {
            return []
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
            
            AppLogger.general.debug("[DownloadStorage] Loaded \(loadedBooks.count) books from disk")
            return loadedBooks
            
        } catch {
            AppLogger.general.error("[DownloadStorage] Failed to load books: \(error)")
            return []
        }
    }
    
    func checkAvailableStorage(requiredSpace: Int64 = 500_000_000) -> Bool {
        guard let systemAttributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let freeSpace = systemAttributes[.systemFreeSize] as? Int64 else {
            return false
        }
        
        return freeSpace > requiredSpace
    }
    
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
}
