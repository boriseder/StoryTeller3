//
//  AuthorDetailViewModelFactory.swift
//  StoryTeller3
//
//  Created by Boris Eder on 28.10.25.
//


//
//  AuthorDetailViewModelFactory.swift
//  StoryTeller3
//

import Foundation

@MainActor
struct AuthorDetailViewModelFactory {
    static func create(
        authorName: String,
        api: AudiobookshelfClient,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) -> AuthorDetailViewModel {
        
        // Create Repositories
        let bookRepository = BookRepository(api: api, cache: BookCache())
        let downloadRepository = downloadManager.repository!
        
        // Create UseCases
        let searchBooksByAuthorUseCase = SearchBooksByAuthorUseCase(bookRepository: bookRepository)
        let playBookUseCase = PlayBookUseCase(api: api, player: player, downloadManager: downloadManager)
        let coverPreloadUseCase = CoverPreloadUseCase(api: api, downloadManager: downloadManager)
        
        // Create ViewModel
        return AuthorDetailViewModel(
            authorName: authorName,
            searchBooksByAuthorUseCase: searchBooksByAuthorUseCase,
            playBookUseCase: playBookUseCase,
            coverPreloadUseCase: coverPreloadUseCase,
            downloadRepository: downloadRepository,
            onBookSelected: onBookSelected
        )
    }
}