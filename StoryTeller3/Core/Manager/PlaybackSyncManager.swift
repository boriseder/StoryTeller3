//
//  PlaybackSyncManager.swift
//  StoryTeller3
//
//  Created by Boris Eder on 21.11.25.
//


import Foundation
import SwiftUI

/// Manages automatic synchronization of playback progress with the server
@MainActor
class PlaybackSyncManager: ObservableObject {
    static let shared = PlaybackSyncManager()
    
    @Published var lastSyncDate: Date?
    @Published var isSyncing: Bool = false
    @Published var syncError: Error?
    
    private let syncInterval: TimeInterval = 60.0 // Sync every 60 seconds
    private var syncTimer: Timer?
    private var lastSyncedStates: [String: PlaybackState] = [:] // bookId -> last synced state
    
    private let persistenceManager = PlaybackPersistenceManager.shared
    private var api: AudiobookshelfClient?
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Configuration
    
    func configure(api: AudiobookshelfClient) {
        self.api = api
        startPeriodicSync()
    }
    
    // MARK: - Manual Sync
    
    func syncNow() async {
        guard let api = api else {
            AppLogger.general.debug("[PlaybackSync] API not configured, skipping sync")
            return
        }
        
        guard !isSyncing else {
            AppLogger.general.debug("[PlaybackSync] Sync already in progress")
            return
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            let states = persistenceManager.getAllPlaybackStates()
            
            // Only sync states that have changed since last sync
            let statesToSync = states.filter { state in
                shouldSyncState(state)
            }
            
            if statesToSync.isEmpty {
                AppLogger.general.debug("[PlaybackSync] No changes to sync")
                isSyncing = false
                return
            }
            
            AppLogger.general.debug("[PlaybackSync] Syncing \(statesToSync.count) states")
            
            for state in statesToSync {
                do {
                    // ✅ Use existing ProgressService API
                    try await api.progress.updatePlaybackProgress(
                        libraryItemId: state.bookId,
                        currentTime: state.currentTime,
                        timeListened: 0, // We don't track this separately
                        duration: state.duration
                    )
                    
                    lastSyncedStates[state.bookId] = state
                    AppLogger.general.debug("[PlaybackSync] ✓ Synced: \(state.bookId)")
                } catch {
                    AppLogger.general.debug("[PlaybackSync] ✗ Failed: \(state.bookId) - \(error)")
                    syncError = error
                }
            }
            
            lastSyncDate = Date()
            AppLogger.general.debug("[PlaybackSync] Sync completed successfully")
            
        } catch {
            syncError = error
            AppLogger.general.debug("[PlaybackSync] Sync failed: \(error)")
        }
        
        isSyncing = false
    }
    
    // MARK: - Periodic Sync
    
    private func startPeriodicSync() {
        stopPeriodicSync()
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncNow()
            }
        }
        
        // Also sync immediately
        Task {
            await syncNow()
        }
        
        AppLogger.general.debug("[PlaybackSync] Started periodic sync (every \(syncInterval)s)")
    }
    
    private func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Sync when app enters background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.syncNow()
            }
        }
        
        // Sync when app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.syncNow()
            }
        }
        
        // Listen for playback state changes
        NotificationCenter.default.addObserver(
            forName: .playbackStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let state = notification.object as? PlaybackState {
                self?.markStateAsChanged(state)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func shouldSyncState(_ state: PlaybackState) -> Bool {
        guard let lastSynced = lastSyncedStates[state.bookId] else {
            return true // Never synced before
        }
        
        // Check if state has changed significantly
        let timeChanged = abs(state.currentTime - lastSynced.currentTime) > 5.0 // 5 seconds threshold
        let chapterChanged = state.chapterIndex != lastSynced.chapterIndex
        let finishedChanged = state.isFinished != lastSynced.isFinished
        
        return timeChanged || chapterChanged || finishedChanged
    }
    
    private func markStateAsChanged(_ state: PlaybackState) {
        // Remove from lastSyncedStates to force sync on next cycle
        lastSyncedStates.removeValue(forKey: state.bookId)
    }
    
    // MARK: - Download Progress from Server
    
    /// Downloads the current progress from the server for a specific book
    func downloadProgress(for bookId: String) async throws -> PlaybackState? {
        guard let api = api else {
            throw PlaybackSyncError.apiNotConfigured
        }
        
        AppLogger.general.debug("[PlaybackSync] Downloading progress for: \(bookId)")
        
        // ✅ Use existing ProgressService API
        guard let serverProgress = try await api.progress.fetchPlaybackProgress(libraryItemId: bookId) else {
            AppLogger.general.debug("[PlaybackSync] No server progress found for: \(bookId)")
            return nil
        }
        
        // Convert MediaProgress to PlaybackState
        return PlaybackState(
            bookId: bookId,
            chapterIndex: 0, // Server doesn't track chapter index separately
            currentTime: serverProgress.currentTime,
            duration: serverProgress.duration,
            lastPlayed: Date(timeIntervalSince1970: serverProgress.lastUpdate),
            isFinished: serverProgress.isFinished
        )
    }
    
    /// Downloads all items in progress from the server
    func downloadAllInProgress() async throws -> [PlaybackState] {
        guard let api = api else {
            throw PlaybackSyncError.apiNotConfigured
        }
        
        AppLogger.general.debug("[PlaybackSync] Downloading all items in progress")
        
        // ✅ Use existing ProgressService API
        let itemsInProgress = try await api.progress.fetchItemsInProgress()
        
        return itemsInProgress.compactMap { mediaProgress in
            PlaybackState(
                bookId: mediaProgress.libraryItemId,
                chapterIndex: 0,
                currentTime: mediaProgress.currentTime,
                duration: mediaProgress.duration,
                lastPlayed: Date(timeIntervalSince1970: mediaProgress.lastUpdate),
                isFinished: mediaProgress.isFinished
            )
        }
    }
    
    /// Syncs down progress from server and merges with local data
    func syncFromServer() async throws {
        guard let api = api else {
            throw PlaybackSyncError.apiNotConfigured
        }
        
        AppLogger.general.debug("[PlaybackSync] Starting sync from server")
        
        let serverStates = try await downloadAllInProgress()
        
        for serverState in serverStates {
            let localState = persistenceManager.loadPlaybackState(for: serverState.bookId)
            
            // Use whichever is more recent
            if let local = localState {
                if serverState.lastPlayed > local.lastPlayed {
                    // Server is newer
                    persistenceManager.savePlaybackState(serverState)
                    AppLogger.general.debug("[PlaybackSync] Updated local with server data: \(serverState.bookId)")
                } else {
                    AppLogger.general.debug("[PlaybackSync] Local is newer, keeping: \(serverState.bookId)")
                }
            } else {
                // No local state, save server state
                persistenceManager.savePlaybackState(serverState)
                AppLogger.general.debug("[PlaybackSync] Saved new server progress: \(serverState.bookId)")
            }
        }
        
        AppLogger.general.debug("[PlaybackSync] Sync from server completed")
    }
    
    deinit {
        stopPeriodicSync()
    }
}

// MARK: - Sync Errors

enum PlaybackSyncError: LocalizedError {
    case apiNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .apiNotConfigured:
            return "API client not configured"
        }
    }
}