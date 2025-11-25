//
//  AllBookmarksView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 24.11.25.
//


import SwiftUI

// MARK: - All Bookmarks View (über alle Bücher)
struct AllBookmarksView: View {
    @StateObject private var repository = BookmarkRepository.shared
    @EnvironmentObject var dependencies: DependencyContainer
    @State private var searchText = ""
    @State private var sortOption: BookmarkSortOption = .dateNewest
    @State private var groupByBook = true
    
    private var player: AudioPlayer { dependencies.player }
    
    // Alle Bookmarks flach
    private var allBookmarks: [BookmarkWithBook] {
        var items: [BookmarkWithBook] = []
        
        for (libraryItemId, bookmarks) in repository.bookmarks {
            // Versuche Book-Infos zu laden (aus Library oder Downloads)
            let book = dependencies.libraryViewModel.books.first { $0.id == libraryItemId }
                ?? dependencies.downloadManager.downloadedBooks.first { $0.id == libraryItemId }
            
            for bookmark in bookmarks {
                items.append(BookmarkWithBook(bookmark: bookmark, book: book))
            }
        }
        
        return items
            .filter { searchFilter($0) }
            .sorted { sortBookmarks($0, $1) }
    }
    
    // Gruppiert nach Buch
    private var groupedBookmarks: [(book: Book?, bookmarks: [Bookmark])] {
        var grouped: [String: (Book?, [Bookmark])] = [:]
        
        for item in allBookmarks {
            let key = item.bookmark.libraryItemId
            if grouped[key] == nil {
                grouped[key] = (item.book, [])
            }
            grouped[key]?.1.append(item.bookmark)
        }
        
        return grouped.values.map { ($0.0, $0.1) }
            .sorted { (first, second) in
                guard let book1 = first.book, let book2 = second.book else { return false }
                return book1.title < book2.title
            }
    }
    
    var body: some View {
        List {
            if allBookmarks.isEmpty {
                emptyState
            } else {
                if groupByBook {
                    groupedView
                } else {
                    flatView
                }
            }
        }
        .navigationTitle("All Bookmarks")
        .searchable(text: $searchText, prompt: "Search bookmarks...")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    sortMenu
                    Divider()
                    groupingMenu
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .refreshable {
            await repository.syncFromServer()
        }
    }
    
    // MARK: - Flat View (alle Bookmarks chronologisch)
    
    private var flatView: some View {
        ForEach(allBookmarks) { item in
            AllBookmarksRow(
                item: item,
                onTap: { jumpToBookmark(item) },
                onDelete: { deleteBookmark(item) }
            )
        }
    }
    
    // MARK: - Grouped View (nach Buch gruppiert)
    
    private var groupedView: some View {
        ForEach(groupedBookmarks, id: \.book?.id) { group in
            Section {
                ForEach(group.bookmarks) { bookmark in
                    let item = BookmarkWithBook(bookmark: bookmark, book: group.book)
                    AllBookmarksRow(
                        item: item,
                        showBookInfo: false, // Schon im Section Header
                        onTap: { jumpToBookmark(item) },
                        onDelete: { deleteBookmark(item) }
                    )
                }
            } header: {
                if let book = group.book {
                    BookSectionHeader(book: book, bookmarkCount: group.bookmarks.count)
                } else {
                    Text("Unknown Book (\(group.bookmarks.count) bookmarks)")
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 70))
                .foregroundColor(.secondary)
            
            Text("No Bookmarks")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start adding bookmarks while listening to your audiobooks")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Sort Menu
    
    private var sortMenu: some View {
        Section("Sort By") {
            ForEach(BookmarkSortOption.allCases, id: \.self) { option in
                Button {
                    sortOption = option
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
    
    private var groupingMenu: some View {
        Section("View") {
            Button {
                withAnimation {
                    groupByBook.toggle()
                }
            } label: {
                HStack {
                    Text(groupByBook ? "Show All" : "Group by Book")
                    if groupByBook {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
    
    // MARK: - Filter & Sort
    
    private func searchFilter(_ item: BookmarkWithBook) -> Bool {
        if searchText.isEmpty { return true }
        
        let query = searchText.lowercased()
        
        // Suche in Bookmark-Titel
        if item.bookmark.title.lowercased().contains(query) {
            return true
        }
        
        // Suche in Buch-Titel
        if let book = item.book, book.title.lowercased().contains(query) {
            return true
        }
        
        return false
    }
    
    private func sortBookmarks(_ first: BookmarkWithBook, _ second: BookmarkWithBook) -> Bool {
        switch sortOption {
        case .dateNewest:
            return first.bookmark.createdAt > second.bookmark.createdAt
        case .dateOldest:
            return first.bookmark.createdAt < second.bookmark.createdAt
        case .timeInBook:
            return first.bookmark.time < second.bookmark.time
        case .bookTitle:
            guard let book1 = first.book, let book2 = second.book else { return false }
            return book1.title < book2.title
        }
    }
    
    // MARK: - Actions
    
    private func jumpToBookmark(_ item: BookmarkWithBook) {
        guard let book = item.book else {
            AppLogger.general.debug("[AllBookmarks] Cannot jump - book not found")
            return
        }
        
        Task {
            // Load book if not currently playing
            if player.book?.id != book.id {
                await player.load(book: book, isOffline: false, restoreState: false, autoPlay: false)
            }
            
            // Jump to bookmark
            await MainActor.run {
                player.jumpToBookmark(item.bookmark)
            }
        }
    }
    
    private func deleteBookmark(_ item: BookmarkWithBook) {
        Task {
            do {
                try await repository.deleteBookmark(
                    libraryItemId: item.bookmark.libraryItemId,
                    time: item.bookmark.time
                )
            } catch {
                AppLogger.general.debug("[AllBookmarks] Delete failed: \(error)")
            }
        }
    }
}

// MARK: - Bookmark with Book Info
struct BookmarkWithBook: Identifiable {
    let bookmark: Bookmark
    let book: Book?
    
    var id: String { bookmark.id }
}

// MARK: - Sort Options
enum BookmarkSortOption: String, CaseIterable {
    case dateNewest = "Date (Newest)"
    case dateOldest = "Date (Oldest)"
    case timeInBook = "Time in Book"
    case bookTitle = "Book Title"
}

// MARK: - Bookmark Row für All-Bookmarks View
struct AllBookmarksRow: View {
    let item: BookmarkWithBook
    var showBookInfo: Bool = true
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Book Cover (wenn vorhanden)
                if showBookInfo, let book = item.book {
                    BookCoverView.square(
                        book: book,
                        size: 60,
                        api: DependencyContainer.shared.apiClient,
                        downloadManager: nil,
                        showProgress: false
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    // Bookmark Title
                    Text(item.bookmark.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    // Book Title (wenn angezeigt werden soll)
                    if showBookInfo, let book = item.book {
                        Text(book.title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Time & Date
                    HStack(spacing: 12) {
                        Label(item.bookmark.formattedTime, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(
                            item.bookmark.createdDate.formatted(date: .abbreviated, time: .omitted),
                            systemImage: "calendar"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    // Chapter Info (wenn Book verfügbar)
                    if let book = item.book, let chapterTitle = item.bookmark.chapterTitle(for: book) {
                        Text("Ch. \(item.bookmark.chapterIndex(for: book) + 1): \(chapterTitle)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("Jump to Bookmark", systemImage: "play.fill")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Book Section Header
struct BookSectionHeader: View {
    let book: Book
    let bookmarkCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            BookCoverView.square(
                book: book,
                size: 40,
                api: DependencyContainer.shared.apiClient,
                downloadManager: nil,
                showProgress: false
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("\(bookmarkCount) bookmark\(bookmarkCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}