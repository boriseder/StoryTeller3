import SwiftUI

struct LoadingView: View {
    @State var message: String = "Loading..."
    
    var body: some View {
        StateContainer {
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .frame(width: 60, height: 60, alignment: .center)
                
                Text(message)
                    .font(DSText.detail)
                    .foregroundStyle(DSColor.onDark)
                    .frame(height: 24)
            }
            .frame(minWidth: 100, minHeight: 120)
        }
    }
}
