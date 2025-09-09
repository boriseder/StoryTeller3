import Foundation

// MARK: - Library
struct LibrariesResponse: Codable {
    let libraries: [Library]
}

struct LibraryItemsResponse: Decodable {
    let results: [LibraryItem]
    let total: Int?
    let limit: Int?
    let page: Int?
}

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




