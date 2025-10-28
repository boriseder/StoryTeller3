//
// HomeView.swift
// ✅ MIGRATED - No Infrastructure Props

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var appState: AppStateManager
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var viewModel: HomeViewModel
    @State private var selectedSeries: Series?
    @State private var selectedAuthor: IdentifiableString?
    
    init(viewModel: HomeViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            if theme.backgroundStyle == .dynamic {
                Color.accent.ignoresSafeArea()
            }
          
            switch viewModel.uiState {
            case .loading: LoadingView(message: "Loading")
            case .error(let message): ErrorView(error: message)
            case .empty: EmptyStateView()
            case .noDownloads: NoDownloadsView()
            case .content: contentView
            }
        }
        .navigationTitle("Explore & listen")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { NotificationCenter.default.post(name: .init("ShowSettings"), object: nil) }) {
                    Image(systemName: "gearshape.fill").font(.system(size: 16))
                }
            }
        }
        .refreshable { await viewModel.loadPersonalizedSections() }
        .task { await viewModel.loadPersonalizedSectionsIfNeeded() }
        .sheet(item: $selectedSeries) { series in
            SeriesDetailSheet(series: series, onBookSelected: viewModel.onBookSelected)
                .environmentObject(appState).presentationDetents([.medium, .large])
                .environmentObject(container)
        }
        .sheet(item: $selectedAuthor) { authorWrapper in
            AuthorDetailSheet(authorName: authorWrapper.value, onBookSelected: viewModel.onBookSelected)
                .environmentObject(appState).presentationDetents([.medium, .large])
                .environmentObject(container)
        }
    }
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.contentGap) {
                homeHeaderView
                ForEach(Array(viewModel.personalizedSections.enumerated()), id: \.element.id) { index, section in
                    PersonalizedSectionView(
                        section: section,
                        onBookSelected: { book in Task { await viewModel.playBook(book, appState: appState) } },
                        onSeriesSelected: { selectedSeries = $0 },
                        onAuthorSelected: { selectedAuthor = $0.asIdentifiable() }
                    )
                }
            }.padding(.horizontal, DSLayout.screenPadding)
        }
    }
    
    private var homeHeaderView: some View {
        HStack {
            HomeStatCard(icon: "books.vertical.fill", title: "Books", value: "\(viewModel.totalItemsCount)", color: .blue)
            Divider().frame(height: 40)
            HomeStatCard(icon: "arrow.down.circle.fill", title: "Downloaded", value: "\(viewModel.downloadedCount)", color: .green)
        }
        .padding().background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
    }
}

struct PersonalizedSectionView: View {
    let section: PersonalizedSection
    let onBookSelected: (Book) -> Void
    let onSeriesSelected: (Series) -> Void
    let onAuthorSelected: (String) -> Void
    @EnvironmentObject private var container: DependencyContainer
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(section.label).font(DSText.itemTitle)
            switch section.type {
            case "book": bookSection
            case "series": seriesSection
            default: bookSection
            }
        }
    }
    
    private var bookSection: some View {
        let books = section.entities.compactMap { entity -> Book? in
            guard let item = entity.asLibraryItem else { return nil }
            return container.audiobookshelfClient.converter.convertLibraryItemToBook(item)
        }
        return HorizontalBookScrollView(books: books, cardStyle: .series, onBookSelected: onBookSelected)
    }
    
    private var seriesSection: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(section.entities.indices, id: \.self) { index in
                    SeriesCardView(entity: section.entities[index], onTap: {
                        if let series = section.entities[index].asSeries { onSeriesSelected(series) }
                    })
                }
            }
        }
    }
}

struct SeriesCardView: View {
    let entity: PersonalizedEntity
    let onTap: () -> Void
    @EnvironmentObject private var container: DependencyContainer
    
    var body: some View {
        Button(action: onTap) {
            VStack {
                if let series = entity.asSeries, let book = series.books.first,
                   let coverBook = container.audiobookshelfClient.converter.convertLibraryItemToBook(book) {
                    BookCoverView.square(book: coverBook, size: 120)
                }
                Text(entity.name ?? "Unknown").lineLimit(1)
            }
        }
    }
}

struct HomeStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon).font(.system(size: 24)).foregroundColor(color)
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(value).font(.subheadline).fontWeight(.semibold)
            }
        }
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
