import Foundation

// MARK: Metadata Repsonse
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
