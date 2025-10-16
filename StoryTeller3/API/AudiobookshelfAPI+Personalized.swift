//
//  Updated AudiobookshelfAPI+Personalized.swift
//  StoryTeller3
//

import Foundation

extension AudiobookshelfAPI {
    
    /// Fetch all personalized sections with detailed breakdown
    func fetchPersonalizedSections(from libraryId: String) async throws -> [PersonalizedSection] {
        var components = URLComponents(string: "\(baseURLString)/api/libraries/\(libraryId)/personalized")!
        
        // Don't limit the number of items - we want all sections
        components.queryItems = [
            URLQueryItem(name: "limit", value: "10") // Reasonable limit per section
        ]
        
        guard let url = components.url else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/libraries/\(libraryId)/personalized")
        }
        
        AppLogger.general.debug("[AudiobookshelfAPI] Fetching all personalized sections from: \(url)")
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        
        do {
            let personalizedSections: PersonalizedResponse = try await networkService.performRequest(
                request,
                responseType: PersonalizedResponse.self
            )
            
            AppLogger.general.debug("[AudiobookshelfAPI] Received \(personalizedSections.count) personalized sections")
            
            // Log section details for debugging
            for section in personalizedSections {
                AppLogger.general.debug("[AudiobookshelfAPI] Section: \(section.id) (\(section.type)) - \(section.entities.count) items")
            }
            
            return personalizedSections
            
        } catch {
            AppLogger.general.debug("[AudiobookshelfAPI] fetchPersonalizedSections error: \(error)")
            throw error
        }
    }

}
