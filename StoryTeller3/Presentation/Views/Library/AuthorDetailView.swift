import SwiftUI

struct AuthorDetailView: View {
    @StateObject private var viewModel: AuthorDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppStateManager
    
    init(authorName: String, onBookSelected: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AuthorDetailViewModel(
            authorName: authorName,
            container: .shared,
            onBookSelected: onBookSelected
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DSLayout.contentGap) {
                authorHeaderView
                
                Divider()
                
                booksGridView
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                viewModel.onDismiss = { dismiss() }
                await viewModel.loadAuthorBooks()
            }
        }
    }
    
    private var authorHeaderView: some View {
        HStack(alignment: .top) {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(String(viewModel.authorName.prefix(2).uppercased()))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.accentColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.authorName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if !viewModel.authorBooks.isEmpty {
                    HStack(spacing: 8) {
                        Text("\(viewModel.authorBooks.count) books")
                        
                        if viewModel.downloadedCount > 0 {
                            Text("• \(viewModel.downloadedCount) downloaded")
                        }
                        
                        if viewModel.totalDuration > 0 {
                            Text("• \(TimeFormatter.formatTimeCompact(viewModel.totalDuration))")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .layoutPriority(1)
            
            Spacer()
            
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
                ForEach(viewModel.authorBooks, id: \.id) { book in
                    let cardViewModel = BookCardStateViewModel(book: book)
                    BookCardView(
                        viewModel: cardViewModel,
                        api: viewModel.api,
                        onTap: {
                            Task {
                                await viewModel.playBook(book, appState: appState)
                            }
                        },
                        onDownload: {
                            Task {
                                await viewModel.downloadBook(book)
                            }
                        },
                        onDelete: {
                            viewModel.deleteBook(book.id)
                        },
                        style: .library
                    )
                }
            }
            .padding(.horizontal, DSLayout.contentPadding)
        }
    }
}
