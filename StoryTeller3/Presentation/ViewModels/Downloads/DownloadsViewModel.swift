import SwiftUI

@MainActor
class DownloadsViewModel: ObservableObject {
    // MARK: - Published UI State
    @Published var progressState = DownloadProgressState()
    
    // MARK: - Dependencies
    private let downloadUseCase: DownloadBookUseCase
    private let storageMonitor: StorageMonitor
    private var storageUpdateTimer: Timer?
    
    let downloadManager: DownloadManager
    let player: AudioPlayer
    let onBookSelected: () -> Void
    
    // MARK: - Computed Properties for UI
    var downloadedBooks: [Book] {
        downloadManager.downloadedBooks
    }
    
    var bookToDelete: Book? {
        get { progressState.bookToDelete }
        set { progressState.bookToDelete = newValue }
    }
    
    var showingDeleteConfirmation: Bool {
        get { progressState.showingDeleteConfirmation }
        set { progressState.showingDeleteConfirmation = newValue }
    }
    
    var showingDeleteAllConfirmation: Bool {
        get { progressState.showingDeleteAllConfirmation }
        set { progressState.showingDeleteAllConfirmation = newValue }
    }
    
    var totalStorageUsed: Int64 {
        progressState.totalStorageUsed
    }
    
    var availableStorage: Int64 {
        progressState.availableStorage
    }
    
    var showStorageWarning: Bool {
        progressState.showStorageWarning
    }
    
    var storageThreshold: Int64 {
        progressState.storageThreshold
    }
    
    // MARK: - Init with DI
    init(
        downloadManager: DownloadManager,
        player: AudioPlayer,
        storageMonitor: StorageMonitor = StorageMonitor(),
        onBookSelected: @escaping () -> Void
    ) {
        self.downloadManager = downloadManager
        self.player = player
        self.storageMonitor = storageMonitor
        self.downloadUseCase = DownloadBookUseCase(downloadManager: downloadManager)
        self.onBookSelected = onBookSelected
        
        updateStorageInfo()
        setupStorageMonitoring()
    }
    
    // MARK: - Actions (Delegate to Use Cases)
    func updateStorageInfo() {
        let info = storageMonitor.getStorageInfo()
        let warningLevel = storageMonitor.getWarningLevel()
        
        let totalUsed = downloadManager.getTotalDownloadSize()
        
        progressState.updateStorage(
            totalUsed: totalUsed,
            available: info.availableSpace,
            warningLevel: warningLevel
        )
        
        AppLogger.debug.debug("[Downloads] Storage - Used: \(info.usedSpaceFormatted), Available: \(info.availableSpaceFormatted)")
    }
    
    private func setupStorageMonitoring() {
        storageUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateStorageInfo()
        }
    }
    
    func getBookStorageSize(_ book: Book) -> String {
        let size = downloadManager.getBookStorageSize(book.id)
        return storageMonitor.formatBytes(size)
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        return storageMonitor.formatBytes(bytes)
    }
    
    // MARK: - Playback
    func playBook(_ book: Book) {
        let isOffline = downloadManager.isBookDownloaded(book.id)
        player.load(book: book, isOffline: isOffline, restoreState: true)
        onBookSelected()
    }
    
    // MARK: - Delete Operations
    func requestDeleteBook(_ book: Book) {
        progressState.requestDelete(book)
    }
    
    func confirmDeleteBook() {
        guard let book = progressState.bookToDelete else { return }
        
        AppLogger.debug.debug("[Downloads] Deleting book: \(book.title)")
        downloadUseCase.delete(bookId: book.id)
        
        progressState.confirmDelete()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateStorageInfo()
        }
    }
    
    func cancelDelete() {
        progressState.cancelDelete()
    }
    
    func requestDeleteAll() {
        progressState.requestDeleteAll()
    }
    
    func confirmDeleteAll() {
        AppLogger.debug.debug("[Downloads] Deleting all downloads")
        downloadManager.deleteAllBooks()
        
        progressState.confirmDeleteAll()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateStorageInfo()
        }
    }
    
    func cancelDeleteAll() {
        progressState.cancelDeleteAll()
    }
    
    deinit {
        storageUpdateTimer?.invalidate()
        storageUpdateTimer = nil
    }
}
