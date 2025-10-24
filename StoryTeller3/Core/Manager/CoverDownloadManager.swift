//
//  CoverDownloadManager.swift
//  StoryTeller3
//
//  Created by Boris Eder on 03.10.25.
//


import SwiftUI

// MARK: - Cover Download Manager
actor CoverDownloadManager {
    static let shared = CoverDownloadManager()
    
    private var downloadTasks: [String: Task<UIImage?, Error>] = [:]
    
    private init() {}
    
    func downloadCover(for book: Book, api: AudiobookshelfClient) async throws -> UIImage? {
        let cacheKey = "online_\(book.id)"
        
        // Check if already downloading
        if let existingTask = downloadTasks[cacheKey] {
            return try await existingTask.value
        }
        
        // Create download task
        let task = Task<UIImage?, Error> {
            defer {
                Task {
                    self.removeTask(for: cacheKey)
                }
            }
            // SWIFT 6 FIX - Check if self exists before calling method
            return try await self.performDownload(for: book, api: api)
        }
        
        downloadTasks[cacheKey] = task
        
        do {
            let result = try await task.value
            return result
        } catch {
            self.removeTask(for: cacheKey)
            throw error
        }
    }
    
    private func removeTask(for cacheKey: String) {
        downloadTasks.removeValue(forKey: cacheKey)
    }
    
    private func performDownload(for book: Book, api: AudiobookshelfClient) async throws -> UIImage? {
        // Use the standard Audiobookshelf cover endpoint
        let coverURLString = "\(api.baseURLString)/api/items/\(book.id)/cover"
        guard let url = URL(string: coverURLString) else {
            throw CoverLoadingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(api.authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CoverLoadingError.downloadFailed
        }
        
        guard let image = UIImage(data: data) else {
            throw CoverLoadingError.invalidImageData
        }
        
        // Cache the downloaded image
        await MainActor.run {
            let cacheKey = "online_\(book.id)"
            CoverCacheManager.shared.setDiskCachedImage(image, for: cacheKey)
        }
        
        return image
    }
    
    func cancelDownload(for bookId: String) {
        let cacheKey = "online_\(bookId)"
        downloadTasks[cacheKey]?.cancel()
        downloadTasks.removeValue(forKey: cacheKey)
    }
    
    func cancelAllDownloads() {
        downloadTasks.values.forEach { $0.cancel() }
        downloadTasks.removeAll()
    }
    
    func shutdown() {
        // Cancel all running downloads
        downloadTasks.values.forEach { $0.cancel() }
        downloadTasks.removeAll()
        
        AppLogger.general.debug("CoverDownloadManager shutdown - cancelled all downloads")
    }
}
