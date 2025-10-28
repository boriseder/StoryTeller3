import SwiftUI

struct SeriesSectionView: View {
    @StateObject private var viewModel: SeriesSectionViewModel
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var theme: ThemeManager

    // ✅ Infrastructure for UI components only
    private let player: AudioPlayer
    private let api: AudiobookshelfClient
    private let downloadManager: DownloadManager
    
    init(
        series: Series,
        player: AudioPlayer,
        api: AudiobookshelfClient,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) {
        // Store for UI rendering
        self.player = player
        self.api = api
        self.downloadManager = downloadManager
        
        // Create ViewModel via Factory
        self._viewModel = StateObject(wrappedValue: SeriesSectionViewModelFactory.create(
            series: series,
            onBookSelected: onBookSelected
        ))
    }
    
    var body: some View {
        VStack {
            seriesHeader
            
            // ✅ UI component gets infrastructure for rendering
            HorizontalBookScrollView(
                books: viewModel.books,
                player: player,
                api: api,
                downloadManager: downloadManager,
                cardStyle: .series,
                onBookSelected: { book in
                    Task {
                        await viewModel.playBook(book, appState: appState)
                    }
                }
            )
        }
        .padding(.vertical, DSLayout.elementPadding)

    }
    
    private var seriesHeader: some View {
        
            HStack{
                VStack (alignment: .leading) {
                    Image(systemName: "books.vertical")
                        .font(DSText.itemTitle)
                        .foregroundColor(theme.textColor)
                    
                }
                VStack (alignment: .leading) {
                    HStack {
                        Text(viewModel.series.name)
                            .font(DSText.metadata)
                            .foregroundColor(theme.textColor)
                    }
                    HStack (alignment: .firstTextBaseline){
                        if let author = viewModel.series.author {
                            Text("\(author) -")
                                .font(DSText.footnote)
                                .foregroundColor(theme.textColor)
                                .lineLimit(1)
                        }
                        Text("\(viewModel.series.bookCount) books")
                            .font(DSText.metadata)
                            .foregroundColor(theme.textColor)
                    }
                }
                Spacer()

            }
            .padding(.bottom, DSLayout.tightPadding)
            .padding(.top, DSLayout.elementPadding)
            .padding(.trailing, DSLayout.contentPadding)
    }
}
