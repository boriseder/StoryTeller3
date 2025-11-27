//
//  QuickBookmarkDebugView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 25.11.25.
//


import SwiftUI

// MARK: - Quick Debug View für Bookmark-Probleme
struct QuickBookmarkDebugView: View {
    @StateObject private var repository = BookmarkRepository.shared
    @EnvironmentObject var dependencies: DependencyContainer
    @ObservedObject private var library = DependencyContainer.shared.libraryViewModel
    
    var body: some View {
        List {
            Section("Problem Analysis") {
                Text("Missing Book ID:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("f13b5a32-f9ed-4df2-a50f-cf3094e142df")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.red)
            }
                        
            Section("Library Books") {
                if dependencies.libraryViewModel.books.isEmpty {
                    Text("❌ Library is EMPTY!")
                        .foregroundColor(.red)
                        .bold()
                } else {
                    Text("✅ Library has \(dependencies.libraryViewModel.books.count) books")
                        .foregroundColor(.green)
                }
                
                ForEach(dependencies.libraryViewModel.books.prefix(10)) { book in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.caption)
                            .bold()
                        Text(book.id)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                if dependencies.libraryViewModel.books.count > 10 {
                    Text("... and \(dependencies.libraryViewModel.books.count - 10) more")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Downloaded Books") {
                if dependencies.downloadManager.downloadedBooks.isEmpty {
                    Text("No downloaded books")
                        .foregroundColor(.secondary)
                } else {
                    Text("✅ \(dependencies.downloadManager.downloadedBooks.count) downloaded books")
                        .foregroundColor(.green)
                }
                
                ForEach(dependencies.downloadManager.downloadedBooks.prefix(5)) { book in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.caption)
                            .bold()
                        Text(book.id)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Bookmarks") {
                ForEach(Array(repository.bookmarks.keys.sorted()), id: \.self) { bookId in
                    let bookmarks = repository.bookmarks[bookId] ?? []
                    let isFound = dependencies.libraryViewModel.books.contains { $0.id == bookId }
                    || dependencies.downloadManager.downloadedBooks.contains { $0.id == bookId }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if isFound {
                                Text("✅")
                            } else {
                                Text("❌")
                            }
                            Text(bookId)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(isFound ? .green : .red)
                        }
                        
                        Text("\(bookmarks.count) bookmark(s)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Actions") {
                Button("Reload Library") {
                    Task {
                        await dependencies.libraryViewModel.loadBooks()
                        AppLogger.general.debug("📚 Library reloaded: \(dependencies.libraryViewModel.books.count) books")
                    }
                }
                
                Button("Resync Bookmarks") {
                    Task {
                        await repository.syncFromServer()
                        AppLogger.general.debug("🔖 Bookmarks resynced: \(repository.totalBookmarkCount) total")
                    }
                }
                
                Button("Try to Find Book via API") {
                    Task {
                        await findMissingBook()
                    }
                }
            }
        }
        .navigationTitle("Bookmark Debug")
        .task {
            if dependencies.libraryViewModel.books.isEmpty {
                AppLogger.general.debug("➡️ Loading books from DebugView")
                await dependencies.libraryViewModel.loadBooks()
                AppLogger.general.debug("➡️ Loaded books: \(dependencies.libraryViewModel.books.count)")
            }
        }
    }
    
    private func findMissingBook() async {
        let missingId = "f13b5a32-f9ed-4df2-a50f-cf3094e142df"
        
        guard let api = DependencyContainer.shared.apiClient else {
            AppLogger.general.debug("❌ API client not available")
            return
        }
        
        AppLogger.general.debug("🔍 Searching for book: \(missingId)")
        
        do {
            let book = try await api.books.fetchBookDetails(bookId: missingId)
            AppLogger.general.debug("✅ Found book via API: \(book.title)")
            AppLogger.general.debug("   Author: \(book.author ?? "Unknown")")
            AppLogger.general.debug("   Duration: Value of type 'Book' has no member 'duration")
        } catch {
            AppLogger.general.debug("❌ Could not fetch book from API: \(error)")
        }
    }
}


// MARK: - Alternative: Console Debug Extension
extension BookmarkRepository {
    func debugCompareWithLibrary(library: LibraryViewModel, downloadManager: DownloadManager) {
        AppLogger.general.debug("========================================")
        AppLogger.general.debug("🔍 Bookmark vs Library Comparison")
        AppLogger.general.debug("========================================")
        
        let libraryIds = Set(library.books.map { $0.id })
        let downloadIds = Set(downloadManager.downloadedBooks.map { $0.id })
        let bookmarkIds = Set(bookmarks.keys)
        
        AppLogger.general.debug("📚 Library has \(libraryIds.count) books")
        AppLogger.general.debug("⬇️ Downloads has \(downloadIds.count) books")
        AppLogger.general.debug("🔖 Bookmarks for \(bookmarkIds.count) books")
        
        AppLogger.general.debug("----------------------------------------")
        
        let missingFromLibrary = bookmarkIds.subtracting(libraryIds).subtracting(downloadIds)
        
        if missingFromLibrary.isEmpty {
            AppLogger.general.debug("✅ All bookmark books are available!")
        } else {
            AppLogger.general.debug("❌ \(missingFromLibrary.count) bookmark book(s) missing:")
            for id in missingFromLibrary {
                let count = bookmarks[id]?.count ?? 0
                AppLogger.general.debug("   • \(id) (\(count) bookmarks)")
            }
        }
        
        AppLogger.general.debug("========================================")
    }
}

// Usage in ContentView after loading:
// BookmarkRepository.shared.debugCompareWithLibrary(
//     library: dependencies.libraryViewModel,
//     downloadManager: dependencies.downloadManager
// )
