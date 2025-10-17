import SwiftUI

struct LoadingView: View {
    let message: String
    
    init(message: String = "Syncing...") {
        self.message = message
    }
    var body: some View {
        ZStack {
            Color.white.opacity(0.3)
                .frame(width: 360, height: 240)
                .cornerRadius(DSCorners.comfortable)
                .blur(radius: 0.5)
            
            VStack(spacing: DSLayout.contentGap) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Syncing...")
                    .font(DSText.footnote)
                    .foregroundColor(.secondary)

            }
            .frame(width: 60, height: 60)
        }
    }
}

