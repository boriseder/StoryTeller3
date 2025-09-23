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
        var components = URLComponents(string: "\(baseURLString)/api/libraries/\(libraryId)/personalized")!
        
        // Don't limit the number of items - we want all sections
        components.queryItems = [
            URLQueryItem(name: "limit", value: "10") // Reasonable limit per section
        ]
        
        guard let url = components.url else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/libraries/\(libraryId)/personalized")
        }
        
        AppLogger.debug.debug("Fetching all personalized sections from: \(url)")
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        
        do {
            let personalizedSections: PersonalizedResponse = try await networkService.performRequest(
                request,
                responseType: PersonalizedResponse.self
            )
            
            AppLogger.debug.debug("Received \(personalizedSections.count) personalized sections")
            
            // Log section details for debugging
            for section in personalizedSections {
                AppLogger.debug.debug("Section: \(section.id) (\(section.type)) - \(section.entities.count) items")
            }
            
            return personalizedSections
            
        } catch {
            AppLogger.debug.debug("❌ fetchPersonalizedSections error: \(error)")
            throw error
        }
    }
    
    func fetchPersonalizedSection(
        from libraryId: String,
        sectionType: PersonalizedSectionType,
        limit: Int = 10
    ) async throws -> PersonalizedSection? {
        let allSections = try await fetchPersonalizedSections(from: libraryId)
        return allSections.first { $0.id == sectionType.rawValue }
    }
    
    /// Get books to continue listening
    func fetchContinueListening(from libraryId: String) async throws -> [Book] {
        guard let section = try await fetchPersonalizedSection(
            from: libraryId,
            sectionType: .continueListening
        ) else {
            return []
        }
        
        return section.entities
            .compactMap { $0.asLibraryItem }
            .compactMap { convertLibraryItemToBook($0) }
    }
    
    /// Get recently added books
    func fetchRecentlyAdded(from libraryId: String) async throws -> [Book] {
        guard let section = try await fetchPersonalizedSection(
            from: libraryId,
            sectionType: .recentlyAdded
        ) else {
            return []
        }
        
        return section.entities
            .compactMap { $0.asLibraryItem }
            .compactMap { convertLibraryItemToBook($0) }
    }
    
    /// Get recent series
    func fetchRecentSeries(from libraryId: String) async throws -> [Series] {
        guard let section = try await fetchPersonalizedSection(
            from: libraryId,
            sectionType: .recentSeries
        ) else {
            return []
        }
        
        return section.entities.compactMap { $0.asSeries }
    }

}


/*
 /// Fetch personalized book recommendations from a library (DEPRECATED - use fetchPersonalizedSections)
 func fetchPersonalizedBooks(from libraryId: String) async throws -> [Book] {
     let sections = try await fetchPersonalizedSections(from: libraryId)
     
     // Extract all books from book-type sections
     var allBooks: [Book] = []
     
     for section in sections where section.type == "book" {
         let sectionBooks = section.entities
             .compactMap { $0.asLibraryItem }
             .compactMap { convertLibraryItemToBook($0) }
         
         allBooks.append(contentsOf: sectionBooks)
     }
     
     return allBooks
 }
 
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
     
     AppLogger.debug.debug("Fetching all personalized sections from: \(url)")
     
     let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
     
     do {
         let personalizedSections: PersonalizedResponse = try await networkService.performRequest(
             request,
             responseType: PersonalizedResponse.self
         )
         
         AppLogger.debug.debug("Received \(personalizedSections.count) personalized sections")
         
         // Log section details for debugging
         for section in personalizedSections {
             AppLogger.debug.debug("Section: \(section.id) (\(section.type)) - \(section.entities.count) items")
         }
         
         return personalizedSections
         
     } catch {
         AppLogger.debug.debug("❌ fetchPersonalizedSections error: \(error)")
         throw error
     }
 }
 
 /// Fetch specific section type from personalized endpoint
 func fetchPersonalizedSection(
     from libraryId: String,
     sectionType: PersonalizedSectionType,
     limit: Int = 10
 ) async throws -> PersonalizedSection? {
     let allSections = try await fetchPersonalizedSections(from: libraryId)
     return allSections.first { $0.id == sectionType.rawValue }
 }
 
 /// Get books to continue listening
 func fetchContinueListening(from libraryId: String) async throws -> [Book] {
     guard let section = try await fetchPersonalizedSection(
         from: libraryId,
         sectionType: .continueListening
     ) else {
         return []
     }
     
     return section.entities
         .compactMap { $0.asLibraryItem }
         .compactMap { convertLibraryItemToBook($0) }
 }
 
 /// Get recently added books
 func fetchRecentlyAdded(from libraryId: String) async throws -> [Book] {
     guard let section = try await fetchPersonalizedSection(
         from: libraryId,
         sectionType: .recentlyAdded
     ) else {
         return []
     }
     
     return section.entities
         .compactMap { $0.asLibraryItem }
         .compactMap { convertLibraryItemToBook($0) }
 }
 
 /// Get recent series
 func fetchRecentSeries(from libraryId: String) async throws -> [Series] {
     guard let section = try await fetchPersonalizedSection(
         from: libraryId,
         sectionType: .recentSeries
     ) else {
         return []
     }
     
     return section.entities.compactMap { $0.asSeries }
 }

 */
