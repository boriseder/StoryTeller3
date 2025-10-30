// REFACTORED: HorizontalBookScrollView
// Changes: Removed player and downloadManager parameters - use container via BookCardStateViewModel
// Fixed: Added actual download and delete implementations

import SwiftUI
import Combine

struct HorizontalBookScrollView: View {
    let books: [Book]
    let api: AudiobookshelfClient
    @ObservedObject var downloadManager: DownloadManager
    let onBookSelected: (Book) -> Void
    let cardStyle: BookCardStyle
    
    @State private var bookCardVMs: [BookCardStateViewModel] = []

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DSLayout.contentGap) {
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
        }
        .onAppear {
            updateBookCardViewModels()
        }
        .onChange(of: books) { _, _ in
            updateBookCardViewModels()
        }
        .onReceive(downloadManager.$downloadProgress.throttle(for: .milliseconds(500), scheduler: RunLoop.main, latest: true)) { _ in
            updateDownloadingBooksOnly()
        }
        .onReceive(downloadManager.$isDownloading.throttle(for: .milliseconds(500), scheduler: RunLoop.main, latest: true)) { _ in
            updateDownloadingBooksOnly()
        }
    }
    
    private func updateBookCardViewModels() {
        let newVMs = books.map { book in
            BookCardStateViewModel(book: book) // Container is default
        }
        bookCardVMs = newVMs
    }
    
    private func handleDownload(for book: Book) {
        Task {
            await downloadManager.downloadBook(book, api: api)
        }
    }
    
    private func handleDelete(for book: Book) {
        downloadManager.deleteBook(book.id)
    }
    
    private func updateDownloadingBooksOnly() {
        let downloadingIds = Set(downloadManager.downloadProgress.keys)
        let downloadedIds = Set(downloadManager.downloadedBooks.map { $0.id })
        
        for (index, vm) in bookCardVMs.enumerated() {
            if downloadingIds.contains(vm.id) || downloadedIds.contains(vm.id) {
                bookCardVMs[index] = BookCardStateViewModel(book: vm.book)
            }
        }
    }
}
