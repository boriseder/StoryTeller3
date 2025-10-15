import Foundation

protocol FetchSeriesBooksUseCaseProtocol {
    func execute(libraryId: String, seriesId: String) async throws -> [Book]
}

class FetchSeriesBooksUseCase: FetchSeriesBooksUseCaseProtocol {
    private let api: AudiobookshelfAPI
    
    init(api: AudiobookshelfAPI) {
        self.api = api
    }
    
    func execute(libraryId: String, seriesId: String) async throws -> [Book] {
        return try await api.fetchSeriesSingle(from: libraryId, seriesId: seriesId)
    }
}
