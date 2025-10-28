import Foundation

/// Use Case for preloading book covers
/// Replaces direct CoverPreloadHelpers calls in ViewModels
protocol CoverPreloadUseCaseProtocol {
    func execute(books: [Book], limit: Int) async
    func execute(book: Book) async
}

@MainActor
class CoverPreloadUseCase: CoverPreloadUseCaseProtocol {
    private let coverCacheManager: CoverCacheManager
    private let api: AudiobookshelfClient
    private let downloadManager: DownloadManager
    
    init(
        coverCacheManager: CoverCacheManager = .shared,
        api: AudiobookshelfClient,
        downloadManager: DownloadManager
    ) {
        self.coverCacheManager = coverCacheManager
        self.api = api
        self.downloadManager = downloadManager
    }
    
    func execute(books: [Book], limit: Int = 10) async {
        guard !books.isEmpty else { return }
        
        coverCacheManager.preloadCovers(
            for: Array(books.prefix(limit)),
            api: api,
            downloadManager: downloadManager
        )
    }
    
    func execute(book: Book) async {
        await execute(books: [book], limit: 1)
    }
}
