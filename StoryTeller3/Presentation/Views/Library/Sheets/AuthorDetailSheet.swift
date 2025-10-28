//
//  AuthorDetailSheet.swift
//  StoryTeller3
//
//  ✅ CLEAN ARCHITECTURE: View with ViewModel using UseCases

import SwiftUI

struct AuthorDetailSheet: View {
    @StateObject private var viewModel: AuthorDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppStateManager
    
    // ✅ Infrastructure for UI components only
    private let player: AudioPlayer
    private let api: AudiobookshelfClient
    private let downloadManager: DownloadManager
    
    init(
        authorName: String,
        api: AudiobookshelfClient,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) {
        // Store for UI rendering
        self.api = api
        self.player = player
        self.downloadManager = downloadManager
        
        // Create ViewModel via Factory
        self._viewModel = StateObject(wrappedValue: AuthorDetailViewModelFactory.create(
            authorName: authorName,
            api: api,
            player: player,
            downloadManager: downloadManager,
            onBookSelected: onBookSelected
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                authorHeaderView
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                
                Divider()
                
                Group {
                    if viewModel.isLoading {
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        errorView(error)
                    } else if viewModel.authorBooks.isEmpty {
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
                await viewModel.loadAuthorBooks()
            }
            .alert("Error", isPresented: $viewModel.showingErrorAlert) {
                Button("OK") { }
                Button("Retry") {
                    Task { await viewModel.loadAuthorBooks() }
                }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }
    
    // MARK: - Author Header
    private var authorHeaderView: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(String(viewModel.authorName.prefix(2).uppercased()))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.accentColor)
                )
            
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
                
                Text(viewModel.authorName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                if !viewModel.authorBooks.isEmpty {
                    HStack(spacing: 12) {
                        Text("\(viewModel.authorBooks.count) books")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if viewModel.downloadedCount > 0 {
                            Text("• \(viewModel.downloadedCount) downloaded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if viewModel.totalDuration > 0 {
                            Text("• \(TimeFormatter.formatTimeCompact(viewModel.totalDuration))")
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
            
            Text("Loading books by \(viewModel.authorName)...")
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
                Task { await viewModel.loadAuthorBooks() }
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
            
            Text("No books by \(viewModel.authorName) were found in your library")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var booksGridView: some View {
        ScrollView {
            LazyVGrid(columns: DSGridColumns.two) {
                ForEach(viewModel.authorBooks) { book in
                    let cardViewModel = BookCardStateViewModel(
                        book: book,
                        player: player,
                        downloadManager: downloadManager
                    )
                    
                    BookCardView(
                        viewModel: cardViewModel,
                        api: api,
                        onTap: {
                            Task {
                                await viewModel.playBook(book, appState: appState)
                                dismiss()
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
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}
