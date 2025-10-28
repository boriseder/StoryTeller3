//
//  SeriesDetailSheet.swift
//  StoryTeller3
//
//  ✅ CLEAN ARCHITECTURE: View only depends on ViewModel

import SwiftUI

struct SeriesDetailSheet: View {
    @StateObject private var viewModel: SeriesDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var container: DependencyContainer

    init(series: Series, onBookSelected: @escaping () -> Void) {}

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Series Header
                seriesHeaderView
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                
                Divider()
                
                // Content
                Group {
                    if viewModel.isLoading {
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        errorView(error)
                    } else if viewModel.seriesBooks.isEmpty {
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
                await viewModel.loadSeriesBooks()
            }
            .alert("Error", isPresented: $viewModel.showingErrorAlert) {
                Button("OK") { }
                Button("Retry") {
                    Task { await viewModel.loadSeriesBooks() }
                }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }
    
    // MARK: - Series Header
    private var seriesHeaderView: some View {
        HStack(spacing: 16) {
            // Series Cover (UI component can use api for rendering)
            if let firstBook = viewModel.seriesBooks.first {
                BookCoverView.square(
                    book: firstBook,
                    size: 80,
                    api: container.audiobookshelfClient,
                    downloadManager: container.downloadManager
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
            }
            
            // Series Info
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
                
                Text("Series Name") // Get from viewModel
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                // Series Stats
                if !viewModel.seriesBooks.isEmpty {
                    HStack(spacing: 12) {
                        Text("\(viewModel.seriesBooks.count) books")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if viewModel.downloadedCount > 0 {
                            Text("• \(viewModel.downloadedCount) downloaded")
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
            
            Text("Loading series...")
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
                Text("Error loading series")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                Task { await viewModel.loadSeriesBooks() }
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
            Image(systemName: "books.vertical")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No books found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("This series contains no books")
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
                ForEach(viewModel.seriesBooks) { book in
                    let cardViewModel = BookCardStateViewModel(
                        book: book,
                        player: container.audioPlayer,
                        downloadManager: container.downloadManager ?? DownloadManager()
                    )
                    
                    BookCardView(
                        viewModel: cardViewModel,
                        api: container.audiobookshelfClient,
                        onTap: {
                            Task {
                                await viewModel.playBook(book, appState: appState)
                                dismiss()
                            }
                        },
                        onDownload: {
                            Task {
                                await viewModel.downloadBook(book)
                            }
                        },
                        onDelete: {
                            viewModel.deleteBook(book.id)
                        },
                        style: .series
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}
