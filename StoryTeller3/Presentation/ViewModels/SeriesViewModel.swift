import SwiftUI

class SeriesViewModel: BaseViewModel {
    @Published var series: [Series] = []
    @Published var searchText = ""
    @Published var selectedSortOption: SeriesSortOption = .name
    @Published var libraryName: String = "Serien"
    
    // Dependencies
    private let fetchSeriesUseCase: FetchSeriesUseCaseProtocol
    private let downloadRepository: DownloadRepositoryProtocol
    private let libraryRepository: LibraryRepositoryProtocol
    let api: AudiobookshelfAPI
    let downloadManager: DownloadManager
    let player: AudioPlayer
    private let onBookSelected: () -> Void
    
    var filteredAndSortedSeries: [Series] {
        let filtered = searchText.isEmpty ? series : series.filter { series in
            series.name.localizedCaseInsensitiveContains(searchText) ||
            (series.author?.localizedCaseInsensitiveContains(searchText) ?? false)
        }

        return filtered.sorted { series1, series2 in
            switch selectedSortOption {
            case .name:
                return series1.name.localizedCompare(series2.name) == .orderedAscending
            case .recent:
                return series1.addedAt > series2.addedAt
            case .bookCount:
                return series1.bookCount > series2.bookCount
            case .duration:
                return series1.totalDuration > series2.totalDuration
            }
        }
    }
    
    // MARK: - Convenience initializer for backward compatibility
    convenience init(
        api: AudiobookshelfAPI,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) {
        let bookRepository = BookRepository(api: api, cache: BookCache())
        let fetchSeriesUseCase = FetchSeriesUseCase(bookRepository: bookRepository)
        let downloadRepository = DownloadRepository(downloadManager: downloadManager)
        let libraryRepository = LibraryRepository(api: api)
        
        self.init(
            fetchSeriesUseCase: fetchSeriesUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: api,
            downloadManager: downloadManager,
            player: player,
            onBookSelected: onBookSelected
        )
    }
    
    // MARK: - Main initializer with use cases
    init(
        fetchSeriesUseCase: FetchSeriesUseCaseProtocol,
        downloadRepository: DownloadRepositoryProtocol,
        libraryRepository: LibraryRepositoryProtocol,
        api: AudiobookshelfAPI,
        downloadManager: DownloadManager,
        player: AudioPlayer,
        onBookSelected: @escaping () -> Void
    ) {
        self.fetchSeriesUseCase = fetchSeriesUseCase
        self.downloadRepository = downloadRepository
        self.libraryRepository = libraryRepository
        self.api = api
        self.downloadManager = downloadManager
        self.player = player
        self.onBookSelected = onBookSelected
        super.init()
    }
    
    func loadSeriesIfNeeded() async {
        if series.isEmpty {
            await loadSeries()
        }
    }
    
    @MainActor
    func loadSeries() async {
        isLoading = true
        resetError()
        
        do {
            guard let selectedLibrary = try await libraryRepository.getSelectedLibrary() else {
                libraryName = "Serien"
                series = []
                isLoading = false
                return
            }

            libraryName = "\(selectedLibrary.name) - Serien"
            
            let fetchedSeries = try await fetchSeriesUseCase.execute(
                libraryId: selectedLibrary.id
            )
            
            withAnimation(.easeInOut) {
                series = fetchedSeries
            }
            
        } catch let error as RepositoryError {
            handleRepositoryError(error)
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func playBook(_ book: Book, appState: AppStateManager, restoreState: Bool = true) async {
        await loadAndPlayBook(
            book,
            api: api,
            player: player,
            downloadManager: downloadManager,
            appState: appState,
            restoreState: restoreState,
            onSuccess: onBookSelected
        )
    }
    
    func convertLibraryItemToBook(_ item: LibraryItem) -> Book? {
        return api.convertLibraryItemToBook(item)
    }
    
    // MARK: - Error Handling
    
    private func handleRepositoryError(_ error: RepositoryError) {
        errorMessage = error.localizedDescription
        showingErrorAlert = true
        AppLogger.debug.debug("[SeriesViewModel] Repository error: \(error)")
    }
}
