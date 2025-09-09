import Foundation

struct Media: Decodable {
    let metadata: Metadata
    let chapters: [Chapter]?
    let duration: Double?
    let size: Int64?
    let tracks: [AudioTrack]?
}
