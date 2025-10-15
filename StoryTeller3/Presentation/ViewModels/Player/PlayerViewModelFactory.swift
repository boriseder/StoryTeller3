import Foundation

struct PlayerViewModelFactory {
    @MainActor
    static func create(
        player: AudioPlayer,
        api: AudiobookshelfAPI
    ) -> PlayerViewModel {
        return PlayerViewModel(player: player, api: api)
    }
}
