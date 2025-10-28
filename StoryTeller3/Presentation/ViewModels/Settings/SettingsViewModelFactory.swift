import Foundation

@MainActor
struct SettingsViewModelFactory {
    static func create(container: DependencyContainer) -> SettingsViewModel {
        SettingsViewModel(
            testConnectionUseCase: container.testConnectionUseCase,
            authenticationUseCase: container.authenticationUseCase,
            loadCredentialsUseCase: container.loadCredentialsUseCase,
            saveCredentialsUseCase: container.saveCredentialsUseCase,
            logoutUseCase: container.logoutUseCase,
            calculateStorageUseCase: container.calculateStorageUseCase,
            clearCacheUseCase: container.clearCacheUseCase
        )
    }
}
