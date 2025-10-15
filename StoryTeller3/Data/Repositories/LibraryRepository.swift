import Foundation

// MARK: - Repository Protocol
protocol LibraryRepositoryProtocol {
    func getLibraries() async throws -> [Library]
    func getSelectedLibrary() async throws -> Library?
    func selectLibrary(_ libraryId: String)
    func clearSelection()
}

// MARK: - Library Repository Implementation
class LibraryRepository: LibraryRepositoryProtocol {
    
    private let api: AudiobookshelfAPI
    private let settingsRepository: SettingsRepositoryProtocol
    private var cachedLibraries: [Library]?
    
    init(
        api: AudiobookshelfAPI,
        settingsRepository: SettingsRepositoryProtocol = SettingsRepository()
    ) {
        self.api = api
        self.settingsRepository = settingsRepository
    }
    
    // MARK: - Public Methods
    
    func getLibraries() async throws -> [Library] {
        if let cached = cachedLibraries, !cached.isEmpty {
            AppLogger.debug.debug("[LibraryRepository] Returning \(cached.count) cached libraries")
            return cached
        }
        
        do {
            let libraries = try await api.fetchLibraries()
            cachedLibraries = libraries
            
            AppLogger.debug.debug("[LibraryRepository] Fetched \(libraries.count) libraries")
            
            return libraries
            
        } catch let urlError as URLError {
            throw RepositoryError.networkError(urlError)
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(decodingError)
        } catch {
            throw RepositoryError.networkError(error)
        }
    }
    
    func getSelectedLibrary() async throws -> Library? {
        guard let selectedId = settingsRepository.getSelectedLibraryId() else {
            AppLogger.debug.debug("[LibraryRepository] No library selected")
            return nil
        }
        
        let libraries = try await getLibraries()
        
        if let selected = libraries.first(where: { $0.id == selectedId }) {
            AppLogger.debug.debug("[LibraryRepository] Found selected library: \(selected.name)")
            return selected
        }
        
        if let defaultLibrary = libraries.first(where: { $0.name.lowercased().contains("default") }) {
            AppLogger.debug.debug("[LibraryRepository] No match, using default library: \(defaultLibrary.name)")
            selectLibrary(defaultLibrary.id)
            return defaultLibrary
        }
        
        if let firstLibrary = libraries.first {
            AppLogger.debug.debug("[LibraryRepository] No match, using first library: \(firstLibrary.name)")
            selectLibrary(firstLibrary.id)
            return firstLibrary
        }
        
        return nil
    }
    
    func selectLibrary(_ libraryId: String) {
        settingsRepository.saveSelectedLibraryId(libraryId)
        AppLogger.debug.debug("[LibraryRepository] Selected library: \(libraryId)")
    }
    
    func clearSelection() {
        settingsRepository.saveSelectedLibraryId(nil)
        AppLogger.debug.debug("[LibraryRepository] Cleared library selection")
    }
    
    func clearCache() {
        cachedLibraries = nil
        AppLogger.debug.debug("[LibraryRepository] Cleared library cache")
    }
}
