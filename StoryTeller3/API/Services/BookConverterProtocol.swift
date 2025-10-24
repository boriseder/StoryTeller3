import Foundation

protocol BookConverterProtocol {
    func convertLibraryItemToBook(_ item: LibraryItem) -> Book?
}
