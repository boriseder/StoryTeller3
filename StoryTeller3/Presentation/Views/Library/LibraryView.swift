import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel: LibraryViewModel = DependencyContainer.shared.libraryViewModel
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var theme: ThemeManager
    
    @State private var selectedSeries: Book?
    @State private var bookCardVMs: [BookCardStateViewModel] = []
    
    // Workaround to hide nodata at start of app
    @State private var showEmptyState = false
    
    var body: some View {
        ZStack {
            
            if theme.backgroundStyle == .dynamic {
                Color.accent.ignoresSafeArea()
            }
            
            ZStack {
                switch viewModel.uiState {
                    
                case .content, .loading, .loadingFromCache:
                    contentView
                        .transition(.opacity)

                case .offline(let cachedItemCount):
                    if cachedItemCount > 0 {
                        contentView
                    } else {
                        ErrorView(error: "No cached data available. Please connect to the internet.")
                            .transition(.opacity)
                    }
/*
                case .error(let message):
                    ErrorView(error: message)
                        .transition(.opacity)
*/
                case .empty:
                    if showEmptyState {
                        EmptyStateView()
                            .transition(.opacity)
                    }

                case .noDownloads:
                    NoDownloadsView()
                        .transition(.opacity)
                
                case .noSearchResults:
                    NoSearchResultsView()
                        .transition(.opacity)

                }
            }
            .onChange(of: viewModel.uiState) {
                if viewModel.uiState == .empty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak viewModel] in
                        guard viewModel?.uiState == .empty else { return }
                        withAnimation { showEmptyState = true }
                    }
                } else {
                    showEmptyState = false
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.uiState)

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
        .alert("Error", isPresented: $viewModel.showingErrorAlert) {
            Button("OK") {
                appState.selectedTab = .downloads
            }
            Button("Reconnect") {
                Task {
                    guard let baseURL = UserDefaults.standard.string(forKey: "baseURL") else { return }
                    let useCase = TestConnectionUseCase(connectionHealthChecker: ConnectionHealthChecker())
                    let isConnected = await useCase.execute(baseURL: baseURL)
                    
                    await MainActor.run {
                        appState.isDeviceOnline = isConnected
                        if isConnected {
                            viewModel.showingErrorAlert = false
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("""
            \(viewModel.errorMessage ?? "Unknown Error")
            
            Do you want to change to your downloaded books?
            """)
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
                onBookSelected: viewModel.onBookSelected
            )
            .environmentObject(appState)
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
                
                offlineBanner
                
                LazyVGrid(columns: DSGridColumns.two, spacing: 0) {
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
                    .padding(.vertical, DSLayout.contentPadding)
                }

                Spacer()
                    .frame(height: DSLayout.miniPlayerHeight)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, DSLayout.screenPadding)

        }
        .opacity(viewModel.contentLoaded ? 1 : 0)
        .animation(.easeInOut(duration: 0.5), value: viewModel.contentLoaded)
        .animation(.easeInOut(duration: 0.3), value: viewModel.uiState)
        .onAppear { viewModel.contentLoaded = true }
    }
    
    // MARK: - Ultra-Optimized Update Logic
    
    private func updateBookCardViewModels() {
        let books = viewModel.filteredAndSortedBooks
        
        Task { @MainActor in
            let newVMs = books.map { book in
                BookCardStateViewModel(book: book)
            }
            self.bookCardVMs = newVMs
        }
    }
    
    private func updateCurrentBookOnly() {
        guard let currentBookId = viewModel.player.book?.id,
              let index = bookCardVMs.firstIndex(where: { $0.id == currentBookId }) else {
            return
        }
        
        bookCardVMs[index] = BookCardStateViewModel(book: bookCardVMs[index].book)
    }
    
    private func updateDownloadingBooksOnly() {
        let downloadingIds = Set(viewModel.downloadManager.downloadProgress.keys)
        
        for (index, vm) in bookCardVMs.enumerated() {
            if downloadingIds.contains(vm.id) {
                bookCardVMs[index] = BookCardStateViewModel(book: vm.book)
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
            // MARK: - Sort Section
            Section("SORTING") {
                ForEach(LibrarySortOption.allCases) { option in
                    Button {
                        viewModel.filterState.selectedSortOption = option
                        viewModel.filterState.saveToDefaults()
                    } label: {
                        if viewModel.filterState.selectedSortOption == option {
                            Label(option.rawValue, systemImage: "checkmark")
                        } else {
                            Text(option.rawValue)
                        }
                    }
                }
                
                Button {
                    viewModel.filterState.sortAscending.toggle()
                    viewModel.filterState.saveToDefaults()
                } label: {
                    // Zeigt aktuelle Richtung mit Icon UND Text
                    Label(
                        viewModel.filterState.sortAscending ? "Ascending" : "Descending",
                        systemImage: viewModel.filterState.sortAscending ? "arrow.up" : "arrow.down"
                    )
                }
            }
            
            Divider()
            
            // MARK: - Filter Section
            Section("FILTER") {
                Button {
                    viewModel.toggleDownloadFilter()
                } label: {
                    if viewModel.filterState.showDownloadedOnly {
                        Label("Show all books", systemImage: "books.vertical")
                    } else {
                        Label("Downloaded only", systemImage: "arrow.down.circle")
                    }
                }
                
                if viewModel.downloadedBooksCount > 0 {
                    Text("\(viewModel.downloadedBooksCount) downloaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // MARK: - View Section
            Section("VIEW") {
                Button {
                    viewModel.toggleSeriesMode()
                } label: {
                    // Filled icon = ON, outline = OFF
                    Label(
                        "Group series",
                        systemImage: viewModel.filterState.showSeriesGrouped
                        ? "square.stack.3d.up.fill"
                        : "square.stack.3d.up"
                    )
                }
            }
            
            // MARK: - Reset Section
            if viewModel.filterState.hasActiveFilters {
                Divider()
                
                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.resetFilters()
                    }
                } label: {
                    Label("Reset all filters", systemImage: "arrow.counterclockwise")
                }
            }
            
        } label: {
            // MARK: - Toolbar Icon mit Badge
            ZStack {
                // Background circle
                Circle()
                    .fill(viewModel.filterState.hasActiveFilters
                          ? Color.accentColor.opacity(0.15)
                          : Color.clear)
                    .frame(width: 32, height: 32)
                
                // Main icon
                Image(systemName: viewModel.filterState.hasActiveFilters
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(viewModel.filterState.hasActiveFilters
                                 ? .accentColor
                                 : .primary)
                
                // Badge indicator
                if viewModel.filterState.hasActiveFilters {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                        .offset(x: 10, y: -10)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.filterState.hasActiveFilters)
        }
    }
    
    private var offlineBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.body)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline Mode")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if case .cache(let timestamp) = viewModel.dataSource {
                    Text("Last updated \(formatTimestamp(timestamp))")
                        .font(.caption)
                        .opacity(0.8)
                }
            }
            
            Spacer()
            
            Divider()
                .frame(height: 40)

            // Third section
            Button {
                appState.isDeviceOnline.toggle()
                appState.isServerReachable.toggle()
            } label: {
                Image(systemName: appState.isDeviceOnline ? "icloud" : "icloud.slash")
                    .font(DSText.button)
                    .foregroundColor(appState.isDeviceOnline ? Color.green : Color.red)
                    .padding(DSLayout.tightPadding)
                    .background(appState.isDeviceOnline ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(.horizontal, DSLayout.elementPadding)

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.9))
        .foregroundColor(.white)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
            
            Text("Show \(count) of \(totalDownloaded) downloaded books")
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
                Text("\(seriesCount) Series • \(booksCount) Books")
            } else {
                Text("\(viewModel.totalBooksCount) Books")
            }
        }
    }
}
