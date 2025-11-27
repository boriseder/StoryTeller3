//
//  BookmarkListView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 24.11.25.
//


import SwiftUI

// MARK: - Bookmark List View (für Player oder Book Detail)
struct BookmarkListView: View {
    let book: Book
    let onBookmarkTap: (Bookmark) -> Void
    
    @StateObject private var repository = BookmarkRepository.shared
    @State private var showingAddBookmark = false
    @State private var editingBookmark: Bookmark?

    private var bookmarks: [Bookmark] {
        repository.getBookmarks(for: book.id)
    }
    
    var body: some View {
        List {
            if bookmarks.isEmpty {
                emptyState
            } else {
                ForEach(bookmarks) { bookmark in
                    BookmarkRow(
                        bookmark: bookmark,
                        book: book,
                        onTap: { onBookmarkTap(bookmark) },
                        onEdit: { editingBookmark = bookmark },
                        onDelete: { deleteBookmark(bookmark) }
                    )
                }
            }
        }
        .navigationTitle("Bookmarks")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddBookmark = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        /*
        .sheet(isPresented: $showingAddBookmark) {
            AddBookmarkView(book: book)
        }
        .sheet(item: $editingBookmark) { bookmark in
            EditBookmarkView(book: book, bookmark: bookmark)
        }
         */
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Bookmarks")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap + to add your first bookmark")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private func deleteBookmark(_ bookmark: Bookmark) {
        Task {
            do {
                try await repository.deleteBookmark(
                    libraryItemId: book.id,
                    time: bookmark.time
                )
            } catch {
                AppLogger.general.debug("[BookmarkList] Delete failed: \(error)")
            }
        }
    }
}

// MARK: - Bookmark Row
struct BookmarkRow: View {
    let bookmark: Bookmark
    let book: Book
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Time Badge
                VStack(spacing: 4) {
                    Text(bookmark.formattedTime)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                    
                    if let chapterTitle = bookmark.chapterTitle(for: book) {
                        Text("Ch. \(bookmark.chapterIndex(for: book) + 1)")
                            .font(.system(.caption2))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 70)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
                
                // Bookmark Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(bookmark.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    if let chapterTitle = bookmark.chapterTitle(for: book) {
                        Text(chapterTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text(bookmark.createdDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("Jump to Bookmark", systemImage: "play.fill")
            }
            
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
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
/*
// MARK: - Add Bookmark Sheet
struct AddBookmarkView: View {
    let book: Book
    @State private var title: String = ""
    @State private var time: Double = 0
    @State private var isCreating = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var repository = BookmarkRepository.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Bookmark Details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                    
                    HStack {
                        Text("Time")
                        Spacer()
                        Text(TimeFormatter.formatTime(time))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $time, in: 0...(book.chapters.last?.end ?? 0))
                    Text("Position")
                    }
                }
                
                Section {
                    Button("Create Bookmark") {
                        createBookmark()
                    }
                    .disabled(title.isEmpty || isCreating)
                }
            }
            .navigationTitle("New Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createBookmark() {
        guard !title.isEmpty else { return }
        
        isCreating = true
        
        Task {
            do {
                try await repository.createBookmark(
                    libraryItemId: book.id,
                    time: time,
                    title: title
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                AppLogger.general.debug("[AddBookmark] Failed: \(error)")
                isCreating = false
            }
        }
    }
}

// MARK: - Edit Bookmark Sheet
struct EditBookmarkView: View {
    let book: Book
    let bookmark: Bookmark
    @State private var title: String
    @State private var isUpdating = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var repository = BookmarkRepository.shared
    
    init(book: Book, bookmark: Bookmark) {
        self.book = book
        self.bookmark = bookmark
        _title = State(initialValue: bookmark.title)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Edit Title") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section("Details") {
                    HStack {
                        Text("Time")
                        Spacer()
                        Text(bookmark.formattedTime)
                            .foregroundColor(.secondary)
                    }
                    
                    if let chapterTitle = bookmark.chapterTitle(for: book) {
                        HStack {
                            Text("Chapter")
                            Spacer()
                            Text(chapterTitle)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button("Save Changes") {
                        updateBookmark()
                    }
                    .disabled(title.isEmpty || title == bookmark.title || isUpdating)
                }
            }
            .navigationTitle("Edit Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func updateBookmark() {
        guard !title.isEmpty, title != bookmark.title else { return }
        
        isUpdating = true
        
        Task {
            do {
                try await repository.updateBookmark(
                    libraryItemId: book.id,
                    time: bookmark.time,
                    newTitle: title
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                AppLogger.general.debug("[EditBookmark] Failed: \(error)")
                isUpdating = false
            }
        }
    }
}

// MARK: - Quick Bookmark Button (für Player)
struct QuickBookmarkButton: View {
    let book: Book
    let currentTime: Double
    @State private var showingBookmarkSheet = false
    @State private var bookmarkTitle = ""
    @StateObject private var repository = BookmarkRepository.shared
    
    var body: some View {
        Button {
            showingBookmarkSheet = true
        } label: {
            Image(systemName: "bookmark")
                .font(.title3)
        }
        .sheet(isPresented: $showingBookmarkSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Bookmark title", text: $bookmarkTitle)
                            .textInputAutocapitalization(.sentences)
                    }
                    
                    Section {
                        HStack {
                            Text("Time")
                            Spacer()
                            Text(TimeFormatter.formatTime(currentTime))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section {
                        Button("Save Bookmark") {
                            saveBookmark()
                        }
                        .disabled(bookmarkTitle.isEmpty)
                    }
                }
                .navigationTitle("Add Bookmark")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingBookmarkSheet = false
                        }
                    }
                }
            }
        }
    }
    
    private func saveBookmark() {
        guard !bookmarkTitle.isEmpty else { return }
        
        Task {
            do {
                try await repository.createBookmark(
                    libraryItemId: book.id,
                    time: currentTime,
                    title: bookmarkTitle
                )
                await MainActor.run {
                    bookmarkTitle = ""
                    showingBookmarkSheet = false
                }
            } catch {
                AppLogger.general.debug("[QuickBookmark] Failed: \(error)")
            }
        }
    }
}
*/
