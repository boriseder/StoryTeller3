import SwiftUI

// MARK: - Horizontal Book Scroll View
struct HorizontalBookScrollView: View {
    let books: [Book]
    let onBookSelected: (Book) -> Void
    let cardStyle: BookCardStyle
    
    @State private var bookCardVMs: [BookCardStateViewModel] = []
    @State private var updateTimer: Timer?
    @EnvironmentObject var container: DependencyContainer

    init(books: [Book], cardStyle: BookCardStyle, onBookSelected: @escaping (Book) -> Void)
    {
        self.books = books
        self.onBookSelected = onBookSelected
        self.cardStyle = cardStyle
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSLayout.contentGap) {
                ForEach(bookCardVMs) { bookVM in
                    BookCardView(
                        viewModel: bookVM,
                        onTap: {
                            onBookSelected(bookVM.book)
                        },
                        onDownload: {
                            Task {
                                await container.downloadManager.downloadBook(bookVM.book, api: container.audiobookshelfClient)
                            }
                        },
                        onDelete: {
                            container.downloadManager.deleteBook(bookVM.book.id)
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
                player: container.audioPlayer,
                downloadManager: container.downloadManager
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
