import Foundation

protocol ProgressServiceProtocol {
    func syncSessionProgress(sessionId: String, currentTime: Double, timeListened: Double, duration: Double) async throws
    func fetchProgress(libraryItemId: String) async throws -> MediaProgress?
    func closeSession(sessionId: String, currentTime: Double, timeListened: Double) async throws
    func fetchItemsInProgress() async throws -> [MediaProgress]
}
