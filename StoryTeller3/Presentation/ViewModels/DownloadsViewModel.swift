//
//  DownloadsViewModel.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//

import SwiftUI

class DownloadsViewModel: BaseViewModel {
    @Published var bookToDelete: Book?
    @Published var showingDeleteConfirmation = false
    @Published var showingDeleteAllConfirmation = false
    @Published var totalStorageUsed: Int64 = 0
    @Published var availableStorage: Int64 = 0
    @Published var showStorageWarning = false
    
    let downloadManager: DownloadManager
    let player: AudioPlayer
    private let onBookSelected: () -> Void
    
    // Storage threshold for warning (500MB)
    let storageThreshold: Int64 = 500_000_000
    
    // Computed property direkt vom DownloadManager
    var downloadedBooks: [Book] {
        downloadManager.downloadedBooks
    }
    
    init(downloadManager: DownloadManager, player: AudioPlayer, onBookSelected: @escaping () -> Void) {
        self.downloadManager = downloadManager
        self.player = player
        self.onBookSelected = onBookSelected
        super.init()
        
        // Initial storage calculation
        updateStorageInfo()
        
        // Monitor for storage changes
        setupStorageMonitoring()
    }
    
    // MARK: - Storage Management
    
    func updateStorageInfo() {
        totalStorageUsed = downloadManager.getTotalDownloadSize()
        availableStorage = getAvailableStorage()
        showStorageWarning = availableStorage < storageThreshold
        
        let usedFormatted = formatBytes(totalStorageUsed)
        let availableFormatted = formatBytes(availableStorage)
        
        AppLogger.debug.debug("[Downloads] Storage - Used: \(usedFormatted), Available: \(availableFormatted)")
    }
    
    private func setupStorageMonitoring() {
        // Update storage info when downloads change
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateStorageInfo()
        }
    }
    
    func getAvailableStorage() -> Int64 {
        let fileManager = FileManager.default
        guard let systemAttributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let freeSpace = systemAttributes[.systemFreeSize] as? Int64 else {
            return 0
        }
        return freeSpace
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: bytes)
    }
    
    func getBookStorageSize(_ book: Book) -> String {
        let size = downloadManager.getBookStorageSize(book.id)
        return formatBytes(size)
    }
    
    // MARK: - Playback
    
    func playBook(_ book: Book) {
        let isOffline = downloadManager.isBookDownloaded(book.id)
        player.load(book: book, isOffline: isOffline, restoreState: true)
        onBookSelected()
    }
    
    // MARK: - Delete Operations
    
    func requestDeleteBook(_ book: Book) {
        bookToDelete = book
        showingDeleteConfirmation = true
    }
    
    func confirmDeleteBook() {
        guard let book = bookToDelete else { return }
        
        AppLogger.debug.debug("[Downloads] Deleting book: \(book.title)")
        downloadManager.deleteBook(book.id)
        
        bookToDelete = nil
        showingDeleteConfirmation = false
        
        // Update storage info after deletion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateStorageInfo()
        }
    }
    
    func cancelDelete() {
        bookToDelete = nil
        showingDeleteConfirmation = false
    }
    
    func requestDeleteAll() {
        showingDeleteAllConfirmation = true
    }
    
    func confirmDeleteAll() {
        AppLogger.debug.debug("[Downloads] Deleting all downloads")
        downloadManager.deleteAllBooks()
        
        showingDeleteAllConfirmation = false
        
        // Update storage info after deletion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateStorageInfo()
        }
    }
    
    func cancelDeleteAll() {
        showingDeleteAllConfirmation = false
    }
}
