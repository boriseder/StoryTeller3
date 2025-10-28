import SwiftUI

struct SeriesSectionView: View {
    @StateObject private var viewModel: SeriesSectionViewModel
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var container: DependencyContainer

    
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
            .environmentObject(container)
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
