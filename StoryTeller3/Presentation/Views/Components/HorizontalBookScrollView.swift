import SwiftUI

// MARK: - Horizontal Book Scroll View
struct HorizontalBookScrollView: View {
    let books: [Book]
    let player: AudioPlayer
    let api: AudiobookshelfAPI
    let downloadManager: DownloadManager
    let onBookSelected: (Book) -> Void
    let cardStyle: BookCardStyle
    
    @State private var bookCardVMs: [BookCardStateViewModel] = []
    @State private var updateTimer: Timer?
    
    init(
        books: [Book],
        player: AudioPlayer,
        api: AudiobookshelfAPI,
        downloadManager: DownloadManager,
        cardStyle: BookCardStyle = .library,
        onBookSelected: @escaping (Book) -> Void
    ) {
        self.books = books
        self.player = player
        self.api = api
        self.downloadManager = downloadManager
        self.cardStyle = cardStyle
        self.onBookSelected = onBookSelected
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSLayout.contentGap) {
                ForEach(bookCardVMs) { bookVM in
                    BookCardView(
                        viewModel: bookVM,
                        api: api,
                        onTap: {
                            onBookSelected(bookVM.book)
                        },
                        onDownload: {
                            Task {
                                await downloadManager.downloadBook(bookVM.book, api: api)
                            }
                        },
                        onDelete: {
                            downloadManager.deleteBook(bookVM.book.id)
                        },
                        style: cardStyle
                    )
                }
            }
        }
        .onAppear {
            updateBookCardViewModels()
            startPeriodicUpdates()
        }
        .onDisappear {
            stopPeriodicUpdates()
        }
    }
    
    private func updateBookCardViewModels() {
        let newVMs = books.map { book in
            BookCardStateViewModel(
                book: book,
                player: player,
                downloadManager: downloadManager
            )
        }
        
        if bookCardVMs != newVMs {
            bookCardVMs = newVMs
        }
    }
    
    private func startPeriodicUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateBookCardViewModels()
        }
    }
    
    private func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}
