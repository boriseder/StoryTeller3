import SwiftUI

struct LibraryView: View {
    @StateObject var viewModel: LibraryViewModel
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var appConfig: AppConfig

    @State private var selectedSeries: Book?
    
    init(player: AudioPlayer, api: AudiobookshelfAPI, downloadManager: DownloadManager, onBookSelected: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: LibraryViewModelFactory.create(
            api: api,
            player: player,
            downloadManager: downloadManager,
            onBookSelected: onBookSelected
        ))
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 132, maximum: 160), spacing: 16)
    ]

    var body: some View {
        Group {
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
            appConfig.userBackgroundStyle.textColor == .white ? .dark : .light,
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
    }
    
    
    private var contentView: some View {
        ZStack {
            DynamicBackground()
            
            VStack(spacing: 0) {
                // Filter-Status-Banner (wenn Download-Filter aktiv)
                if viewModel.filterState.showDownloadedOnly {
                    filterStatusBanner
                }
                
                // Series-Status-Banner (wenn Series-Modus aktiv)
                if viewModel.filterState.showSeriesGrouped {
                    seriesStatusBanner
                }
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.filteredAndSortedBooks) { book in
                            BookCardView.library(
                                book: book,
                                player: viewModel.player,
                                api: viewModel.api,
                                downloadManager: viewModel.downloadManager,
                                onTap: {
                                    handleBookTap(book)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
    }
    // MARK: - Subviews
           
    private func handleBookTap(_ book: Book) {
        if book.isCollapsedSeries {
            selectedSeries = book
        } else {
            Task {
                await viewModel.playBook(book, appState: appState)
            }
        }
    }


    // MARK: - Status Banners
    
    private var filterStatusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            Text("Show \(viewModel.filteredAndSortedBooks.count) von \(viewModel.downloadedBooksCount) downloaded books")
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                viewModel.toggleDownloadFilter()
            }) {
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
    
    private var seriesStatusBanner: some View {
        let seriesCount = viewModel.filteredAndSortedBooks.filter { $0.isCollapsedSeries }.count
        let booksCount = viewModel.filteredAndSortedBooks.filter { !$0.isCollapsedSeries }.count
        
        return HStack(spacing: 12) {
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
            
            Button(action: {
                viewModel.toggleSeriesMode()
            }) {
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

    // MARK: - Toolbar Components
    
    private var filterAndSortMenu: some View {
        Menu {
            // Sortierung Section
            Section("Sort to") {
                ForEach(LibrarySortOption.allCases, id: \.self) { option in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.filterState.selectedSortOption = option
                        }
                    }) {
                        Label(option.rawValue, systemImage: option.systemImage)
                        if viewModel.filterState.selectedSortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            Divider()
            
            // Filter Section
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
            
            // Darstellung Section
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
            
            // Statistik Section
            Section("Library") {
                if viewModel.filterState.showSeriesGrouped {
                    let seriesCount = viewModel.filteredAndSortedBooks.filter { $0.isCollapsedSeries }.count
                    let booksCount = viewModel.filteredAndSortedBooks.filter { !$0.isCollapsedSeries }.count
                    
                    HStack {
                        Text("Total: \(seriesCount) Series • \(booksCount) Books")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    HStack {
                        Text("Total: \(viewModel.totalBooksCount) Books")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            
            // Reset Section (nur wenn Filter aktiv)
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
                
                // Badge wenn Filter aktiv
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
