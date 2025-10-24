import SwiftUI

struct SeriesSectionView: View {
    @StateObject private var viewModel: SeriesSectionViewModel
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var theme: ThemeManager

    init(
        series: Series,
        player: AudioPlayer,
        api: AudiobookshelfClient,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: SeriesSectionViewModel(
            series: series,
            api: api,
            player: player,
            downloadManager: downloadManager,
            onBookSelected: onBookSelected
        ))
    }
    
    var body: some View {
        VStack {
            seriesHeader
            
            HorizontalBookScrollView(
                books: viewModel.books,
                player: viewModel.player,
                api: viewModel.api,
                downloadManager: viewModel.downloadManager,
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

