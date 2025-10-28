import Foundation

struct PlayerViewModelFactory {
    @MainActor
    static func create(container: DependencyContainer) -> PlayerViewModel {
        PlayerViewModel(
            player: container.audioPlayer,
            api: container.audiobookshelfClient
        )
    }
}
