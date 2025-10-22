import SwiftUI

struct LibraryView: View {
    @StateObject var viewModel: LibraryViewModel
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var theme: ThemeManager

    @State private var selectedSeries: Book?
    @State private var bookCardVMs: [BookCardStateViewModel] = []
    
    init(player: AudioPlayer, api: AudiobookshelfAPI, downloadManager: DownloadManager, onBookSelected: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: LibraryViewModelFactory.create(
            api: api,
            player: player,
            downloadManager: downloadManager,
            onBookSelected: onBookSelected
        ))
    }
    
    var body: some View {
        ZStack {
            
            if theme.backgroundStyle == .dynamic {
                Color.accent.ignoresSafeArea()
            }

            
            switch viewModel.uiState {
            case .loading:
                LoadingView()
            case .error(let message):
                ErrorView(error: message)
            case .empty:
                EmptyStateView()
            case .noDownloads:
                NoDownloadsView()
            case .noSearchResults:
                NoSearchResultsView()
            case .content:
                contentView
            }
        }
        .navigationTitle(viewModel.libraryName)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarColorScheme(
            theme.colorScheme,
            for: .navigationBar
        )
        .searchable(
            text: $viewModel.filterState.searchText,
            placement: .automatic,
            prompt: "Search books...")
        .refreshable {
            await viewModel.loadBooks()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if !viewModel.books.isEmpty {
                        filterAndSortMenu
                    }
                    SettingsButton()
                }
            }
        }
        .alert("Fehler", isPresented: $viewModel.showingErrorAlert) {
            Button("OK") { }
            Button("Erneut versuchen") {
                Task { await viewModel.loadBooks() }
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unbekannter Fehler")
        }
        .task {
            await viewModel.loadBooksIfNeeded()
            updateBookCardViewModels()
        }
        .sheet(item: $selectedSeries) { series in
            SeriesQuickAccessView(
                seriesBook: series,
                player: viewModel.player,
                api: viewModel.api,
                downloadManager: viewModel.downloadManager,
                onBookSelected: viewModel.onBookSelected
            )
            .environmentObject(viewModel)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: viewModel.filteredAndSortedBooks.count) {
            updateBookCardViewModels()
        }
        .onReceive(viewModel.player.$currentTime.throttle(for: .seconds(2), scheduler: RunLoop.main, latest: true)) { _ in
            updateCurrentBookOnly()
        }
        .onReceive(viewModel.downloadManager.$downloadProgress.throttle(for: .milliseconds(500), scheduler: RunLoop.main, latest: true)) { _ in
            updateDownloadingBooksOnly()
        }
    }
    
    private var contentView: some View {
        ZStack {
            if theme.backgroundStyle == .dynamic {
                DynamicBackground()
            }

            VStack(spacing: 0) {
                if viewModel.filterState.showDownloadedOnly {
                    FilterStatusBannerView(
                        count: viewModel.filteredAndSortedBooks.count,
                        totalDownloaded: viewModel.downloadedBooksCount,
                        onDismiss: { viewModel.toggleDownloadFilter() }
                    )
                }
                
                if viewModel.filterState.showSeriesGrouped {
                    SeriesStatusBannerView(
                        books: viewModel.filteredAndSortedBooks,
                        onDismiss: { viewModel.toggleSeriesMode() }
                    )
                }
                
                ScrollView {
                    LazyVGrid(columns: DSGridColumns.two) {
                        ForEach(bookCardVMs) { bookVM in
                            BookCardView(
                                viewModel: bookVM,
                                api: viewModel.api,
                                onTap: {
                                    handleBookTap(bookVM.book)
                                },
                                onDownload: {
                                    startDownload(bookVM.book)
                                },
                                onDelete: {
                                    deleteDownload(bookVM.book)
                                },
                                style: .library
                            )

                        }
                        .padding(.bottom, DSLayout.elementPadding)
                    }

                    Spacer()
                    .frame(height: DSLayout.miniPlayerHeight)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, DSLayout.screenPadding)
            }
        }
        .opacity(viewModel.contentLoaded ? 1 : 0)
        .animation(.easeInOut(duration: 0.5), value: viewModel.contentLoaded)
        .animation(.easeInOut(duration: 0.3), value: viewModel.uiState)
        .onAppear { viewModel.contentLoaded = true }
    }
    
    // MARK: - Ultra-Optimized Update Logic
    
    private func updateBookCardViewModels() {
        let books = viewModel.filteredAndSortedBooks
        let player = viewModel.player
        let downloadManager = viewModel.downloadManager
        
        Task.detached(priority: .userInitiated) {
            let newVMs = books.map { book in
                BookCardStateViewModel(
                    book: book,
                    player: player,
                    downloadManager: downloadManager
                )
            }
            
            await MainActor.run {
                self.bookCardVMs = newVMs
            }
        }
    }
    
    private func updateCurrentBookOnly() {
        guard let currentBookId = viewModel.player.book?.id,
              let index = bookCardVMs.firstIndex(where: { $0.id == currentBookId }) else {
            return
        }
        
        let updatedVM = BookCardStateViewModel(
            book: bookCardVMs[index].book,
            player: viewModel.player,
            downloadManager: viewModel.downloadManager
        )
        
        if bookCardVMs[index] != updatedVM {
            bookCardVMs[index] = updatedVM
        }
    }
    
    private func updateDownloadingBooksOnly() {
        let downloadingIds = Set(viewModel.downloadManager.downloadProgress.keys)
        
        for (index, vm) in bookCardVMs.enumerated() {
            if downloadingIds.contains(vm.id) {
                let updatedVM = BookCardStateViewModel(
                    book: vm.book,
                    player: viewModel.player,
                    downloadManager: viewModel.downloadManager
                )
                
                if bookCardVMs[index] != updatedVM {
                    bookCardVMs[index] = updatedVM
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleBookTap(_ book: Book) {
        if book.isCollapsedSeries {
            selectedSeries = book
        } else {
            Task {
                await viewModel.playBook(book, appState: appState)
            }
        }
    }
    
    private func startDownload(_ book: Book) {
        Task {
            await viewModel.downloadManager.downloadBook(book, api: viewModel.api)
        }
    }
    
    private func deleteDownload(_ book: Book) {
        viewModel.downloadManager.deleteBook(book.id)
    }

    // MARK: - Toolbar Components
    
    private var filterAndSortMenu: some View {
        Menu {
            Section("Sort to") {
                ForEach(LibrarySortOption.allCases, id: \.self) { option in
                    Button(action: {
                        viewModel.filterState.selectedSortOption = option
                    }) {
                        Label(option.rawValue, systemImage: option.systemImage)
                        if viewModel.filterState.selectedSortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            Divider()
            
            Section("Filter") {
                Button(action: {
                    viewModel.toggleDownloadFilter()
                }) {
                    Label("Only downloaded", systemImage: "arrow.down.circle")
                    if viewModel.filterState.showDownloadedOnly {
                        Image(systemName: "checkmark")
                    }
                }
                
                if viewModel.downloadedBooksCount > 0 {
                    Text("\(viewModel.downloadedBooksCount) downloaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Section("View") {
                Button(action: {
                    viewModel.toggleSeriesMode()
                }) {
                    Label("Bundled series", systemImage: "rectangle.stack")
                    if viewModel.filterState.showSeriesGrouped {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Section("Library") {
                LibraryStatsView(
                    viewModel: viewModel,
                    isSeriesMode: viewModel.filterState.showSeriesGrouped
                )
            }
            
            if viewModel.filterState.showDownloadedOnly || viewModel.filterState.showSeriesGrouped || !viewModel.filterState.searchText.isEmpty {
                Divider()
                
                Section {
                    Button(action: {
                        viewModel.resetFilters()
                    }) {
                        Label("Reset filter", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            
        } label: {
            ZStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                if viewModel.filterState.showDownloadedOnly || viewModel.filterState.showSeriesGrouped {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                        .offset(x: 8, y: -8)
                }
            }
        }
    }
}

// MARK: - Filter Status Banner Component
struct FilterStatusBannerView: View {
    let count: Int
    let totalDownloaded: Int
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            Text("Show \(count) von \(totalDownloaded) downloaded books")
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
}

// MARK: - Series Status Banner Component
struct SeriesStatusBannerView: View {
    let books: [Book]
    let onDismiss: () -> Void
    
    private var seriesCount: Int {
        books.lazy.filter { $0.isCollapsedSeries }.count
    }
    
    private var booksCount: Int {
        books.count - seriesCount
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 16))
                .foregroundColor(.blue)
            
            if seriesCount > 0 && booksCount > 0 {
                Text("Show \(seriesCount) Series • \(booksCount) Books")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            } else if seriesCount > 0 {
                Text("Show \(seriesCount) Series")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            } else {
                Text("Show \(booksCount) books")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
}

// MARK: - Library Stats Component
struct LibraryStatsView: View {
    let viewModel: LibraryViewModel
    let isSeriesMode: Bool
    
    private var seriesCount: Int {
        viewModel.filteredAndSortedBooks.lazy.filter { $0.isCollapsedSeries }.count
    }
    
    private var booksCount: Int {
        viewModel.filteredAndSortedBooks.count - seriesCount
    }
    
    var body: some View {
        HStack {
            if isSeriesMode {
                Text("Total: \(seriesCount) Series • \(booksCount) Books")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Total: \(viewModel.totalBooksCount) Books")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
