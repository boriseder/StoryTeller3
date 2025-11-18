
// MARK: - PlaybackSession Models
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

struct AudioTrack: Codable {
    let index: Int
    let startOffset: Double
    let duration: Double
    let title: String?
    let contentUrl: String?
    let mimeType: String?
    let filename: String?
}
