//
//  AdvancedSettingsViewModel.swift
//  StoryTeller3
//
//  Created by Boris Eder on 10.09.25.
//



import SwiftUI

@MainActor
class AdvancedSettingsViewModel: ObservableObject {
    @Published var appCacheSize: String = "Berechne..."
    @Published var coverCacheSize: String = "Berechne..."
    @Published var downloadedBooksCount: Int = 0
    @Published var totalDownloadSize: String = "Berechne..."
    @Published var enableDebugLogging = false
    @Published var connectionTimeout: Double = 30
    @Published var maxConcurrentDownloads: Int = 3
    @Published var coverCacheLimit: Int = 100
    @Published var memoryCacheSize: Int = 50

    @Published var showingClearAppCacheAlert = false
    @Published var showingClearCoverCacheAlert = false
    @Published var showingClearDownloadsAlert = false
    @Published var showingClearAllCacheAlert = false

    let downloadManager = DownloadManager()
    let coverCacheManager = CoverCacheManager.shared // jetzt public / internal

    func loadSettings() {
        connectionTimeout = UserDefaults.standard.double(forKey: "connection_timeout")
        if connectionTimeout == 0 { connectionTimeout = 30 }

        maxConcurrentDownloads = UserDefaults.standard.integer(forKey: "max_concurrent_downloads")
        if maxConcurrentDownloads == 0 { maxConcurrentDownloads = 3 }

        coverCacheLimit = UserDefaults.standard.integer(forKey: "cover_cache_limit")
        if coverCacheLimit == 0 { coverCacheLimit = 100 }

        memoryCacheSize = UserDefaults.standard.integer(forKey: "memory_cache_size")
        if memoryCacheSize == 0 { memoryCacheSize = 50 }

        enableDebugLogging = UserDefaults.standard.bool(forKey: "enable_debug_logging")

        Task { await calculateStorageInfo() }
    }

    func calculateStorageInfo() async {
        appCacheSize = calculateAppCacheSize()
        coverCacheSize = calculateCoverCacheSize()
        downloadedBooksCount = downloadManager.downloadedBooks.count
        totalDownloadSize = calculateDownloadSize()
    }

    func clearAppCache() async {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let coverCacheURL = cacheURL.appendingPathComponent("BookCovers")

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
            for file in contents where file != coverCacheURL {
                try FileManager.default.removeItem(at: file)
            }
            await calculateStorageInfo()
        } catch {}
    }

    func clearCompleteCache() async {
        await clearAppCache()
        coverCacheManager.clearAllCache()
        await calculateStorageInfo()
    }

    func clearAllDownloads() async {
        downloadManager.deleteAllBooks()
        await calculateStorageInfo()
    }

    func clearCoverMemoryCache() {
        coverCacheManager.clearMemoryCache()
    }

    func saveCoverCacheSettings() {
        UserDefaults.standard.set(coverCacheLimit, forKey: "cover_cache_limit")
        UserDefaults.standard.set(memoryCacheSize, forKey: "memory_cache_size")
    }

    func saveDownloadSettings() {
        UserDefaults.standard.set(maxConcurrentDownloads, forKey: "max_concurrent_downloads")
    }

    func saveNetworkSettings() {
        UserDefaults.standard.set(connectionTimeout, forKey: "connection_timeout")
    }

    func toggleDebugLogging(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "enable_debug_logging")
    }

    private func calculateAppCacheSize() -> String {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let totalSize = folderSize(at: cacheURL)
        let coverSize = coverCacheManager.getCacheSize()
        return formatBytes(max(0, totalSize - coverSize))
    }

    private func calculateCoverCacheSize() -> String {
        formatBytes(coverCacheManager.getCacheSize())
    }

    private func calculateDownloadSize() -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadsURL = documentsURL.appendingPathComponent("Downloads")
        return formatBytes(folderSize(at: downloadsURL))
    }

    private func folderSize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if values.isRegularFile == true, let fileSize = values.fileSize {
                    total += Int64(fileSize)
                }
            } catch {}
        }
        return total
    }

    private func formatBytes(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
