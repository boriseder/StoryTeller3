//
//  Enhanced PersonalizedModels.swift
//  StoryTeller3
//

import Foundation

// MARK: - Personalized Response Models

struct PersonalizedSection: Codable, Identifiable {
    let id: String
    let label: String
    let labelStringKey: String?
    let type: String
    let entities: [PersonalizedEntity]
    let total: Int
}

typealias PersonalizedResponse = [PersonalizedSection]

// MARK: - Enhanced PersonalizedEntity
struct PersonalizedEntity: Codable, Identifiable {
    let id: String
    let media: Media?                    // For books
    let libraryId: String?
    let collapsedSeries: CollapsedSeries?
    
    // Series-specific properties
    let name: String?                    // For series
    let nameIgnorePrefix: String?        // For series
    let books: [LibraryItem]?           // For series
    let addedAt: TimeInterval?          // For series
    
    // Author-specific properties (if applicable)
    let numBooks: Int?                  // For authors
    
    private enum CodingKeys: String, CodingKey {
        case id, media, libraryId, collapsedSeries
        case name, nameIgnorePrefix, books, addedAt, numBooks
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        media = try container.decodeIfPresent(Media.self, forKey: .media)
        libraryId = try container.decodeIfPresent(String.self, forKey: .libraryId)
        collapsedSeries = try container.decodeIfPresent(CollapsedSeries.self, forKey: .collapsedSeries)
        
        // Series properties
        name = try container.decodeIfPresent(String.self, forKey: .name)
        nameIgnorePrefix = try container.decodeIfPresent(String.self, forKey: .nameIgnorePrefix)
        books = try container.decodeIfPresent([LibraryItem].self, forKey: .books)
        addedAt = try container.decodeIfPresent(TimeInterval.self, forKey: .addedAt)
        
        // Author properties
        numBooks = try container.decodeIfPresent(Int.self, forKey: .numBooks)
    }
    
    // MARK: - Convenience Properties
    
    var asLibraryItem: LibraryItem? {
        guard let media = media else { return nil }
        return LibraryItem(
            id: id,
            media: media,
            libraryId: libraryId,
            isFile: nil,
            isMissing: nil,
            isInvalid: nil,
            coverPath: nil,
            collapsedSeries: collapsedSeries
        )
    }
    
    var asSeries: Series? {
        guard let name = name,
              let books = books else { return nil }
        
        return Series(
            id: id,
            name: name,
            nameIgnorePrefix: nameIgnorePrefix,
            nameIgnorePrefixSort: nil,
            books: books,
            addedAt: addedAt ?? Date().timeIntervalSince1970
        )
    }
    
    var asAuthor: Author? {
        guard let name = name else { return nil }
        
        return Author(
            id: id,
            name: name,
            numBooks: numBooks ?? 0
        )
    }
    
    // Determine entity type based on available properties
    var entityType: PersonalizedEntityType {
        if media != nil {
            return .book
        } else if books != nil {
            return .series
        } else if numBooks != nil {
            return .author
        } else {
            return .unknown
        }
    }
}

// MARK: - Entity Type Enum
enum PersonalizedEntityType {
    case book
    case series
    case author
    case unknown
}

// MARK: - Author Model
struct Author: Identifiable, Decodable {
    let id: String
    let name: String
    let numBooks: Int
    
    init(id: String, name: String, numBooks: Int) {
        self.id = id
        self.name = name
        self.numBooks = numBooks
    }
}

// MARK: - Personalized Section Types
enum PersonalizedSectionType: String, CaseIterable {
    case recentlyAdded = "recently-added"
    case recentSeries = "recent-series"
    case discover = "discover"
    case newestAuthors = "newest-authors"
    case continueListening = "continue-listening"
    case recentlyFinished = "recently-finished"
    
    var displayName: String {
        switch self {
        case .recentlyAdded:
            return "Recently Added"
        case .recentSeries:
            return "Recent Series"
        case .discover:
            return "Discover"
        case .newestAuthors:
            return "New Authors"
        case .continueListening:
            return "Continue Listening"
        case .recentlyFinished:
            return "Recently Finished"
        }
    }
    
    var icon: String {
        switch self {
        case .recentlyAdded:
            return "clock.fill"
        case .recentSeries:
            return "rectangle.stack.fill"
        case .discover:
            return "sparkles"
        case .newestAuthors:
            return "person.2.fill"
        case .continueListening:
            return "play.circle.fill"
        case .recentlyFinished:
            return "checkmark.circle.fill"
        }
    }
    
    var expectedEntityType: PersonalizedEntityType {
        switch self {
        case .recentlyAdded, .discover, .continueListening, .recentlyFinished:
            return .book
        case .recentSeries:
            return .series
        case .newestAuthors:
            return .author
        }
    }
}
