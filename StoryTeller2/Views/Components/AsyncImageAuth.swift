import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Authenticated AsyncImage
struct AsyncImageWithAuth: View {
    private let url: URL?
    private let authToken: String
    private let placeholder: AnyView
    
    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var hasError = false
    
    init(url: URL?, authToken: String, @ViewBuilder placeholder: () -> some View) {
        self.url = url
        self.authToken = authToken
        self.placeholder = AnyView(placeholder())
    }
    
    init(bookId: String, baseURL: String, authToken: String, @ViewBuilder placeholder: () -> some View) {
        self.url = URL(string: "\(baseURL)/api/items/\(bookId)/cover")
        self.authToken = authToken
        self.placeholder = AnyView(placeholder())
    }
    
    var body: some View {
        Group {
            if let imageData = imageData {
                createImage(from: imageData)
            } else if hasError || url == nil {
                placeholder
            } else if isLoading {
                placeholder.overlay(
                    ProgressView()
                        .scaleEffect(0.8)
                )
            } else {
                placeholder
            }
        }
        .task {
            await loadImage()
        }
    }
    
    @ViewBuilder
    private func createImage(from data: Data) -> some View {
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
        #elseif canImport(AppKit)
        if let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
        #endif
    }
    
    @MainActor
    private func loadImage() async {
        guard let url = url else {
            hasError = true
            isLoading = false
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 10.0
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                hasError = true
                isLoading = false
                return
            }
            
            imageData = data
            isLoading = false
            
        } catch {
            hasError = true
            isLoading = false
            print("Fehler beim Laden des Cover-Bildes: \(error)")
        }
    }
}