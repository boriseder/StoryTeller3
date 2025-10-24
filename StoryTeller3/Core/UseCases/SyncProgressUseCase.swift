import Foundation

protocol SyncProgressUseCaseProtocol {
    func execute() async throws
}

class SyncProgressUseCase: SyncProgressUseCaseProtocol {
    private let playbackRepository: PlaybackRepositoryProtocol
    private let api: AudiobookshelfAPI
    
    init(
        playbackRepository: PlaybackRepositoryProtocol,
        api: AudiobookshelfAPI
    ) {
        self.playbackRepository = playbackRepository
        self.api = api
    }
    
    func execute() async throws {
        try await playbackRepository.syncPlaybackProgress(to: api)
    }
}
