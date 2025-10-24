import Foundation

struct PlayerViewModelFactory {
    @MainActor
    static func create(
        player: AudioPlayer,
        api: AudiobookshelfClient
    ) -> PlayerViewModel {
        return PlayerViewModel(player: player, api: api)
    }
}
