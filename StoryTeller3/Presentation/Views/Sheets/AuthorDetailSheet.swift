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
    let api: AudiobookshelfAPI
    @ObservedObject var downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var authorBooks: [Book] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Author Header
                authorHeaderView
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                
                Divider()
                
                // Content
                Group {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if authorBooks.isEmpty {
                        emptyStateView
                    } else {
                        booksGridView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                await loadAuthorBooks()
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
                Button("Retry") {
                    Task { await loadAuthorBooks() }
                }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
    
    // MARK: - Author Header
    private var authorHeaderView: some View {
        HStack(spacing: 16) {
            // Author Avatar
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(String(authorName.prefix(2).uppercased()))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.accentColor)
                )
            
            // Author Info
            VStack(alignment: .leading, spacing: 6) {
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14))
                        Text("Close")
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(authorName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                // Author Stats
                if !authorBooks.isEmpty {
                    HStack(spacing: 12) {
                        Text("\(authorBooks.count) books")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let downloadedCount = authorBooks.filter { downloadManager.isBookDownloaded($0.id) }.count
                        if downloadedCount > 0 {
                            Text("• \(downloadedCount) downloaded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        let totalDuration = authorBooks.reduce(0.0) { total, book in
                            total + (book.chapters.reduce(0.0) { chapterTotal, chapter in
                                chapterTotal + ((chapter.end ?? 0) - (chapter.start ?? 0))
                            })
                        }
                        
                        if totalDuration > 0 {
                            Text("• \(TimeFormatter.formatTimeCompact(totalDuration))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Content Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading books by \(authorName)...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Error loading books")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                Task { await loadAuthorBooks() }
            }) {
                Text("Retry")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No books found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("No books by \(authorName) were found in your library")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var booksGridView: some View {
        let columns = [
            GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 12)
        ]
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(authorBooks) { book in
                    BookCardView(
                        book: book,
                        player: player,
                        api: api,
                        downloadManager: downloadManager,
                        style: .library,
                        onTap: {
                            Task {
                                await playBook(book)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
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
            let allBooks = try await api.fetchBooks(from: libraryId, limit: 0, collapseSeries: false)
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
            AppLogger.debug.debug("Error loading author books: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    private func playBook(_ book: Book) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            
            let isOffline = downloadManager.isBookDownloaded(fetchedBook.id)
            player.load(book: fetchedBook, isOffline: isOffline, restoreState: true)
            
            dismiss()
            onBookSelected()
            
            AppLogger.debug.debug("[AuthorDetailSheet] Loaded book: \(fetchedBook.title)")
            
        } catch {
            errorMessage = "Could not load '\(book.title)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.debug.debug("[AuthorDetailSheet] Failed to load book: \(error)")
        }
        
        isLoading = false
    }}
