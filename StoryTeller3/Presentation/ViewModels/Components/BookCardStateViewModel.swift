// REFACTORED: BookCardStateViewModel
// Changes: Container injection instead of direct player/downloadManager parameters

import Foundation
import SwiftUI

@MainActor
class BookCardStateViewModel: ObservableObject, Identifiable {
    let book: Book
    private let container: DependencyContainer
    
    // Computed properties instead of stored references
    private var player: AudioPlayer { container.player }
    private var downloadManager: DownloadManager { container.downloadManager }
    
    var id: String { book.id }
    
    init(book: Book, container: DependencyContainer = .shared) {
        self.book = book
        self.container = container
    }
    
    var isCurrentBook: Bool {
        player.book?.id == book.id
    }
    
    var isPlaying: Bool {
        isCurrentBook && player.isPlaying
    }
    
    var isDownloaded: Bool {
        downloadManager.isBookDownloaded(book.id)
    }
    
    var downloadProgress: Double {
        downloadManager.getDownloadProgress(for: book.id)
    }
    
    var isDownloading: Bool {
        downloadManager.isDownloadingBook(book.id)
    }
    
    var duration: Double {
        guard isCurrentBook else { return 0 }
        return player.duration
    }
    
    var currentProgress: Double {
        guard isCurrentBook, player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }
}
