import Foundation

@MainActor
struct SettingsViewModelFactory {
    static func create(container: DependencyContainer? = nil) -> SettingsViewModel {
        let container = container ?? DependencyContainer.shared
        return SettingsViewModel(
            testConnectionUseCase: container.makeTestConnectionUseCase(),
            authenticationUseCase: container.makeAuthenticationUseCase(),
            fetchLibrariesUseCase: container.makeFetchLibrariesUseCase(),
            calculateStorageUseCase: container.makeCalculateStorageUseCase(),
            clearCacheUseCase: container.makeClearCacheUseCase(),
            saveCredentialsUseCase: container.makeSaveCredentialsUseCase(),
            loadCredentialsUseCase: container.makeLoadCredentialsUseCase(),
            logoutUseCase: container.makeLogoutUseCase(),
            serverValidator: container.serverValidator,
            diagnosticsService: container.diagnosticsService,
            coverCacheManager: container.coverCacheManager,
            downloadManager: container.downloadManager
        )
    }
}
