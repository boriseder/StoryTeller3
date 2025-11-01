import SwiftUI

struct SeriesView: View {
    @StateObject private var viewModel: SeriesViewModel
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var theme: ThemeManager

    // Workaround to hide nodata at start of app
    @State private var showEmptyState = false
    
    init(api: AudiobookshelfClient, appState: AppStateManager, onBookSelected: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: SeriesViewModelFactory.create(
            api: api,
            appState: appState,
            onBookSelected: onBookSelected
        ))
    }

    var body: some View {
        ZStack {
            
            if theme.backgroundStyle == .dynamic {
                Color.accent.ignoresSafeArea()
            }

            ZStack {
                switch viewModel.uiState {
                    
                case .content, .loading, .loadingFromCache:
                    contentView
                        .transition(.opacity)

                case .offline(let cachedItemCount):
                    if cachedItemCount > 0 {
                        contentView
                    } else {
                        ErrorView(error: "No cached data available. Please connect to the internet.")
                            .transition(.opacity)
                    }

                case .error(let message):
                    ErrorView(error: message)
                        .transition(.opacity)

                case .empty:
                    if showEmptyState {
                        EmptyStateView()
                            .transition(.opacity)
                    }

                case .noDownloads:
                    NoDownloadsView()
                        .transition(.opacity)
                
                case .noSearchResults:
                    NoSearchResultsView()
                        .transition(.opacity)

                }
            }
            .onChange(of: viewModel.uiState) {
                if viewModel.uiState == .empty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak viewModel] in
                        guard viewModel?.uiState == .empty else { return }
                        withAnimation { showEmptyState = true }
                    }
                } else {
                    showEmptyState = false
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.uiState)

        }
        .navigationTitle(viewModel.libraryName)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbarColorScheme(
            theme.colorScheme,
            for: .navigationBar
        )
        .searchable(text: $viewModel.filterState.searchText, prompt: "Serien durchsuchen...")
        .refreshable {
            await viewModel.loadSeries()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if !viewModel.series.isEmpty {
                        sortMenu
                    }
                    SettingsButton()
                }
            }
        }
        .alert("Fehler", isPresented: $viewModel.showingErrorAlert) {
            Button("OK") { }
            Button("Erneut versuchen") {
                Task { await viewModel.loadSeries() }
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unbekannter Fehler")
        }
        .task {
            await viewModel.loadSeriesIfNeeded()
        }
    }
    
    // MARK: - Subviews
        
    private var contentView: some View {
        ZStack {
            if theme.backgroundStyle == .dynamic {
                DynamicBackground()
            }

            ScrollView {
                LazyVStack(spacing: DSLayout.contentGap) {
                    ForEach(viewModel.filteredAndSortedSeries) { series in
                        SeriesSectionView(
                            series: series,
                            api: viewModel.api,
                            onBookSelected: {
                                // Book selection is handled inside SeriesSectionView
                            }
                        )
                        .environmentObject(appState)
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
        .onAppear { viewModel.contentLoaded = true }
    }
    
    // MARK: - Toolbar Components
    
    private var sortMenu: some View {
        Menu {
            ForEach(SeriesSortOption.allCases, id: \.self) { option in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.filterState.selectedSortOption = option
                    }
                }) {
                    Label(option.rawValue, systemImage: option.systemImage)
                    if viewModel.filterState.selectedSortOption == option {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
    }
}
