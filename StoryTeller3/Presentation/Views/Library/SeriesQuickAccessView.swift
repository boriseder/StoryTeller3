import SwiftUI

struct SeriesQuickAccessView: View {
    @StateObject private var viewModel: SeriesQuickAccessViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppStateManager
    
    
    init(
        seriesBook: Book,
        onBookSelected: @escaping () -> Void
        ) {
        _viewModel = StateObject(wrappedValue: SeriesQuickAccessViewModel(
            seriesBook: seriesBook,
            container: .shared,
            onBookSelected: onBookSelected
        ))
        }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DSLayout.contentGap) {
                // Series Header
                seriesHeaderView
                
                Divider()
                
                booksGridView
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                await viewModel.loadSeriesBooks()
            }
        }
    }
    
    private var seriesHeaderView: some View {
        HStack(alignment: .top) {
            // Series Info
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(viewModel.seriesBook.displayTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                if !viewModel.seriesBooks.isEmpty {
                    HStack(spacing: DSLayout.elementGap) {
                        Text("\(viewModel.seriesBooks.count) Books")
                        
                        if viewModel.downloadedCount > 0 {
                            Text(" • \(viewModel.downloadedCount) downloaded")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .layoutPriority(1) // verhindert, dass der Titel zu klein wird
            
            Spacer()
            
            // Dismiss Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSLayout.screenPadding)
        .padding(.top, DSLayout.comfortPadding)
    }
    
    private var booksGridView: some View {
        
        ScrollView {
            LazyVGrid(columns: DSGridColumns.two, spacing: 0) {
                ForEach(viewModel.seriesBooks, id: \.id) { book in
                    let cardViewModel = BookCardStateViewModel(book: book)
                    BookCardView(
                        viewModel: cardViewModel,
                        api: viewModel.api,
                        onTap: {},
                        onDownload: {},
                        onDelete: {},
                        style: .series
                    )
                }
            }
            .padding(.horizontal, DSLayout.contentPadding)
        }
    }
}
