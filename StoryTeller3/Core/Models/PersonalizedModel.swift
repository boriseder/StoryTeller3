//
//  PersonalizedModels.swift
//  StoryTeller3
//
//  Created by Assistant on 10.09.25
//

import Foundation

// MARK: - Personalized Response Models

struct PersonalizedSection: Decodable, Identifiable {
    let id: String
    let label: String
    let labelStringKey: String?
    let type: String
    let entities: [PersonalizedEntity]
    let total: Int
}

typealias PersonalizedResponse = [PersonalizedSection]

// MARK: - Entity (nur Books relevant)
struct PersonalizedEntity: Decodable, Identifiable {
    let id: String
    let media: Media?        // optional, nur bei Büchern vorhanden
    let libraryId: String?
    let collapsedSeries: CollapsedSeries?
    
    // Convenience-Mapping
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
            return "Recently added"
        case .recentSeries:
            return "Series"
        case .discover:
            return "Explore"
        case .newestAuthors:
            return "New authors"
        case .continueListening:
            return "Continue"
        case .recentlyFinished:
            return "Kürzlich beendet"
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
}

