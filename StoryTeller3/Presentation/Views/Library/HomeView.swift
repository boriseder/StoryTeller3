//
//  Enhanced HomeView.swift
//  StoryTeller3
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    
    init(player: AudioPlayer, api: AudiobookshelfAPI, downloadManager: DownloadManager, onBookSelected: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: HomeViewModel(
            api: api,
            player: player,
            downloadManager: downloadManager,
            onBookSelected: onBookSelected
        ))
    }

    var body: some View {
        Group {
                contentView
            }
        .navigationTitle("Welcome back")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.loadPersonalizedSections()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                settingsButton
            }
        }
        .alert("Error", isPresented: $viewModel.showingErrorAlert) {
            Button("OK") { }
            Button("Retry") {
                Task { await viewModel.loadPersonalizedSections() }
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown Error")
        }
        .task {
            await viewModel.loadPersonalizedSectionsIfNeeded()
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ZStack {
            DynamicMusicBackground()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Header with Quick Stats
                    //homeHeaderView
                    
                    // All Personalized Sections
                    ForEach(viewModel.personalizedSections) { section in
                        PersonalizedSectionView(
                            section: section,
                            player: viewModel.player,
                            api: viewModel.api,
                            downloadManager: viewModel.downloadManager,
                            onBookSelected: { book in
                                Task {
                                    await viewModel.loadAndPlayBook(book)
                                }
                            },
                            onSeriesSelected: { series in
                                Task {
                                    await viewModel.loadSeriesBooks(series)
                                }
                            },
                            onAuthorSelected: { authorName in
                                Task {
                                    await viewModel.searchBooksByAuthor(authorName)
                                }
                            }
                        )
                    }
                    
                    // Bottom padding for mini player
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.vertical, 16)
            }
        }
    }
    
    private var homeHeaderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discover your library")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick Stats
            /*
            HStack(spacing: 16) {
                StatCard(
                    icon: "books.vertical.fill",
                    title: "Total Items",
                    value: "\(viewModel.totalItemsCount)",
                    color: .blue
                )
                
                StatCard(
                    icon: "arrow.down.circle.fill",
                    title: "Downloaded",
                    value: "\(viewModel.downloadedCount)",
                    color: .green
                )
            }
             */
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
    
    private var settingsButton: some View {
        Button(action: {
            NotificationCenter.default.post(name: .init("ShowSettings"), object: nil)
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Personalized Section View
struct PersonalizedSectionView: View {
    let section: PersonalizedSection
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI
    @ObservedObject var downloadManager: DownloadManager
    let onBookSelected: (Book) -> Void
    let onSeriesSelected: (Series) -> Void
    let onAuthorSelected: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            sectionHeader
            
            // Section Content based on type
            switch section.type {
            case "book":
                bookSection
            case "series":
                seriesSection
            case "authors":
                authorsSection
            default:
                // Fallback for unknown types
                bookSection
            }
        }
    }
    
    private var sectionHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: sectionIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                
                Text(section.label)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            if section.total > section.entities.count {
                Text("\(section.entities.count) of \(section.total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(section.entities.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var sectionIcon: String {
        switch section.id {
        case "continue-listening":
            return "play.circle.fill"
        case "recently-added":
            return "clock.fill"
        case "recent-series":
            return "rectangle.stack.fill"
        case "discover":
            return "sparkles"
        case "newest-authors":
            return "person.2.fill"
        default:
            return "books.vertical.fill"
        }
    }
    
    // MARK: - Section Content Types
    
    private var bookSection: some View {
        let books = section.entities.compactMap { entity -> Book? in
            guard let libraryItem = entity.asLibraryItem else { return nil }
            return api.convertLibraryItemToBook(libraryItem)
        }
        
        return HorizontalBookScrollView(
            books: books,
            player: player,
            api: api,
            downloadManager: downloadManager,
            cardStyle: .library,
            onBookSelected: onBookSelected
        )
    }
    
    private var seriesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(convertToSeries(), id: \.id) { series in
                    SeriesCardView(
                        series: series,
                        onTap: {
                            onSeriesSelected(series)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var authorsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(extractAuthors(), id: \.self) { authorName in
                    AuthorCardView(
                        authorName: authorName,
                        onTap: {
                            onAuthorSelected(authorName)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertToSeries() -> [Series] {
        // Convert entities to Series objects
        return section.entities.compactMap { entity -> Series? in
            guard let libraryItem = entity.asLibraryItem else { return nil }
            
            // Create a minimal Series object from the entity
            return Series(
                id: entity.id,
                name: libraryItem.media.metadata.title,
                nameIgnorePrefix: nil,
                nameIgnorePrefixSort: nil,
                books: [libraryItem],
                addedAt: Date().timeIntervalSince1970
            )
        }
    }
    
    private func extractAuthors() -> [String] {
        return section.entities.compactMap { entity -> String? in
            guard let libraryItem = entity.asLibraryItem else { return nil }
            return libraryItem.media.metadata.author
        }
        .uniqued() // Remove duplicates
    }
}

// MARK: - Series Card View
struct SeriesCardView: View {
    let series: Series
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Series Cover (using first book's cover)
                if let firstBook = series.firstBook {
                    BookCoverView.square(
                        book: Book(
                            id: firstBook.id,
                            title: firstBook.media.metadata.title,
                            author: firstBook.media.metadata.author,
                            chapters: [],
                            coverPath: firstBook.coverPath,
                            collapsedSeries: nil
                        ),
                        size: 120
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 120)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(series.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let author = series.author {
                        Text(author)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text("\(series.bookCount) books")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Author Card View
struct AuthorCardView: View {
    let authorName: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Author Avatar
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(authorName.prefix(2).uppercased()))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.accentColor)
                    )
                
                Text(authorName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Array Extension for Unique
extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
