//
//  DownloadNetworkService.swift
//  StoryTeller3
//
//  Created by Boris Eder on 24.10.25.
//


import Foundation

/// Service responsible for network operations related to downloads
protocol DownloadNetworkService {
    /// Downloads a file from a URL with authentication
    /// - Parameters:
    ///   - url: The URL to download from
    ///   - authToken: Authentication token
    /// - Returns: The downloaded data
    func downloadFile(from url: URL, authToken: String) async throws -> Data
    
    /// Creates a playback session for downloading audio files
    /// - Parameters:
    ///   - libraryItemId: The library item ID
    ///   - api: The AudiobookshelfAPI instance
    /// - Returns: PlaybackSessionResponse containing audio track URLs
    func createPlaybackSession(libraryItemId: String, api: AudiobookshelfClient) async throws -> PlaybackSessionResponse
}

final class DefaultDownloadNetworkService: DownloadNetworkService {
    
    // MARK: - Properties
    private let urlSession: URLSession
    private let timeout: TimeInterval
    
    // MARK: - Initialization
    init(urlSession: URLSession = .shared, timeout: TimeInterval = 300.0) {
        self.urlSession = urlSession
        self.timeout = timeout
    }
    
    // MARK: - DownloadNetworkService
    
    func downloadFile(from url: URL, authToken: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw DownloadError.httpError(statusCode: httpResponse.statusCode)
        }
        
        guard data.count > 1024 else {
            throw DownloadError.fileTooSmall
        }
        
        return data
    }
    
    func createPlaybackSession(libraryItemId: String, api: AudiobookshelfClient) async throws -> PlaybackSessionResponse {
        let url = URL(string: "\(api.baseURLString)/api/items/\(libraryItemId)/play")!
        let requestBody = DeviceUtils.createPlaybackRequest()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(api.authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 30.0
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AudiobookshelfError.invalidResponse
        }
        
        return try JSONDecoder().decode(PlaybackSessionResponse.self, from: data)
    }
}
