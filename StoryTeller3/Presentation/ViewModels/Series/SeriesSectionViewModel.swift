import SwiftUI

@MainActor
class SeriesSectionViewModel: ObservableObject {
    let series: Series
    let onBookSelected: () -> Void
    
    private let playBookUseCase: PlayBookUseCaseProtocol
    private let convertLibraryItemUseCase: ConvertLibraryItemUseCaseProtocol
    
    var books: [Book] {
        series.books.compactMap { convertLibraryItemUseCase.execute(item: $0) }
    }
    
    init(
        series: Series,
        playBookUseCase: PlayBookUseCaseProtocol,
        convertLibraryItemUseCase: ConvertLibraryItemUseCaseProtocol,
        onBookSelected: @escaping () -> Void
    ) {
        self.series = series
        self.playBookUseCase = playBookUseCase
        self.convertLibraryItemUseCase = convertLibraryItemUseCase
        self.onBookSelected = onBookSelected
    }
    
    func playBook(_ book: Book, appState: AppStateManager) async {
        do {
            try await playBookUseCase.execute(
                book: book,
                appState: appState,
                restoreState: true
            )
            onBookSelected()
        } catch {
            AppLogger.general.debug("[SeriesSectionViewModel] Failed to play book: \(error)")
        }
    }
}
