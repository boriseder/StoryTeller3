import Foundation

protocol ProgressServiceProtocol {
    func updatePlaybackProgress(libraryItemId: String, currentTime: Double, timeListened: Double, duration: Double) async throws
    func fetchPlaybackProgress(libraryItemId: String) async throws -> MediaProgress?
    func fetchItemsInProgress() async throws -> [MediaProgress]
}
