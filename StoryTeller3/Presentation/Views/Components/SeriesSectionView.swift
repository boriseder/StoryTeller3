import SwiftUI

struct SeriesSectionView: View {
    @StateObject private var viewModel: SeriesSectionViewModel
    @EnvironmentObject var appState: AppStateManager
    
    init(
        series: Series,
        player: AudioPlayer,
        api: AudiobookshelfAPI,
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
       /* .background  {
            RoundedRectangle(cornerRadius: DSCorners.content)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        */
    }
    
    private var seriesHeader: some View {
        
            HStack{
                VStack (alignment: .leading) {
                    Image(systemName: "books.vertical")
                        .font(DSText.itemTitle)
                        .foregroundColor(.white)
                    
                }
                VStack (alignment: .leading) {
                    HStack {
                        Text(viewModel.series.name)
                            .font(DSText.metadata)
                            .foregroundColor(.white)
                    }
                    HStack (alignment: .firstTextBaseline){
                        if let author = viewModel.series.author {
                            Text("\(author) -")
                                .font(DSText.footnote)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        Text("\(viewModel.series.bookCount) books")
                            .font(DSText.metadata)
                            .foregroundColor(.white)
                    }
                }
                Spacer()

            }
            .padding(.bottom, DSLayout.tightPadding)
            .padding(.top, DSLayout.elementPadding)
            .padding(.trailing, DSLayout.contentPadding)

        
        /*
         HStack {
         VStack(alignment: .leading) {
         Text(viewModel.series.name)
         .font(DSText.itemTitle)
         .foregroundColor(.primary)
         
         if let author = viewModel.series.author {
         Text(author)
         .font(DSText.metadata)
         .foregroundColor(.secondary)
         }
         }
         
         Spacer()
         
         VStack(alignment: .trailing, spacing: 2) {
         Spacer()
         
         Text("\(viewModel.series.bookCount) books")
         .font(DSText.metadata)
         .foregroundColor(.secondary)
         
         /*
          Text(viewModel.series.formattedDuration)
          .font(.caption)
          .foregroundColor(.secondary)
          */
         }
         }
         .padding(.top, DSLayout.contentPadding)
         }
         */
    }
}

