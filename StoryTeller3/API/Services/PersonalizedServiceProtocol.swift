import Foundation

protocol PersonalizedServiceProtocol {
    func fetchPersonalizedSections(libraryId: String, limit: Int) async throws -> [PersonalizedSection]
}
