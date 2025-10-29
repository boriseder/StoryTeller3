import Foundation

enum API {}

extension API {
    struct AudioTrack: Decodable {
        let title: String?
        let startOffset: Double
        let duration: Double
    }
}

