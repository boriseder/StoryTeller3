import Foundation

struct ContinueReadingViewModelFactory {
    @MainActor
    static func create(container: DependencyContainer) -> ContinueReadingViewModel {
        ContinueReadingViewModel(syncProgressUseCase: container.syncProgressUseCase)
    }
}
