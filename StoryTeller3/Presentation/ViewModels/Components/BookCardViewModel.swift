import SwiftUI

class BookCardViewModel: ObservableObject {
    @Published var isPressed = false
    
    let book: Book
    let player: AudioPlayer
    let downloadManager: DownloadManager
    let api: AudiobookshelfAPI?
    private let downloadUseCase: DownloadBookUseCase
    
    var isCurrentBook: Bool {
        player.book?.id == book.id
    }
    
    var isDownloaded: Bool {
        downloadManager.isBookDownloaded(book.id)
    }
    
    var isDownloading: Bool {
        downloadManager.isDownloadingBook(book.id)
    }
    
    var downloadProgress: Double {
        downloadManager.downloadProgress[book.id] ?? 0.0
    }
    
    var downloadStatus: String? {
        downloadManager.downloadStatus[book.id]
    }
    
    var downloadStage: DownloadStage? {
        downloadManager.downloadStage[book.id]
    }
    
    var playbackProgress: Double {
        guard player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }
    
    var currentTime: Double {
        player.currentTime
    }
    
    var duration: Double {
        player.duration
    }
    
    var isPlaying: Bool {
        player.isPlaying
    }
    
    init(
        book: Book,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        api: AudiobookshelfAPI?
    ) {
        self.book = book
        self.player = player
        self.downloadManager = downloadManager
        self.api = api
        self.downloadUseCase = DownloadBookUseCase(downloadManager: downloadManager)
    }
    
    func startDownload() {
        guard let api = api else {
            AppLogger.debug.debug("[BookCardViewModel] Cannot download: API not available")
            return
        }
        
        Task {
            await downloadUseCase.execute(book: book, api: api)
        }
    }
    
    func cancelDownload() {
        AppLogger.debug.debug("[BookCardViewModel] Cancel download requested for: \(self.book.title)")
        downloadUseCase.cancel(bookId: book.id)
    }
    
    func deleteDownload() {
        downloadUseCase.delete(bookId: book.id)
    }
}
