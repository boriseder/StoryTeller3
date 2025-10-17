import SwiftUI

struct DynamicBackground: View {
    @EnvironmentObject var appConfig: AppConfig
    
    @State private var rotation = 0.0
    @State private var scale = 1.0
    @State private var animationPhase = 0.0
    
    // Ruhigere Farbpalette
    let colors: [Color] = [
        Color.blue.opacity(0.3),
        Color.teal.opacity(0.3),
        Color.indigo.opacity(0.3),
        Color.purple.opacity(0.25)
    ]
    
    var body: some View {
            
        switch appConfig.userBackgroundStyle {
        case .dynamic:
            StaticLinearGradientBackground()
        case .light:
            Color.white.ignoresSafeArea()
        case .dark:
            Color.black.ignoresSafeArea()
        }
    }
}

struct StaticLinearGradientBackground: View {
    let colors: [Color] = [
        Color.blue.opacity(0.3),
        Color.teal.opacity(0.3),
        Color.indigo.opacity(0.3),
        Color.purple.opacity(0.25)
    ]
    
    var body: some View {
        ZStack {
            Color.accent.ignoresSafeArea()
            LinearGradient(
                colors: [
                    Color.indigo.opacity(0.55),
                    Color.blue.opacity(0.35),
                    Color.teal.opacity(0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            Color.black.opacity(0.7).ignoresSafeArea()

            // Statische Blobs
            ForEach(0..<6, id: \.self) { index in
                StaticBlobView(index: index, colors: colors)
            }
        }
    }
}

struct StaticBlobView: View {
    let index: Int
    let colors: [Color]
    
    var body: some View {
        let baseColor = colors[index % colors.count]
        let size = 220 + Double(index) * 40
        let offsetX = cos(Double(index) * 0.7) * 120
        let offsetY = sin(Double(index) * 0.9) * 100
        let angle = Double(index) * 45
        let scaleAmount = 1.0 + sin(Double(index)) * 0.12
        
        Circle()
            .fill(
                RadialGradient(
                    colors: [baseColor, baseColor.opacity(0.05), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 200
                )
            )
            .frame(width: size, height: size)
            .offset(x: offsetX, y: offsetY)
            .rotationEffect(.degrees(angle))
            .scaleEffect(scaleAmount)
            .blur(radius: 35)
            .opacity(0.6)
    }
}
