//
//  Enhanced HomeView.swift
//  StoryTeller3
//
//  Updated to handle all personalized sections

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var theme: ThemeManager

    @State private var selectedSeries: Series?
    @State private var selectedAuthor: IdentifiableString?
    
    init(player: AudioPlayer, api: AudiobookshelfClient, downloadManager: DownloadManager, onBookSelected: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: HomeViewModelFactory.create(
            api: api,
            player: player,
            downloadManager: downloadManager,
            onBookSelected: onBookSelected
        ))
    }

    var body: some View {
        ZStack {
            
            if theme.backgroundStyle == .dynamic {
                Color.accent.ignoresSafeArea()
            }
          
            switch viewModel.uiState {

            case .loading:
                LoadingView(message: "Loading")
            case .error(let message):
                ErrorView(error: message)
            case .empty:
                EmptyStateView()
            case .noDownloads:
                NoDownloadsView()
            case .content:
                contentView
            }
        }
        .navigationTitle("Explore & listen")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarColorScheme(
            theme.colorScheme,
            for: .navigationBar
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                settingsButton
            }
        }
        .refreshable {
            await viewModel.loadPersonalizedSections()
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
        .sheet(item: $selectedSeries) { series in
        SeriesDetailSheet(
            series: series,
            player: viewModel.player,
            api: viewModel.api,
            downloadManager: viewModel.downloadManager,
            onBookSelected: viewModel.onBookSelected
        )
        .environmentObject(appState)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
        .sheet(item: $selectedAuthor) { authorWrapper in
        AuthorDetailSheet(
            authorName: authorWrapper.value,
            player: viewModel.player,
            api: viewModel.api,
            downloadManager: viewModel.downloadManager,
            onBookSelected: viewModel.onBookSelected
        )
        .environmentObject(appState)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ZStack {
            /*
            if theme.backgroundStyle == .dynamic {
                DynamicBackground()
            }
            Color.clear.ignoresSafeArea()
*/
            ScrollView {
                LazyVStack(spacing: DSLayout.contentGap) {
                    homeHeaderView
                        .opacity(viewModel.sectionsLoaded ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3).delay(0.1), value: viewModel.sectionsLoaded)
                    
                    ForEach(Array(viewModel.personalizedSections.enumerated()), id: \.element.id) { index, section in
                        PersonalizedSectionView(
                            section: section,
                            player: viewModel.player,
                            api: viewModel.api,
                            downloadManager: viewModel.downloadManager,
                            onBookSelected: { book in
                                Task { await viewModel.playBook(book, appState: appState) }
                            },
                            onSeriesSelected: { series in
                                selectedSeries = series
                            },
                            onAuthorSelected: { authorName in
                                selectedAuthor = authorName.asIdentifiable()
                            }
                        )
                        .environmentObject(appState)
                        .opacity(viewModel.sectionsLoaded ? 1 : 0)
                        .animation(
                            .easeInOut(duration: 0.4).delay(0.1 + Double(index) * 0.1),
                            value: viewModel.sectionsLoaded
                        )
                    }

                }
                Spacer()
                .frame(height: DSLayout.miniPlayerHeight)

            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, DSLayout.screenPadding)
        }
        .opacity(viewModel.contentLoaded ? 1 : 0)
        .animation(.easeInOut(duration: 0.5), value: viewModel.contentLoaded)
        .animation(.easeInOut(duration: 0.3), value: viewModel.uiState)
        .onAppear {
            viewModel.contentLoaded = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.sectionsLoaded = true
            }
        }
    }
    
    private var homeHeaderView: some View {
        VStack(spacing: DSLayout.elementGap) {
            
            HStack(spacing: DSLayout.contentGap) {
                HomeStatCard(
                    icon: "books.vertical.fill",
                    title: "Books in library",
                    value: "\(viewModel.totalItemsCount)",
                    color: .blue
                )
                
                Divider()
                    .frame(height: 40)
                
                HomeStatCard(
                    icon: "arrow.down.circle.fill",
                    title: "Downloaded",
                    value: "\(viewModel.downloadedCount)",
                    color: .green
                )
            }
        }
        .padding(DSLayout.contentGap)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
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
    let api: AudiobookshelfClient
    @ObservedObject var downloadManager: DownloadManager
    let onBookSelected: (Book) -> Void
    let onSeriesSelected: (Series) -> Void
    let onAuthorSelected: (String) -> Void
    
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading) {
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
                // Fallback for unknown types - treat as books
                bookSection
            }
        }
    }
    
    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline){
                Image(systemName: sectionIcon)
                    .font(DSText.itemTitle)
                    .foregroundColor(theme.textColor)
                
                Text(section.label)
                    .font(DSText.itemTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textColor)
            
                Spacer()
            /*
            if section.total > section.entities.count {
                Text("\(section.entities.count) of \(section.total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(section.entities.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
             */
        }
        .padding(.top, DSLayout.contentPadding)

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
            return api.converter.convertLibraryItemToBook(libraryItem)
        }
        
        return HorizontalBookScrollView(
            books: books,
            player: player,
            api: api,
            downloadManager: downloadManager,
            cardStyle: .series,
            onBookSelected: onBookSelected
        )
    }
    
    private var seriesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(section.entities.indices, id: \.self) { index in
                    let entity = section.entities[index]
                    
                    SeriesCardView(
                        entity: entity,
                        api: api,
                        downloadManager: downloadManager,
                        onTap: {
                            if let series = entity.asSeries {
                                onSeriesSelected(series)
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var authorsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack{
                ForEach(extractAuthors(), id: \.self) { authorName in
                    AuthorCardView(
                        authorName: authorName,
                        onTap: {
                            onAuthorSelected(authorName)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertToSeries() -> [Series] {
        // Convert entities to Series objects
        return section.entities.compactMap { entity -> Series? in
            return entity.asSeries
        }
    }
    
    private func extractAuthors() -> [String] {
        return section.entities.compactMap { entity -> String? in
            // For author sections, the name should be the author name
            if let name = entity.name {
                return name
            }
            // Fallback: extract from book metadata
            if let libraryItem = entity.asLibraryItem {
                return libraryItem.media.metadata.author
            }
            return nil
        }
        .uniqued() // Remove duplicates
    }
}

// MARK: - Series Card View
struct SeriesCardView: View {
    let entity: PersonalizedEntity
    let api: AudiobookshelfClient
    let downloadManager: DownloadManager
    let onTap: () -> Void
    
    private let cardStyle: BookCardStyle = .series
    @EnvironmentObject var theme: ThemeManager

    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Group {
                    if let series = entity.asSeries,
                       let firstBook = series.books.first,
                       let coverBook = api.converter.convertLibraryItemToBook(firstBook) {
                        
                        BookCoverView.square(
                            book: coverBook,
                            size: cardStyle.coverSize,
                            api: api,
                            downloadManager: downloadManager
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DSCorners.content))
                    }
                }
                .padding(.top, DSLayout.elementGap)
                .padding(.horizontal, DSLayout.elementGap)

                Text(displayName)
                    .font(DSText.emphasized)
                    .foregroundColor(theme.textColor)
                    .lineLimit(1)
                    .frame(maxWidth: cardStyle.coverSize, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(.vertical, DSLayout.elementPadding)
                    .padding(.horizontal, DSLayout.elementPadding)

            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: 1)
            .animation(.easeInOut(duration: 0.2), value: 1)

        }
        .buttonStyle(.plain)
    }
        
    private var displayName: String {
        return entity.name ?? entity.asSeries?.name ?? "Unknown Series"
    }
    
    private var displayAuthor: String? {
        if let series = entity.asSeries {
            return series.author
        }
        if let libraryItem = entity.asLibraryItem {
            return libraryItem.media.metadata.author
        }
        return nil
    }
    
    private var displayBookCount: String {
        if let series = entity.asSeries {
            return "\(series.bookCount) books"
        }
        if let numBooks = entity.numBooks {
            return "\(numBooks) books"
        }
        return "Series"
    }
}

// MARK: - Author Card View
struct AuthorCardView: View {
    let authorName: String
    let onTap: () -> Void
    
    @EnvironmentObject var theme: ThemeManager

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
                    .foregroundColor(theme.textColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Home Stat Card Component
struct HomeStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            Image(systemName: icon)
                .font(.system(size: DSLayout.icon))
                .foregroundColor(color)
                .frame(width: DSLayout.icon, height: DSLayout.icon)
                .background(color.opacity(0.1))
               // .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(title)
                    .font(DSText.footnote)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Array Extension for Unique
extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
