import SwiftUI

@MainActor
class SeriesViewModel: ObservableObject {
    // MARK: - Published UI State
    @Published var series: [Series] = []
    @Published var filterState = SeriesFilterState()
    @Published var libraryName: String = "Serien"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    @Published var contentLoaded = false

    // MARK: - Dependencies (Use Cases & Repositories ONLY)
    private let fetchSeriesUseCase: FetchSeriesUseCaseProtocol
    private let playBookUseCase: PlayBookUseCaseProtocol
    private let convertLibraryItemUseCase: ConvertLibraryItemUseCaseProtocol
    private let downloadRepository: DownloadRepository
    private let libraryRepository: LibraryRepositoryProtocol
    private let onBookSelected: () -> Void
    
    // MARK: - Computed Properties for UI
    var filteredAndSortedSeries: [Series] {
        let filtered = series.filter { filterState.matchesSearchFilter($0) }
        return filterState.applySorting(to: filtered)
    }
    
    // MARK: - Init with DI
    init(
        fetchSeriesUseCase: FetchSeriesUseCaseProtocol,
        playBookUseCase: PlayBookUseCaseProtocol,
        convertLibraryItemUseCase: ConvertLibraryItemUseCaseProtocol,
        downloadRepository: DownloadRepository,
        libraryRepository: LibraryRepositoryProtocol,
        onBookSelected: @escaping () -> Void
    ) {
        self.fetchSeriesUseCase = fetchSeriesUseCase
        self.playBookUseCase = playBookUseCase
        self.convertLibraryItemUseCase = convertLibraryItemUseCase
        self.downloadRepository = downloadRepository
        self.libraryRepository = libraryRepository
        self.onBookSelected = onBookSelected
    }
    
    // MARK: - Actions
    func loadSeriesIfNeeded() async {
        if series.isEmpty {
            await loadSeries()
        }
    }
    
    func loadSeries() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let selectedLibrary = try await libraryRepository.getSelectedLibrary() else {
                libraryName = "Serien"
                series = []
                isLoading = false
                return
            }

            libraryName = "Series"

            let fetchedSeries = try await fetchSeriesUseCase.execute(
                libraryId: selectedLibrary.id
            )
            
            withAnimation(.easeInOut) {
                series = fetchedSeries
            }
            
        } catch let error as RepositoryError {
            handleRepositoryError(error)
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
        
        isLoading = false
    }
    
    func playBook(_ book: Book, appState: AppStateManager, restoreState: Bool = true) async {
        isLoading = true
        
        do {
            try await playBookUseCase.execute(
                book: book,
                appState: appState,
                restoreState: restoreState
            )
            onBookSelected()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
        
        isLoading = false
    }
    
    func convertLibraryItemToBook(_ item: LibraryItem) -> Book? {
        return convertLibraryItemUseCase.execute(item: item)
    }
    
    // MARK: - Error Handling
    private func handleRepositoryError(_ error: RepositoryError) {
        errorMessage = error.localizedDescription
        showingErrorAlert = true
        AppLogger.general.debug("[SeriesViewModel] Repository error: \(error)")
    }
}
