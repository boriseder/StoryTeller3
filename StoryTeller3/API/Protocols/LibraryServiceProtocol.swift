import Foundation

protocol LibraryServiceProtocol {
    func fetchLibraries() async throws -> [Library]
    func fetchLibraryStats(libraryId: String) async throws -> Int
}
