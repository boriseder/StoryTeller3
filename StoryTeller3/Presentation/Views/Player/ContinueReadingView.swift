import SwiftUI
// MARK: - Continue Reading Section
struct ContinueReadingSection: View {
    @StateObject private var continueManager = ContinueReadingManager()
    @StateObject private var syncManager = OfflineSyncManager.shared
    
    let player: AudioPlayer
    let api: AudiobookshelfAPI
    let downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            
            if continueManager.recentBooks.isEmpty {
                emptyStateView
            } else {
                recentBooksScrollView
            }
        }
        .onAppear {
            continueManager.loadRecentBooks()
        }
        .refreshable {
            await syncManager.performSync()
            continueManager.loadRecentBooks()
        }
    }
    
    private var sectionHeader: some View {
        HStack {
            Label("Continue Reading", systemImage: "book.closed.fill")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Sync status indicator
            syncStatusIndicator
        }
    }
    
    private var syncStatusIndicator: some View {
        Group {
            switch syncManager.syncStatus {
            case .idle:
                EmptyView()
            case .syncing:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            case .success(let date):
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("Synced \(timeAgo(date))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            case .failed(_):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Sync failed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.circle")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("No recent books")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Start listening to see your progress here")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
    
    private var recentBooksScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(continueManager.recentBooks, id: \.bookId) { state in
                    ContinueReadingCard(
                        state: state,
                        player: player,
                        api: api,
                        downloadManager: downloadManager,
                        continueManager: continueManager,
                        onTap: {
                            Task {
                                await resumeBook(state)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func resumeBook(_ state: PlaybackState) async {
        do {
            let book = try await api.fetchBookDetails(bookId: state.bookId)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            
            let isOffline = downloadManager.isBookDownloaded(book.id)
            player.load(book: book, isOffline: isOffline, restoreState: true)
            
            onBookSelected()
        } catch {
            AppLogger.debug.debug("Failed to resume book: \(error)")
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            return "\(Int(interval/60))m ago"
        } else {
            return "\(Int(interval/3600))h ago"
        }
    }
}

// MARK: - Continue Reading Card
struct ContinueReadingCard: View {
    let state: PlaybackState
    let player: AudioPlayer
    let api: AudiobookshelfAPI
    let downloadManager: DownloadManager
    let continueManager: ContinueReadingManager
    let onTap: () -> Void
    
    @State private var book: Book?
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Book cover with progress overlay
                ZStack(alignment: .bottom) {
                    if let book = book {
                        BookCoverView.square(
                            book: book,
                            size: 120,
                            api: api,
                            downloadManager: downloadManager
                        )
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                ProgressView()
                            )
                    }
                    
                    // Progress overlay
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(height: 4)
                                
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: geometry.size.width * state.progress, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Book info
                VStack(alignment: .leading, spacing: 4) {
                    if let book = book {
                        Text(book.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        if let author = book.author {
                            Text(author)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress info
                    HStack {
                        Text(continueManager.getProgressText(for: state))
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        Text(continueManager.getTimeAgoText(for: state))
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .task {
            await loadBookInfo()
        }
    }
    
    private func loadBookInfo() async {
        do {
            let loadedBook = try await api.fetchBookDetails(bookId: state.bookId)
            await MainActor.run {
                self.book = loadedBook
            }
        } catch {
            AppLogger.debug.debug("Failed to load book info for continue reading: \(error)")
        }
    }
}

// MARK: - Sync Status View
struct SyncStatusView: View {
    @StateObject private var syncManager = OfflineSyncManager.shared
    
    var body: some View {
        HStack {
            switch syncManager.syncStatus {
            case .idle:
                Label("Ready to sync", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(.secondary)
            
            case .syncing:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Syncing progress...")
                }
                .foregroundColor(.blue)
            
            case .success(let date):
                Label("Last sync: \(formatDate(date))", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            
            case .failed(let error):
                Label("Sync failed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            // Pending counts
            if syncManager.pendingUploads > 0 || syncManager.pendingDownloads > 0 {
                HStack(spacing: 8) {
                    if syncManager.pendingUploads > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.circle")
                                .font(.caption)
                            Text("\(syncManager.pendingUploads)")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    }
                    
                    if syncManager.pendingDownloads > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down.circle")
                                .font(.caption)
                            Text("\(syncManager.pendingDownloads)")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
            }
            
            // Manual sync button
            Button(action: {
                Task {
                    await syncManager.performSync()
                }
            }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
            }
            .disabled(syncManager.syncStatus.isActive)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Settings Integration
struct ProgressSyncSettingsView: View {
    @StateObject private var syncManager = OfflineSyncManager.shared
    @State private var autoSyncEnabled = true
    @State private var syncOnWiFiOnly = false
    @State private var showingClearProgressAlert = false
    
    var body: some View {
        Form {
            Section("Progress Synchronization") {
                Toggle("Auto-sync progress", isOn: $autoSyncEnabled)
                Toggle("Sync only on Wi-Fi", isOn: $syncOnWiFiOnly)
                
                HStack {
                    Text("Last sync")
                    Spacer()
                    switch syncManager.syncStatus {
                    case .success(let date):
                        Text(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date()))
                            .foregroundColor(.secondary)
                    case .failed(_):
                        Text("Failed")
                            .foregroundColor(.red)
                    default:
                        Text("Never")
                            .foregroundColor(.secondary)
                    }
                }
                
                Button("Sync now") {
                    Task {
                        await syncManager.performSync()
                    }
                }
                .disabled(syncManager.syncStatus.isActive)
            }
            
            Section("Data Management") {
                Button("Clear all progress data") {
                    showingClearProgressAlert = true
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Progress & Sync")
        .alert("Clear Progress Data", isPresented: $showingClearProgressAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearAllProgressData()
            }
        } message: {
            Text("This will permanently delete all saved reading progress. This action cannot be undone.")
        }
    }
    
    private func clearAllProgressData() {
        // Implementation would clear CoreData and UserDefaults
        AppLogger.debug.debug("[ProgressSync] Clearing all progress data")
    }
}
