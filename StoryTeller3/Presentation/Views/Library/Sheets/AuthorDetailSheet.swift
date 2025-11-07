//
//  AuthorDetailSheet.swift
//  StoryTeller3
//
//  Created by Boris Eder on 24.09.25.
//


//
//  AuthorDetailSheet.swift
//  StoryTeller3
//

import SwiftUI

struct AuthorDetailSheet: View {
    let authorName: String
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfClient
    @ObservedObject var downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var authorBooks: [Book] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        
        NavigationStack {
            VStack(alignment: .leading, spacing: DSLayout.contentGap) {
                // Series Header
                authorHeaderView
                
                Divider()
                
                booksGridView
                
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                await loadAuthorBooks()
            }
        }
    }
    
    // MARK: - Author Header
    private var authorHeaderView: some View {
        HStack(alignment: .top) {
            
            // Author Avatar
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(String(authorName.prefix(2).uppercased()))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.accentColor)
                )
            
            // Author Info
            VStack(alignment: .leading, spacing: 4) {
                
                // Author Name
                Text(authorName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Stats
                if !authorBooks.isEmpty {
                    HStack(spacing: 8) {
                        Text("\(authorBooks.count) books")
                        
                        let downloadedCount = authorBooks.filter { downloadManager.isBookDownloaded($0.id) }.count
                        if downloadedCount > 0 {
                            Text("• \(downloadedCount) downloaded")
                        }
                        
                        let totalDuration = authorBooks.reduce(0.0) { total, book in
                            total + (book.chapters.reduce(0.0) { chapterTotal, chapter in
                                chapterTotal + ((chapter.end ?? 0) - (chapter.start ?? 0))
                            })
                        }
                        if totalDuration > 0 {
                            Text("• \(TimeFormatter.formatTimeCompact(totalDuration))")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .layoutPriority(1) // verhindert, dass der Name zu klein wird
            
            Spacer()
            
            // Dismiss Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSLayout.screenPadding)
        .padding(.top, DSLayout.comfortPadding)
    }
    // MARK: - Content Views
    
    private var booksGridView: some View {
        
        ScrollView {
            LazyVGrid(columns: DSGridColumns.two, spacing: 0) {
                ForEach(authorBooks) { book in
                    let viewModel = BookCardStateViewModel(book: book)
                    
                    BookCardView(
                        viewModel: viewModel,
                        api: api,
                        onTap: {
                            Task {
                                await playBook(book)
                            }
                        },
                        onDownload: {
                            Task {
                                await downloadManager.downloadBook(book, api: api)
                            }
                        },
                        onDelete: {
                            downloadManager.deleteBook(book.id)
                        },
                        style: .library
                    )
                }
            }
            .padding(.horizontal, DSLayout.contentPadding)
        }
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadAuthorBooks() async {
        guard let libraryId = LibraryHelpers.getCurrentLibraryId() else {            errorMessage = "No library selected"
            showingErrorAlert = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch all books and filter by author
            let allBooks = try await api.books.fetchBooks(libraryId: libraryId, limit: 0, collapseSeries: false)
            let filteredBooks = allBooks.filter { book in
                book.author?.localizedCaseInsensitiveContains(authorName) == true
            }
            
            // Sort books by title
            let sortedBooks = filteredBooks.sorted { book1, book2 in
                book1.title.localizedCompare(book2.title) == .orderedAscending
            }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                authorBooks = sortedBooks
            }
            
            // Preload covers for better performance
            CoverPreloadHelpers.preloadIfNeeded(
                books: sortedBooks,
                api: api,
                downloadManager: downloadManager
            )
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            AppLogger.general.debug("Error loading author books: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    private func playBook(_ book: Book) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedBook = try await api.books.fetchBookDetails(bookId: book.id, retryCount: 3)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            
            let isOffline = downloadManager.isBookDownloaded(fetchedBook.id)
            player.load(book: fetchedBook, isOffline: isOffline, restoreState: true)
            
            dismiss()
            onBookSelected()
            
            AppLogger.general.debug("[AuthorDetailSheet] Loaded book: \(fetchedBook.title)")
            
        } catch {
            errorMessage = "Could not load '\(book.title)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.general.debug("[AuthorDetailSheet] Failed to load book: \(error)")
        }
        
        isLoading = false
    }
}
