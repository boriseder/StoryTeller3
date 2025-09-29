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
    
    let downloadManager: DownloadManager
    let player: AudioPlayer
    private let onBookSelected: () -> Void
    
    // Computed property direkt vom DownloadManager
    var downloadedBooks: [Book] {
        downloadManager.downloadedBooks
    }
    
    init(downloadManager: DownloadManager, player: AudioPlayer, onBookSelected: @escaping () -> Void) {
        self.downloadManager = downloadManager
        self.player = player
        self.onBookSelected = onBookSelected
        super.init()
    }
    
    func playBook(_ book: Book) {
        let isOffline = downloadManager.isBookDownloaded(book.id)
        player.load(book: book, isOffline: isOffline, restoreState: true)
        onBookSelected()
    }

    func requestDeleteBook(_ book: Book) {
        bookToDelete = book
        showingDeleteConfirmation = true
    }
    
    func confirmDeleteBook() {
        guard let book = bookToDelete else { return }
        downloadManager.deleteBook(book.id)
        bookToDelete = nil
        showingDeleteConfirmation = false
    }
    
    func cancelDelete() {
        bookToDelete = nil
        showingDeleteConfirmation = false
    }
}
