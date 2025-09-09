import Foundation

// MARK: Book
struct Book: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let author: String?
    let chapters: [Chapter]
    let coverPath: String?
    
    static func == (lhs: Book, rhs: Book) -> Bool { lhs.id == rhs.id }
    
    func coverURL(baseURL: String) -> URL? {
        guard let coverPath = coverPath else { return nil }
        return URL(string: "\(baseURL)\(coverPath)")
    }
}
