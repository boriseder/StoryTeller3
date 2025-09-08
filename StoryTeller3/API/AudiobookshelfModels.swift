import Foundation

// MARK: - API Response Models
struct Library: Codable, Identifiable {
    let id: String
    let name: String
    let mediaType: String?
    
    var isAudiobook: Bool { mediaType == "book" }
}

struct LibraryItem: Decodable, Identifiable {
    let id: String
    let media: Media
    let libraryId: String?
    let isFile: Bool?
    let isMissing: Bool?
    let isInvalid: Bool?
    let coverPath: String?
}

struct Media: Decodable {
    let metadata: Metadata
    let chapters: [Chapter]?
    let duration: Double?
    let size: Int64?
    let tracks: [AudioTrack]?
}

struct Metadata: Decodable {
    let title: String
    let author: String?
    let description: String?
    let isbn: String?
    let genres: [String]?
    let publishedYear: String?
    let narrator: String?
    let publisher: String?
    
    enum CodingKeys: String, CodingKey {
        case title, description, isbn, genres, publishedYear, narrator, publisher
        case authorName      // für Library-Listing
        case authors         // für Item-Detail
    }
    
    struct Author: Decodable {
        let name: String
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Pflichtfeld
        title = try container.decode(String.self, forKey: .title)

        // Optionale Felder
        description   = try container.decodeIfPresent(String.self, forKey: .description)
        isbn          = try container.decodeIfPresent(String.self, forKey: .isbn)
        genres        = try container.decodeIfPresent([String].self, forKey: .genres)
        publishedYear = try container.decodeIfPresent(String.self, forKey: .publishedYear)
        narrator      = try container.decodeIfPresent(String.self, forKey: .narrator)
        publisher     = try container.decodeIfPresent(String.self, forKey: .publisher)

        // 🔄 Autor flexibel auslesen
        if let authorName = try? container.decode(String.self, forKey: .authorName) {
            author = authorName
        } else if let authorObjects = try? container.decode([Author].self, forKey: .authors) {
            author = authorObjects.first?.name
        } else {
            author = nil
        }
    }
}







struct AudioTrack: Codable {
    let index: Int
    let startOffset: Double
    let duration: Double
    let title: String?
    let contentUrl: String?
    let mimeType: String?
    let filename: String?
}

// MARK: - API Response Wrappers
struct LibrariesResponse: Codable {
    let libraries: [Library]
}

struct LibraryItemsResponse: Decodable {
    let results: [LibraryItem]
    let total: Int?
    let limit: Int?
    let page: Int?
}

// MARK: - Player Session Models
struct PlaybackSessionRequest: Codable {
    let deviceInfo: DeviceInfo
    let supportedMimeTypes: [String]
    let mediaPlayer: String
    
    struct DeviceInfo: Codable {
        let clientVersion: String
        let deviceId: String?
        let clientName: String?
    }
}

struct PlaybackSessionResponse: Codable {
    let id: String
    let audioTracks: [AudioTrack]
    let duration: Double
    let mediaType: String
    let libraryItemId: String
    let episodeId: String?
    
    struct AudioTrack: Codable {
        let index: Int
        let startOffset: Double
        let duration: Double
        let title: String
        let contentUrl: String
        let mimeType: String
    }
}
