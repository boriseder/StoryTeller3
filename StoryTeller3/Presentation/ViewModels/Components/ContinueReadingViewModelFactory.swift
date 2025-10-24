import Foundation

struct ContinueReadingViewModelFactory {
    @MainActor static func create(api: AudiobookshelfAPI) -> ContinueReadingViewModel {
        let playbackRepository = PlaybackRepository()
        let syncProgressUseCase = SyncProgressUseCase(
            playbackRepository: playbackRepository,
            api: api
        )
        
        return ContinueReadingViewModel(syncProgressUseCase: syncProgressUseCase)
    }
}
