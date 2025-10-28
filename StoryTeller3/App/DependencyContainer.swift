//
//  DependencyContainer.swift
//  StoryTeller3
//
//  Created by Boris Eder on 28.10.25.
//


//
//  DependencyContainer.swift
//  StoryTeller3
//
//  Created on 2025
//

import Foundation
import SwiftUI

/// Central dependency container managing all infrastructure services
/// This is the single source of truth for dependency injection
@MainActor
class DependencyContainer: ObservableObject {
    
    // MARK: - Core Infrastructure
    let audioPlayer: AudioPlayer
    let audiobookshelfClient: AudiobookshelfClient
    let downloadManager: DownloadManager
    let networkService: NetworkService
    let authenticationService: AuthenticationService
    
    // MARK: - Managers
    let coverCacheManager: CoverCacheManager
    let coverDownloadManager: CoverDownloadManager
    let continueReadingManager: ContinueReadingManager
    let playerStateManager: PlayerStateManager
    
    // MARK: - Repositories
    let bookRepository: BookRepository
    let libraryRepository: LibraryRepository
    let downloadRepository: DownloadRepository
    let playbackRepository: PlaybackRepository
    let settingsRepository: SettingsRepository
    
    // MARK: - Services
    let keychainService: KeychainService
    let networkMonitor: NetworkMonitor
    let appStateManager: AppStateManager
    
    // MARK: - Use Cases
    let fetchBooksUseCase: FetchBooksUseCase
    let fetchLibrariesUseCase: FetchLibrariesUseCase
    let fetchSeriesUseCase: FetchSeriesUseCase
    let fetchSeriesBooksUseCase: FetchSeriesBooksUseCase
    let fetchPersonalizedSectionsUseCase: FetchPersonalizedSectionsUseCase
    let downloadBookUseCase: DownloadBookUseCase
    let playBookUseCase: PlayBookUseCase
    let syncProgressUseCase: SyncProgressUseCase
    let authenticationUseCase: AuthenticationUseCase
    let testConnectionUseCase: TestConnectionUseCase
    let loadCredentialsUseCase: LoadCredentialsUseCase
    let saveCredentialsUseCase: SaveCredentialsUseCase
    let logoutUseCase: LogoutUseCase
    let searchBooksByAuthorUseCase: SearchBooksByAuthorUseCase
    let calculateStorageUseCase: CalculateStorageUseCase
    let clearCacheUseCase: ClearCacheUseCase
    let convertLibraryItemUseCase: ConvertLibraryItemUseCase
    let coverPreloadUseCase: CoverPreloadUseCase
    let fetchLibraryStatsUseCase: FetchLibraryStatsUseCase
    
    // MARK: - Initialization
    init() {
        // Initialize core services
        self.keychainService = KeychainService()
        self.networkMonitor = NetworkMonitor()
        
        // Initialize networking
        self.networkService = NetworkService()
        self.authenticationService = AuthenticationService(
            networkService: networkService,
            keychainService: keychainService
        )
        
        // Initialize Audiobookshelf client
        self.audiobookshelfClient = AudiobookshelfClient(
            authService: authenticationService,
            networkService: networkService
        )
        
        // Initialize repositories
        self.bookRepository = BookRepository()
        self.libraryRepository = LibraryRepository()
        self.downloadRepository = DownloadRepository()
        self.playbackRepository = PlaybackRepository()
        self.settingsRepository = SettingsRepository()
        
        // Initialize managers
        self.coverCacheManager = CoverCacheManager()
        self.coverDownloadManager = CoverDownloadManager(
            networkService: networkService
        )
        self.downloadManager = DownloadManager(
            client: audiobookshelfClient,
            downloadRepository: downloadRepository
        )
        
        self.playerStateManager = PlayerStateManager()
        
        // Initialize audio player
        self.audioPlayer = AudioPlayer(
            client: audiobookshelfClient,
            playerStateManager: playerStateManager
        )
        
        self.continueReadingManager = ContinueReadingManager(
            client: audiobookshelfClient,
            audioPlayer: audioPlayer
        )
        
        // Initialize app state manager
        self.appStateManager = AppStateManager(
            libraryRepository: libraryRepository,
            settingsRepository: settingsRepository
        )
        
        // Initialize Use Cases
        self.fetchBooksUseCase = FetchBooksUseCase(
            client: audiobookshelfClient,
            bookRepository: bookRepository
        )
        
        self.fetchLibrariesUseCase = FetchLibrariesUseCase(
            client: audiobookshelfClient,
            libraryRepository: libraryRepository
        )
        
        self.fetchSeriesUseCase = FetchSeriesUseCase(
            client: audiobookshelfClient
        )
        
        self.fetchSeriesBooksUseCase = FetchSeriesBooksUseCase(
            client: audiobookshelfClient
        )
        
        self.fetchPersonalizedSectionsUseCase = FetchPersonalizedSectionsUseCase(
            client: audiobookshelfClient
        )
        
        self.downloadBookUseCase = DownloadBookUseCase(
            downloadManager: downloadManager
        )
        
        self.playBookUseCase = PlayBookUseCase(
            audioPlayer: audioPlayer,
            downloadManager: downloadManager
        )
        
        self.syncProgressUseCase = SyncProgressUseCase(
            client: audiobookshelfClient,
            playbackRepository: playbackRepository
        )
        
        self.authenticationUseCase = AuthenticationUseCase(
            authService: authenticationService
        )
        
        self.testConnectionUseCase = TestConnectionUseCase(
            authService: authenticationService
        )
        
        self.loadCredentialsUseCase = LoadCredentialsUseCase(
            keychainService: keychainService
        )
        
        self.saveCredentialsUseCase = SaveCredentialsUseCase(
            keychainService: keychainService
        )
        
        self.logoutUseCase = LogoutUseCase(
            authService: authenticationService,
            audioPlayer: audioPlayer,
            appStateManager: appStateManager
        )
        
        self.searchBooksByAuthorUseCase = SearchBooksByAuthorUseCase(
            client: audiobookshelfClient
        )
        
        self.calculateStorageUseCase = CalculateStorageUseCase(
            downloadRepository: downloadRepository
        )
        
        self.clearCacheUseCase = ClearCacheUseCase(
            coverCacheManager: coverCacheManager,
            downloadRepository: downloadRepository
        )
        
        self.convertLibraryItemUseCase = ConvertLibraryItemUseCase()
        
        self.coverPreloadUseCase = CoverPreloadUseCase(
            coverDownloadManager: coverDownloadManager
        )
        
        self.fetchLibraryStatsUseCase = FetchLibraryStatsUseCase(
            client: audiobookshelfClient
        )
    }
    
    // MARK: - Factory Methods
    
    /// Creates a ViewModelFactory with all necessary dependencies
    func makeViewModelFactory() -> ViewModelFactory {
        ViewModelFactory(container: self)
    }
}
