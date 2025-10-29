// REFACTORED: SeriesSectionViewModel
// Changes: Container injection instead of direct player/downloadManager parameters

import Foundation
import SwiftUI

@MainActor
class SeriesSectionViewModel: ObservableObject {
    let series: Series
    let api: AudiobookshelfClient
    let onBookSelected: () -> Void
    private let container: DependencyContainer
    
    // Computed properties for shared services
    var player: AudioPlayer { container.player }
    var downloadManager: DownloadManager { container.downloadManager }
    
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    init(
        series: Series,
        api: AudiobookshelfClient,
        onBookSelected: @escaping () -> Void,
        container: DependencyContainer = .shared
    ) {
        self.series = series
        self.api = api
        self.onBookSelected = onBookSelected
        self.container = container
        
        // Convert LibraryItems to Books
        self.books = series.books.compactMap { libraryItem in
            api.converter.convertLibraryItemToBook(libraryItem)
        }
    }
    
    func isBookDownloaded(_ bookId: String) -> Bool {
        downloadManager.isBookDownloaded(bookId)
    }
    
    func isCurrentBook(_ bookId: String) -> Bool {
        player.book?.id == bookId
    }
    
    func isPlaying(for bookId: String) -> Bool {
        isCurrentBook(bookId) && player.isPlaying
    }
}
