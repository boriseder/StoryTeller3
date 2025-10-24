import Foundation

class AudiobookshelfClient {
    let connection: ConnectionServiceProtocol
    let libraries: LibraryServiceProtocol
    let books: BookServiceProtocol
    let series: SeriesServiceProtocol
    let personalized: PersonalizedServiceProtocol
    let progress: ProgressServiceProtocol
    let converter: BookConverterProtocol
    
    private let apiConfig: APIConfig    // Dirty hack #1

    init(
        baseURL: String,
        authToken: String,
        networkService: NetworkService = DefaultNetworkService()
    ) {
        let baseConfig = APIConfig(baseURL: baseURL, authToken: authToken)
        let converter = DefaultBookConverter()
        let rateLimiter = RateLimiter(minimumInterval: 0.1)
        
        self.connection = DefaultConnectionService(config: baseConfig, networkService: networkService)
        self.libraries = DefaultLibraryService(config: baseConfig, networkService: networkService)
        self.books = DefaultBookService(config: baseConfig, networkService: networkService, converter: converter, rateLimiter: rateLimiter)
        self.series = DefaultSeriesService(config: baseConfig, networkService: networkService, converter: converter)
        self.personalized = DefaultPersonalizedService(config: baseConfig, networkService: networkService)
        self.progress = DefaultProgressService(config: baseConfig, networkService: networkService)
        self.converter = converter
        
        
        //Quick & Dirty hack
        self.apiConfig = baseConfig  // speichern
        
    }
    
    var baseURLString: String { apiConfig.baseURL }
    var authToken: String { apiConfig.authToken }

}
