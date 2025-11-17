import SwiftUI

struct AuthorDetailView: View {
    let author: Author
    let onBookSelected: (InitialPlayerMode) -> Void

    @StateObject private var viewModel: AuthorDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppStateManager
    @EnvironmentObject var theme: ThemeManager

    init(author: Author, onBookSelected: @escaping (InitialPlayerMode) -> Void) {
        self.author = author
        self.onBookSelected = onBookSelected

        // Dependencies vom Container holen
        let container = DependencyContainer.shared
        _viewModel = StateObject(wrappedValue: AuthorDetailViewModel(
            bookRepository: container.bookRepository,     // ← BookRepositoryProtocol
            api: container.apiClient!,                    // ← AudiobookshelfClient
            downloadManager: container.downloadManager,
            player: container.player,
            appState: container.appState,                 // ← Wird später in task gesetzt
            playBookUseCase: PlayBookUseCase(),           // ← PlayBookUseCase Instance
            author: author,                               // ← Author Object
            onBookSelected: onBookSelected                // ← Closure
        ))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                contentView(geometry: geometry)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                viewModel.onDismiss = { dismiss() }
                await viewModel.loadAuthorDetails()
            }
        }
    }
    
    private func contentView(geometry: GeometryProxy) -> some View {
        ZStack {
                        
            VStack(alignment: .leading, spacing: DSLayout.adaptiveContentGap) {
                authorHeaderView                
                
                ScrollView {
                    LazyVGrid(columns: ResponsiveLayout.columns(for: geometry.size), spacing: DSLayout.adaptiveContentGap) {
                        ForEach(viewModel.authorBooks, id: \.id) { book in
                            let cardViewModel = BookCardStateViewModel(book: book)
                            BookCardView(
                                viewModel: cardViewModel,
                                api: viewModel.api,  // ← Muss public sein!
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
                                style: .library,
                                containerSize: geometry.size
                            )
                        }
                    }
                    .padding(.horizontal, DSLayout.contentPadding)
                    .padding(.top, DSLayout.adaptiveContentGap)
                }
            }
        }
    }
    
    private var authorHeaderView: some View {
        
        HStack(alignment: .center) {
            // Author Image
            AuthorImageView(
                author: author,
                api: DependencyContainer.shared.apiClient,
                size: DSLayout.smallAvatar
            )
            
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(viewModel.author.name)
                    .font(DSText.itemTitle)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if !viewModel.authorBooks.isEmpty {
                    HStack(spacing: DSLayout.elementGap) {
                        Text("\(author.numBooks ?? 0) \((author.numBooks ?? 0) == 1 ? "Book" : "Books")")

                        if viewModel.downloadedCount > 0 {
                            Text(" • \(viewModel.downloadedCount) downloaded")
                        }
                        
                        if viewModel.totalDuration > 0 {
                            Text(" • \(TimeFormatter.formatTimeCompact(viewModel.totalDuration)) total")
                        }
                    }
                    .font(DSText.metadata)
                }
            }
            .layoutPriority(1)
            .padding(.leading, DSLayout.elementGap)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(DeviceType.current == .iPad ? .largeTitle : .title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSLayout.adaptiveScreenPadding)
        .padding(.top, DSLayout.adaptiveContentGap)
    }
}
