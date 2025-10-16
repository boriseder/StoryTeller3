import Foundation

// MARK: - Book Card State View Model
struct BookCardStateViewModel: Identifiable, Equatable {
    let id: String
    let book: Book
    let isCurrentBook: Bool
    let isPlaying: Bool
    let currentProgress: Double
    let currentTime: Double
    let duration: Double
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let downloadStatus: String?
    
    init(book: Book, player: AudioPlayer, downloadManager: DownloadManager) {
        self.id = book.id
        self.book = book
        self.isCurrentBook = player.book?.id == book.id
        self.isPlaying = isCurrentBook && player.isPlaying
        self.currentTime = isCurrentBook ? player.currentTime : 0
        self.duration = isCurrentBook ? player.duration : 0
        self.currentProgress = duration > 0 ? currentTime / duration : 0
        self.isDownloaded = downloadManager.isBookDownloaded(book.id)
        self.isDownloading = downloadManager.isDownloadingBook(book.id)
        self.downloadProgress = downloadManager.downloadProgress[book.id] ?? 0.0
        self.downloadStatus = downloadManager.downloadStatus[book.id]
    }
    
    static func == (lhs: BookCardStateViewModel, rhs: BookCardStateViewModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.isCurrentBook == rhs.isCurrentBook &&
               lhs.isPlaying == rhs.isPlaying &&
               lhs.isDownloaded == rhs.isDownloaded &&
               lhs.isDownloading == rhs.isDownloading &&
               abs(lhs.currentProgress - rhs.currentProgress) < 0.01 &&
               abs(lhs.downloadProgress - rhs.downloadProgress) < 0.01
    }
}
