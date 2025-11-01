// REFACTORED: SeriesSectionView
// Changes: Removed player and downloadManager parameters from init

import SwiftUI

struct SeriesSectionView: View {
    @StateObject private var viewModel: SeriesSectionViewModel
    
    init(
        series: Series,
        api: AudiobookshelfClient,
        onBookSelected: @escaping () -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: SeriesSectionViewModel(
            series: series,
            api: api,
            onBookSelected: onBookSelected
            // container is default parameter
        ))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Series header
            Text(viewModel.series.name)
                .font(DSText.itemTitle)
                .padding(.horizontal, DSLayout.tightPadding)
            
            // Books scroll view
            if viewModel.books.isEmpty {
                emptyView
            } else {
                booksScrollView
            }
        }
    }
    
    private var booksScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(viewModel.books) { book in
                    BookCardView(
                        viewModel: BookCardStateViewModel(book: book),
                        api: viewModel.api,
                        onTap: {
                            viewModel.onBookSelected()
                        },
                        onDownload: {
                            handleDownload(for: book)
                        },
                        onDelete: {
                            handleDelete(for: book)
                        },
                        style: .series
                    )
                }
            }
        }
    }
    
    private var emptyView: some View {
        Text("No books in this series")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
    }
    
    private func handleDownload(for book: Book) {
        Task {
            await viewModel.downloadManager.downloadBook(book, api: viewModel.api)
        }
    }
    
    private func handleDelete(for book: Book) {
        viewModel.downloadManager.deleteBook(book.id)
    }
}
