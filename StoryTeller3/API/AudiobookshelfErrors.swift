import Foundation

// MARK: - Error Handling
enum AudiobookshelfError: LocalizedError {
    case invalidURL(String)
    case networkError(Error)
    case noData
    case decodingError(Error)
    case libraryNotFound(String)
    case unauthorized
    case serverError(Int, String?)
    case bookNotFound(String)
    case missingLibraryItemId
    case invalidResponse
    case noLibrarySelected
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Ungültige URL: \(url)"
        case .networkError(let error):
            return "Netzwerkfehler: \(error.localizedDescription)"
        case .noData:
            return "Keine Daten vom Server erhalten"
        case .decodingError(let error):
            return "Fehler beim Verarbeiten der Server-Antwort: \(error.localizedDescription)"
        case .libraryNotFound(let name):
            return "Bibliothek '\(name)' nicht gefunden"
        case .unauthorized:
            return "Nicht autorisiert - überprüfen Sie Ihren API-Schlüssel"
        case .serverError(let code, let message):
            return "Server-Fehler (\(code)): \(message ?? "Unbekannt")"
        case .bookNotFound(let id):
            return "Buch mit ID '\(id)' nicht gefunden"
        case .missingLibraryItemId:
            return "Library Item ID fehlt"
        case .invalidResponse:
            return "Ungültige Server-Antwort"
        case .noLibrarySelected:
            return "No library selected"
        }
    }
}
