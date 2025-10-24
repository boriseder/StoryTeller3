import Foundation
import AVFoundation

protocol AudioFileService {
    func getLocalAudioURL(bookId: String, chapterIndex: Int) -> URL?
    func getStreamingAudioURL(baseURL: String, audioTrack: PlaybackSessionResponse.AudioTrack) -> URL?
    func createAuthenticatedAsset(url: URL, authToken: String) -> AVURLAsset
    func getLocalCoverURL(bookId: String) -> URL?
}

class DefaultAudioFileService: AudioFileService {
    private let downloadManager: DownloadManager?
    
    init(downloadManager: DownloadManager?) {
        self.downloadManager = downloadManager
    }
    
    func getLocalAudioURL(bookId: String, chapterIndex: Int) -> URL? {
        return downloadManager?.getLocalAudioURL(for: bookId, chapterIndex: chapterIndex)
    }
    
    func getStreamingAudioURL(baseURL: String, audioTrack: PlaybackSessionResponse.AudioTrack) -> URL? {
        let fullURL = "\(baseURL)\(audioTrack.contentUrl)"
        return URL(string: fullURL)
    }
    
    func createAuthenticatedAsset(url: URL, authToken: String) -> AVURLAsset {
        let headers = [
            "Authorization": "Bearer \(authToken)",
            "User-Agent": "AudioBook Client/1.0.0"
        ]
        
        return AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": headers
        ])
    }
    
    func getLocalCoverURL(bookId: String) -> URL? {
        return downloadManager?.getLocalCoverURL(for: bookId)
    }
}
