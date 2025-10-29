// REFACTORED: HorizontalBookScrollView
// Changes: Removed player and downloadManager parameters - use container via BookCardStateViewModel

import SwiftUI

struct HorizontalBookScrollView: View {
    let books: [Book]
    let api: AudiobookshelfClient
    let onBookSelected: (Book) -> Void
    let cardStyle: BookCardStyle
    
    @State private var bookCardVMs: [BookCardStateViewModel] = []
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(bookCardVMs) { bookVM in
                    BookCardView(
                        viewModel: bookVM,
                        api: api,
                        onTap: {
                            onBookSelected(bookVM.book)
                        },
                        onDownload: {
                            handleDownload(for: bookVM.book)
                        },
                        onDelete: {
                            handleDelete(for: bookVM.book)
                        },
                        style: cardStyle
                    )
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            updateBookCardViewModels()
        }
        .onChange(of: books) { _, _ in
            updateBookCardViewModels()
        }
    }
    
    private func updateBookCardViewModels() {
        let newVMs = books.map { book in
            BookCardStateViewModel(book: book) // Container is default
        }
        bookCardVMs = newVMs
    }
    
    private func handleDownload(for book: Book) {
        // Download logic
    }
    
    private func handleDelete(for book: Book) {
        // Delete logic
    }
}
