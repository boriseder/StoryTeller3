import Foundation

/// Use Case for fetching library statistics
/// Replaces direct api.libraries.fetchLibraryStats calls
protocol FetchLibraryStatsUseCaseProtocol {
    func execute(libraryId: String) async throws -> Int
}

class FetchLibraryStatsUseCase: FetchLibraryStatsUseCaseProtocol {
    private let api: AudiobookshelfClient
    
    init(api: AudiobookshelfClient) {
        self.api = api
    }
    
    func execute(libraryId: String) async throws -> Int {
        return try await api.libraries.fetchLibraryStats(libraryId: libraryId)
    }
}
