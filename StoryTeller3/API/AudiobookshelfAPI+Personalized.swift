//
//  AudiobookshelfAPI+Personalized.swift
//  StoryTeller3
//
//  Created by Assistant on 10.09.25
//

import Foundation

extension AudiobookshelfAPI {
    
    /// Fetch personalized book recommendations from a library
    func fetchPersonalizedBooks(from libraryId: String) async throws -> [Book] {
        var components = URLComponents(string: "\(baseURLString)/api/libraries/\(libraryId)/personalized")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "5"),
            URLQueryItem(name: "type", value: "book") // wir wollen nur book-Sections
        ]
        
        guard let url = components.url else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/libraries/\(libraryId)/personalized?")
        }
        
        AppLogger.debug.debug("Fetching personalized books from: \(url)")
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        
        do {
            let personalizedSections: PersonalizedResponse = try await networkService.performRequest(
                request,
                responseType: PersonalizedResponse.self
            )
            
            AppLogger.debug.debug("Received \(personalizedSections.count) sections")
            
            // ✅ Sammle alle Books aus Sections vom Typ "book"
            var allBooks: [Book] = []
            
            for section in personalizedSections where section.type == "book" {
                let sectionBooks = section.entities
                    .compactMap { $0.asLibraryItem }         // filtert nil automatisch raus
                    .compactMap { convertLibraryItemToBook($0) }
                
                allBooks.append(contentsOf: sectionBooks)
            }
            
            
            
            return allBooks
            
        } catch {
            AppLogger.debug.debug("❌ fetchPersonalizedBooks error: \(error)")
            throw error
        }
    }
    
    /// Fetch personalized sections with detailed breakdown
    func fetchPersonalizedSections(from libraryId: String) async throws -> [PersonalizedSection] {
        guard let url = URL(string: "\(baseURLString)/api/libraries/\(libraryId)/personalized") else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/libraries/\(libraryId)/personalized")
        }
        
        AppLogger.debug.debug("Fetching personalized sections from: \(url)")
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AudiobookshelfError.noData
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                throw AudiobookshelfError.unauthorized
            case 404:
                throw AudiobookshelfError.noData
            default:
                let errorMessage = String(data: data, encoding: .utf8)
                throw AudiobookshelfError.serverError(httpResponse.statusCode, errorMessage)
            }
            
            let personalizedSections: PersonalizedResponse = try JSONDecoder().decode(PersonalizedResponse.self, from: data)
            
            AppLogger.debug.debug("Received \(personalizedSections.count) personalized sections")
            
            return personalizedSections
            
        } catch let decodingError as DecodingError {
            AppLogger.debug.debug("Decoding error for personalized sections: \(decodingError)")
            throw AudiobookshelfError.decodingError(decodingError)
        } catch {
            AppLogger.debug.debug("Error fetching personalized sections: \(error)")
            throw error
        }
    }
}
