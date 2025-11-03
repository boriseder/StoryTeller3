import SwiftUI

enum LibraryUIState: Equatable {
    case loading
    case loadingFromCache
//    case error(String)
    case offline(cachedItemCount: Int)
    case empty
    case noDownloads
    case noSearchResults
    case content
}

enum HomeUIState: Equatable {
    case loading
    case loadingFromCache
//    case error(String)
    case offline(hasCachedData: Bool)
    case empty
    case noDownloads
    case content
}

enum SeriesUIState: Equatable {
    case loading
    case loadingFromCache
    case error(String)
    case offline(cachedItemCount: Int)
    case empty
    case noDownloads
    case noSearchResults
    case content
}

// Add: Data source tracking
enum DataSource: Equatable {
    case network(timestamp: Date)
    case cache(timestamp: Date)
    case local
    
    var isFromNetwork: Bool {
        if case .network = self { return true }
        return false
    }
    
    var timestamp: Date {
        switch self {
        case .network(let date), .cache(let date):
            return date
        case .local:
            return Date()
        }
    }
}
