import Foundation

/// Use Case for converting LibraryItem to Book
/// Encapsulates the conversion logic previously accessed via api.converter
protocol ConvertLibraryItemUseCaseProtocol {
    func execute(item: LibraryItem) -> Book?
}

class ConvertLibraryItemUseCase: ConvertLibraryItemUseCaseProtocol {
    private let converter: BookConverterProtocol
    
    init(converter: BookConverterProtocol) {
        self.converter = converter
    }
    
    func execute(item: LibraryItem) -> Book? {
        return converter.convertLibraryItemToBook(item)
    }
}
