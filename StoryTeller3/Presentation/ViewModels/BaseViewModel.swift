import SwiftUI

class BaseViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        isLoading = false
        showingErrorAlert = true
    }
    
    func resetError() {
        errorMessage = nil
        showingErrorAlert = false
    }
    
    // MARK: - Common Playback Method
    
    @MainActor
    func loadAndPlayBook(
        _ book: Book,
        api: AudiobookshelfAPI,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        appState: AppStateManager,
        restoreState: Bool = true,
        onSuccess: @escaping () -> Void
    ) async {
        isLoading = true
        errorMessage = nil
        
        let useCase = PlayBookUseCase()
        
        do {
            try await useCase.execute(
                book: book,
                api: api,
                player: player,
                downloadManager: downloadManager,
                appState: appState,
                restoreState: restoreState
            )
            onSuccess()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
}
