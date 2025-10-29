import Foundation

struct ContinueReadingViewModelFactory {
    @MainActor static func create(
        api: AudiobookshelfClient,
        container: DependencyContainer? = nil
    ) -> ContinueReadingViewModel {
        let container = container ?? DependencyContainer.shared
        let syncProgressUseCase = container.makeSyncProgressUseCase(api: api)
        
        return ContinueReadingViewModel(syncProgressUseCase: syncProgressUseCase)
    }
}
