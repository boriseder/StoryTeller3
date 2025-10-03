import SwiftUI

struct LoadingView: View {
    var message: String = "Loading..."
    
    var body: some View {
        StateContainer {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(width: 60, height: 60) // Fixed size prevents jumping
                
                Text(message)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }
}
