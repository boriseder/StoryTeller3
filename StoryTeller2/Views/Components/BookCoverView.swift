import SwiftUI
import AVFoundation

struct BookCoverView: View {
    let book: Book
    let api: AudiobookshelfAPI?
    let downloadManager: DownloadManager?
    let size: CGSize
    
    @State private var localCover: UIImage?
    @State private var triedLocal = false
    
    var body: some View {
        ZStack {
            if let cover = localCover {
                Image(uiImage: cover)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .cornerRadius(16)
                    .shadow(radius: 8, y: 4)
            } else if triedLocal, let api = api {
                // Fallback: Online-Cover via AsyncImageWithAuth
                AsyncImageWithAuth(
                    bookId: book.id,
                    baseURL: api.baseURLString,
                    authToken: api.authToken
                ) {
                    placeholderView
                }
                .frame(width: size.width, height: size.height)
                .clipped()
                .cornerRadius(16)
                .shadow(radius: 8, y: 4)
            } else {
                placeholderView
            }
        }
        .onAppear {
            if !triedLocal {
                Task { await loadLocalCover() }
            }
        }
    }
    
    private func loadLocalCover() async {
        guard let downloadManager = downloadManager else {
            triedLocal = true
            return
        }
        
        // 1. Lokale Cover-Datei prüfen
        if let localCoverURL = downloadManager.getLocalCoverURL(for: book.id),
           FileManager.default.fileExists(atPath: localCoverURL.path),
           let localImage = UIImage(contentsOfFile: localCoverURL.path) {
            await MainActor.run { self.localCover = localImage }
            triedLocal = true
            return
        }
        
        // 2. Eingebettetes Cover aus Audio-Dateien prüfen
        let bookDir = downloadManager.bookDirectory(for: book.id)
        if let embeddedCover = await extractEmbeddedCover(from: bookDir) {
            await MainActor.run { self.localCover = embeddedCover }
            triedLocal = true
            return
        }
        
        // 3. Kein lokales Cover → fallback
        triedLocal = true
    }
    
    private func extractEmbeddedCover(from dir: URL) async -> UIImage? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path),
              let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return nil
        }
        
        let audioFiles = contents.filter { ["mp3", "m4a", "mp4"].contains($0.pathExtension.lowercased()) }
        for audioFile in audioFiles {
            let asset = AVAsset(url: audioFile)
            do {
                let metadata = try await asset.load(.commonMetadata)
                if let artworkItem = metadata.first(where: { $0.commonKey?.rawValue == "artwork" }),
                   let data = try await artworkItem.load(.dataValue),
                   let image = UIImage(data: data) {
                    return image
                }
            } catch {
                print("[BookCover] ERROR reading metadata: \(error)")
            }
        }
        return nil
    }
    
    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: size.width * 0.2))
                    .foregroundColor(.white)
                Text(book.title)
                    .font(.system(size: size.width * 0.06, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
            }
        }
        .frame(width: size.width, height: size.height)
        .cornerRadius(16)
        .shadow(radius: 8, y: 4)
    }
}
