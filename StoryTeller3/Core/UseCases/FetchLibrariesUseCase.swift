import Foundation

protocol FetchLibrariesUseCaseProtocol {
    func execute(api: AudiobookshelfAPI) async throws -> [Library]
}

class FetchLibrariesUseCase: FetchLibrariesUseCaseProtocol {
    func execute(api: AudiobookshelfAPI) async throws -> [Library] {
        return try await api.fetchLibraries()
    }
}
