import Foundation

class DefaultProgressService: ProgressServiceProtocol {
    private let config: APIConfig
    private let networkService: NetworkService
    
    init(config: APIConfig, networkService: NetworkService) {
        self.config = config
        self.networkService = networkService
    }
    
    func updatePlaybackProgress(
        libraryItemId: String,
        currentTime: Double,
        timeListened: Double,
        duration: Double
    ) async throws {
        guard let url = URL(string: "\(config.baseURL)/api/me/progress/\(libraryItemId)/") else {
            throw AudiobookshelfError.invalidURL("\(config.baseURL)/api/session/\(libraryItemId)/")
        }
        
        let body: [String: Any] = [
            "currentTime": currentTime,
            "timeListened": timeListened,
            "duration": duration
        ]
        
        var request = networkService.createAuthenticatedRequest(url: url, authToken: config.authToken)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AudiobookshelfError.invalidRequest(error.localizedDescription)
        }
        
        AppLogger.general.debug("[ProgressService] Updating playback progress: \(libraryItemId), time: \(currentTime)s")
        
        let _: [String: String]? = try? await networkService.performRequest(request, responseType: [String: String].self)
    }
    
    func fetchPlaybackProgress(libraryItemId: String) async throws -> MediaProgress? {
        guard let url = URL(string: "\(config.baseURL)/api/me/progress/\(libraryItemId)") else {
            throw AudiobookshelfError.invalidURL("\(config.baseURL)/api/me/progress/\(libraryItemId)")
        }
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: config.authToken)
        
        AppLogger.general.debug("[ProgressService] Fetching progress for item: \(libraryItemId)")
        
        do {
            let progress: MediaProgress = try await networkService.performRequest(request, responseType: MediaProgress.self)
            return progress
        } catch AudiobookshelfError.resourceNotFound {
            AppLogger.general.debug("[ProgressService] No progress found for item: \(libraryItemId)")
            return nil
        }
    }
    
    func closeSession(
        sessionId: String,
        currentTime: Double,
        timeListened: Double
    ) async throws {
        guard let url = URL(string: "\(config.baseURL)/api/session/\(sessionId)/close") else {
            throw AudiobookshelfError.invalidURL("\(config.baseURL)/api/session/\(sessionId)/close)")
        }
        
        let body: [String: Any] = [
            "currentTime": currentTime,
            "timeListened": timeListened
        ]
        
        var request = networkService.createAuthenticatedRequest(url: url, authToken: config.authToken)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AudiobookshelfError.invalidRequest(error.localizedDescription)
        }
        
        AppLogger.general.debug("[ProgressService] Closing session: \(sessionId), final time: \(currentTime)s")
        
        let _: [String: String]? = try? await networkService.performRequest(request, responseType: [String: String].self)
    }
    
    func fetchItemsInProgress() async throws -> [MediaProgress] {
        guard let url = URL(string: "\(config.baseURL)/api/me/items-in-progress") else {
            throw AudiobookshelfError.invalidURL("\(config.baseURL)/api/me/items-in-progress")
        }
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: config.authToken)
        
        AppLogger.general.debug("[ProgressService] Fetching items in progress")
        
        struct ItemsInProgressResponse: Codable {
            let libraryItems: [MediaProgress]
        }
        
        let response: ItemsInProgressResponse = try await networkService.performRequest(request, responseType: ItemsInProgressResponse.self)
        return response.libraryItems
    }
}
