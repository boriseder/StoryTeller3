import SwiftUI
import AVFoundation

// MARK: - Cover Cache Manager
@MainActor
class CoverCacheManager: ObservableObject {
    static let shared = CoverCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Setup memory cache
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Setup disk cache directory
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesURL.appendingPathComponent("BookCovers", isDirectory: true)
        
        createCacheDirectory()
        
        // ✅ SWIFT 6 FIX - Setup memory warning handling
        setupMemoryWarningHandling()
    }
    
    // ✅ SWIFT 6 FIX - Memory Warning Setup ohne Sendable closure
    private func setupMemoryWarningHandling() {
        // Clear cache on memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Clear memory cache when app goes to background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    // ✅ SWIFT 6 FIX - Objective-C selectors für NotificationCenter
    @objc private func handleMemoryWarning() {
        print("[CoverCache] Memory warning - clearing memory cache")
        cache.removeAllObjects()
    }
    
    @objc private func handleAppBackground() {
        print("[CoverCache] App backgrounded - clearing memory cache")
        cache.removeAllObjects()
    }
    
    // ✅ NEW: Cleanup Observer
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func createCacheDirectory() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Memory Cache
    func getCachedImage(for key: String) -> UIImage? {
        return cache.object(forKey: NSString(string: key))
    }
    
    func setCachedImage(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Rough memory estimate
        cache.setObject(image, forKey: NSString(string: key), cost: cost)
    }
    
    // MARK: - Disk Cache
    private func diskCacheURL(for key: String) -> URL {
        let filename = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return cacheDirectory.appendingPathComponent("\(filename).jpg")
    }
    
    func getDiskCachedImage(for key: String) -> UIImage? {
        let url = diskCacheURL(for: key)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        
        // Also store in memory cache
        setCachedImage(image, for: key)
        return image
    }
    
    func setDiskCachedImage(_ image: UIImage, for key: String) {
        let url = diskCacheURL(for: key)
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        try? data.write(to: url)
        setCachedImage(image, for: key)
    }
    
    // MARK: - Cache Management
    func clearMemoryCache() {
        cache.removeAllObjects()
    }
    
    func clearDiskCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        createCacheDirectory()
    }
    
    func clearAllCache() {
        clearMemoryCache()
        clearDiskCache()
    }
    
    func getCacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
               resourceValues.isRegularFile == true,
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        return totalSize
    }
    
    // MARK: - Dynamic Cache Configuration
    func updateCacheLimits() {
        let countLimit = UserDefaults.standard.integer(forKey: "cover_cache_limit")
        let sizeLimit = UserDefaults.standard.integer(forKey: "memory_cache_size")
        
        cache.countLimit = countLimit > 0 ? countLimit : 100
        cache.totalCostLimit = (sizeLimit > 0 ? sizeLimit : 50) * 1024 * 1024 // MB to bytes
        
        print("[CoverCache] Updated limits: \(cache.countLimit) covers, \(cache.totalCostLimit / 1024 / 1024) MB")
    }
    
    // MARK: - Cache Optimization
    func optimizeCache() async {
        // Remove corrupted files
        let corruptedFiles = findCorruptedCacheFiles()
        for file in corruptedFiles {
            try? fileManager.removeItem(at: file)
        }
        
        // Clean up old files if cache is too large
        if getCacheSize() > 200 * 1024 * 1024 { // 200MB threshold
            clearOldestDiskCacheItems(keepCount: 100)
        }
        
        print("[CoverCache] Cache optimization completed")
    }
    
    private func findCorruptedCacheFiles() -> [URL] {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        var corruptedFiles: [URL] = []
        
        for case let fileURL as URL in enumerator {
            // Try to load image to check if it's corrupted
            if let data = try? Data(contentsOf: fileURL),
               UIImage(data: data) == nil {
                corruptedFiles.append(fileURL)
            }
        }
        
        return corruptedFiles
    }
    
    private func clearOldestDiskCacheItems(keepCount: Int = 50) {
        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
        ) else { return }
        
        var files: [(URL, Date)] = []
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
                if resourceValues.isRegularFile == true,
                   let modificationDate = resourceValues.contentModificationDate {
                    files.append((fileURL, modificationDate))
                }
            } catch {
                print("[CoverCache] Error reading file attributes: \(error)")
            }
        }
        
        // Sort by modification date (oldest first)
        files.sort { $0.1 < $1.1 }
        
        // Remove oldest files if we exceed keepCount
        let filesToRemove = files.dropLast(keepCount)
        for (fileURL, _) in filesToRemove {
            try? fileManager.removeItem(at: fileURL)
        }
        
        if !filesToRemove.isEmpty {
            print("[CoverCache] Removed \(filesToRemove.count) old cache files")
        }
    }
    
    // MARK: - Preloading
    func preloadCovers(for books: [Book], api: AudiobookshelfAPI?, downloadManager: DownloadManager?) {
        Task { @MainActor in
            for book in books.prefix(10) { // Limit preloading
                let loader = BookCoverLoader(book: book, api: api, downloadManager: downloadManager)
                loader.preloadCover()
            }
        }
    }
}

// MARK: - Cover Download Manager
actor CoverDownloadManager {
    static let shared = CoverDownloadManager()
    
    private var downloadTasks: [String: Task<UIImage?, Error>] = [:]
    
    private init() {}
    
    func downloadCover(for book: Book, api: AudiobookshelfAPI) async throws -> UIImage? {
        let cacheKey = "online_\(book.id)"
        
        // Check if already downloading
        if let existingTask = downloadTasks[cacheKey] {
            return try await existingTask.value
        }
        
        // Create download task
        let task = Task<UIImage?, Error> {
            defer {
                Task {
                    self.removeTask(for: cacheKey)
                }
            }
            // ✅ SWIFT 6 FIX - Check if self exists before calling method
            return try await self.performDownload(for: book, api: api)
        }
        
        downloadTasks[cacheKey] = task
        
        do {
            let result = try await task.value
            return result
        } catch {
            self.removeTask(for: cacheKey)
            throw error
        }
    }
    
    private func removeTask(for cacheKey: String) {
        downloadTasks.removeValue(forKey: cacheKey)
    }
    
    private func performDownload(for book: Book, api: AudiobookshelfAPI) async throws -> UIImage? {
        // Use the standard Audiobookshelf cover endpoint
        let coverURLString = "\(api.baseURLString)/api/items/\(book.id)/cover"
        guard let url = URL(string: coverURLString) else {
            throw CoverLoadingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(api.authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CoverLoadingError.downloadFailed
        }
        
        guard let image = UIImage(data: data) else {
            throw CoverLoadingError.invalidImageData
        }
        
        // Cache the downloaded image
        await MainActor.run {
            let cacheKey = "online_\(book.id)"
            CoverCacheManager.shared.setDiskCachedImage(image, for: cacheKey)
        }
        
        return image
    }
    
    func cancelDownload(for bookId: String) {
        let cacheKey = "online_\(bookId)"
        downloadTasks[cacheKey]?.cancel()
        downloadTasks.removeValue(forKey: cacheKey)
    }
    
    // ✅ NEW: Cancel all downloads on cleanup
    func cancelAllDownloads() {
        downloadTasks.values.forEach { $0.cancel() }
        downloadTasks.removeAll()
    }
}

// MARK: - Cover Loading Errors
enum CoverLoadingError: LocalizedError {
    case invalidURL
    case downloadFailed
    case invalidImageData
    case fileSystemError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid cover URL"
        case .downloadFailed: return "Failed to download cover"
        case .invalidImageData: return "Invalid image data"
        case .fileSystemError: return "File system error"
        }
    }
}

// MARK: - Book Cover Loader
@MainActor
class BookCoverLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading: Bool = false
    @Published var hasError: Bool = false
    @Published var downloadProgress: Double = 0.0
    
    private let book: Book
    private let api: AudiobookshelfAPI?
    private let downloadManager: DownloadManager?
    private let cacheManager = CoverCacheManager.shared
    private var loadTask: Task<Void, Never>?
    
    init(book: Book, api: AudiobookshelfAPI? = nil, downloadManager: DownloadManager? = nil) {
        self.book = book
        self.api = api
        self.downloadManager = downloadManager
    }
    
    func load() {
        // ✅ MEMORY LEAK FIX - Cancel any existing load task
        loadTask?.cancel()
        
        // Reset state
        hasError = false
        isLoading = true
        downloadProgress = 0.0
        
        // ✅ MEMORY LEAK FIX - Use weak self pattern
        loadTask = Task { [weak self] in
            await self?.loadCoverImage()
        }
    }
    
    private func loadCoverImage() async {
        print("[BookCoverLoader] Starting cover load for: \(book.title)")
        
        // Priority 1: Memory cache
        let memoryCacheKey = generateCacheKey()
        print("[BookCoverLoader] Cache key: \(memoryCacheKey)")
        
        if let cachedImage = cacheManager.getCachedImage(for: memoryCacheKey) {
            print("[BookCoverLoader] Found in memory cache")
            self.image = cachedImage
            self.isLoading = false
            return
        }
        
        // Priority 2: Disk cache
        if let diskCachedImage = cacheManager.getDiskCachedImage(for: memoryCacheKey) {
            print("[BookCoverLoader] Found in disk cache")
            self.image = diskCachedImage
            self.isLoading = false
            return
        }
        
        // Priority 3: Local downloaded cover
        if let localImage = await loadLocalCover() {
            print("[BookCoverLoader] Found local cover")
            self.image = localImage
            self.isLoading = false
            cacheManager.setDiskCachedImage(localImage, for: memoryCacheKey)
            return
        }
        
        // Priority 4: Embedded cover from audio files
        if let embeddedImage = await loadEmbeddedCover() {
            print("[BookCoverLoader] Found embedded cover")
            self.image = embeddedImage
            self.isLoading = false
            cacheManager.setDiskCachedImage(embeddedImage, for: memoryCacheKey)
            return
        }
        
        // Priority 5: Online cover with download and caching
        if let onlineImage = await loadOnlineCover() {
            print("[BookCoverLoader] Downloaded online cover")
            self.image = onlineImage
            self.isLoading = false
            return
        }
        
        // No cover found
        print("[BookCoverLoader] No cover found for: \(book.title)")
        self.hasError = true
        self.isLoading = false
    }
    
    private func generateCacheKey() -> String {
        // Create unique cache key based on book ID and potential sources
        var components = [book.id]
        
        if downloadManager?.isBookDownloaded(book.id) == true {
            components.append("local")
        }
        
        if let coverPath = book.coverPath {
            components.append(coverPath.hashValue.description)
        }
        
        return components.joined(separator: "_")
    }
    
    // MARK: - Local Cover Loading
    private func loadLocalCover() async -> UIImage? {
        guard let downloadManager = downloadManager,
              let localCoverURL = downloadManager.getLocalCoverURL(for: book.id),
              FileManager.default.fileExists(atPath: localCoverURL.path) else {
            return nil
        }
        
        return UIImage(contentsOfFile: localCoverURL.path)
    }
    
    // MARK: - Embedded Cover Loading
    private func loadEmbeddedCover() async -> UIImage? {
        guard let downloadManager = downloadManager else { return nil }
        
        let bookDir = downloadManager.bookDirectory(for: book.id)
        guard FileManager.default.fileExists(atPath: bookDir.path) else { return nil }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: bookDir,
                includingPropertiesForKeys: nil
            )
            
            let audioFiles = contents.filter {
                ["mp3", "m4a", "mp4", "flac"].contains($0.pathExtension.lowercased())
            }
            
            for audioFile in audioFiles {
                if let coverImage = await extractCoverFromAudioFile(audioFile) {
                    return coverImage
                }
            }
        } catch {
            print("[BookCoverLoader] Error reading directory: \(error)")
        }
        
        return nil
    }
    
    private func extractCoverFromAudioFile(_ url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        
        do {
            let metadata = try await asset.load(.commonMetadata)
            
            for item in metadata {
                if let commonKey = item.commonKey,
                   commonKey.rawValue == "artwork",
                   let data = try await item.load(.dataValue),
                   let image = UIImage(data: data) {
                    return image
                }
            }
        } catch {
            // Silent fail for individual files
        }
        
        return nil
    }
    
    // MARK: - Online Cover Loading with Download & Caching
    private func loadOnlineCover() async -> UIImage? {
        guard let api = api else { return nil }
        
        self.downloadProgress = 0.1
        
        do {
            let image = try await CoverDownloadManager.shared.downloadCover(for: book, api: api)
            self.downloadProgress = 1.0
            return image
        } catch {
            print("[BookCoverLoader] Online cover download failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Public Methods
    func preloadCover() {
        // ✅ MEMORY LEAK FIX - Use weak self pattern
        if image == nil && !isLoading {
            load()
        }
    }
    
    // ✅ MEMORY LEAK FIX - Safe cleanup method
    func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
    
    // ✅ MEMORY LEAK FIX - Proper deinit without main actor
    deinit {
        loadTask?.cancel()
    }
}

// MARK: - Book Cover View
struct BookCoverView: View {
    let book: Book
    let api: AudiobookshelfAPI?
    let downloadManager: DownloadManager?
    let size: CGSize
    let showLoadingProgress: Bool
    
    @StateObject private var loader: BookCoverLoader
    
    init(
        book: Book,
        api: AudiobookshelfAPI? = nil,
        downloadManager: DownloadManager? = nil,
        size: CGSize,
        showLoadingProgress: Bool = false
    ) {
        self.book = book
        self.api = api
        self.downloadManager = downloadManager
        self.size = size
        self.showLoadingProgress = showLoadingProgress
        self._loader = StateObject(wrappedValue: BookCoverLoader(
            book: book,
            api: api,
            downloadManager: downloadManager
        ))
    }
    
    var body: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if loader.isLoading {
                loadingView
            } else {
                placeholderView
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            loader.load()
        }
        .onChange(of: book.id) { _, _ in
            loader.load()
        }
        // ✅ MEMORY LEAK FIX - Cancel loading when view disappears
        .onDisappear {
            loader.cancelLoading()
        }
        .animation(.easeInOut(duration: 0.3), value: loader.image != nil)
    }
    
    private var loadingView: some View {
        ZStack {
            Color.gray.opacity(0.2)
            
            VStack(spacing: 8) {
                if showLoadingProgress && loader.downloadProgress > 0 {
                    ProgressView(value: loader.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                        .frame(width: size.width * 0.6)
                    
                    Text("\(Int(loader.downloadProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.accentColor)
                }
            }
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.3),
                    Color.accentColor.opacity(0.6),
                    Color.accentColor.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: max(size.width * 0.08, 8)) {
                Image(systemName: loader.hasError ? "exclamationmark.triangle.fill" : "book.closed.fill")
                    .font(.system(size: size.width * 0.25))
                    .foregroundColor(.white)
                
                if size.width > 100 {
                    Text(loader.hasError ? "Cover nicht verfügbar" : book.title)
                        .font(.system(size: size.width * 0.08, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                }
            }
        }
    }
}

// MARK: - Convenience Extensions
extension BookCoverView {
    /// Creates a square cover view
    static func square(
        book: Book,
        size: CGFloat,
        api: AudiobookshelfAPI? = nil,
        downloadManager: DownloadManager? = nil,
        showProgress: Bool = false
    ) -> BookCoverView {
        BookCoverView(
            book: book,
            api: api,
            downloadManager: downloadManager,
            size: CGSize(width: size, height: size),
            showLoadingProgress: showProgress
        )
    }
    
    /// Creates a cover view with typical book aspect ratio (3:4)
    static func bookAspect(
        book: Book,
        width: CGFloat,
        api: AudiobookshelfAPI? = nil,
        downloadManager: DownloadManager? = nil,
        showProgress: Bool = false
    ) -> BookCoverView {
        let height = width * 4/3
        return BookCoverView(
            book: book,
            api: api,
            downloadManager: downloadManager,
            size: CGSize(width: width, height: height),
            showLoadingProgress: showProgress
        )
    }
}

// MARK: - UserDefaults Extensions für Cache Settings
extension UserDefaults {
    private enum CacheKeys {
        static let coverCacheLimit = "cover_cache_limit"
        static let memoryCacheSize = "memory_cache_size"
        static let autoCacheCleanup = "auto_cache_cleanup"
        static let cacheOptimizationEnabled = "cache_optimization_enabled"
    }
    
    var coverCacheLimit: Int {
        get { integer(forKey: CacheKeys.coverCacheLimit) }
        set { set(newValue, forKey: CacheKeys.coverCacheLimit) }
    }
    
    var memoryCacheSize: Int {
        get { integer(forKey: CacheKeys.memoryCacheSize) }
        set { set(newValue, forKey: CacheKeys.memoryCacheSize) }
    }
    
    var autoCacheCleanup: Bool {
        get { bool(forKey: CacheKeys.autoCacheCleanup) }
        set { set(newValue, forKey: CacheKeys.autoCacheCleanup) }
    }
    
    var cacheOptimizationEnabled: Bool {
        get { bool(forKey: CacheKeys.cacheOptimizationEnabled) }
        set { set(newValue, forKey: CacheKeys.cacheOptimizationEnabled) }
    }
}
