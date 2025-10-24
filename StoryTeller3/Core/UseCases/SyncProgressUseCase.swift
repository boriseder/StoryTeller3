import Foundation

protocol SyncProgressUseCaseProtocol {
    func execute() async throws
}

class SyncProgressUseCase: SyncProgressUseCaseProtocol {
    private let playbackRepository: PlaybackRepositoryProtocol
    private let api: AudiobookshelfClient
    
    init(
        playbackRepository: PlaybackRepositoryProtocol,
        api: AudiobookshelfClient
    ) {
        self.playbackRepository = playbackRepository
        self.api = api
    }
    
    func execute() async throws {
        try await playbackRepository.syncPlaybackProgress(to: api)
    }
}
