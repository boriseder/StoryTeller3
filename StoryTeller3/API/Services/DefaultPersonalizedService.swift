import Foundation

class DefaultPersonalizedService: PersonalizedServiceProtocol {
    private let config: APIConfig
    private let networkService: NetworkService
    
    init(config: APIConfig, networkService: NetworkService) {
        self.config = config
        self.networkService = networkService
    }
    
    func fetchPersonalizedSections(libraryId: String, limit: Int = 10) async throws -> [PersonalizedSection] {
        var components = URLComponents(string: "\(config.baseURL)/api/libraries/\(libraryId)/personalized")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        guard let url = components.url else {
            throw AudiobookshelfError.invalidURL("\(config.baseURL)/api/libraries/\(libraryId)/personalized")
        }
        
        AppLogger.general.debug("[PersonalizedService] Fetching personalized sections from: \(url)")
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: config.authToken)
        
        do {
            let personalizedSections: PersonalizedResponse = try await networkService.performRequest(
                request,
                responseType: PersonalizedResponse.self
            )
            
            AppLogger.general.debug("[PersonalizedService] Received \(personalizedSections.count) personalized sections")
            
            for section in personalizedSections {
                AppLogger.general.debug("[PersonalizedService] Section: \(section.id) (\(section.type)) - \(section.entities.count) items")
            }
            
            return personalizedSections
            
        } catch {
            AppLogger.general.debug("[PersonalizedService] fetchPersonalizedSections error: \(error)")
            throw error
        }
    }
}
