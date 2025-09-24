import SwiftUI

struct DynamicMusicBackground: View {
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
        ZStack {
            // Weicher Hintergrund
            LinearGradient(
                colors: [
                    Color.indigo.opacity(0.35),
                    Color.blue.opacity(0.3),
                    Color.teal.opacity(0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Ruhigere Blobs (gleiches Layout wie vorher)
            ForEach(0..<6, id: \.self) { index in
                MusicBlobView(
                    index: index,
                    colors: colors,
                    rotation: rotation,
                    scale: scale,
                    animationPhase: animationPhase
                )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                scale = 1.1
            }
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
        }
    }
}

// MARK: - Music Blob View (unverändert, nur wirkt durch neue Farben ruhiger)
struct MusicBlobView: View {
    let index: Int
    let colors: [Color]
    let rotation: Double
    let scale: Double
    let animationPhase: Double
    
    var body: some View {
        let baseColor = colors[index % colors.count]
        let size = 220 + Double(index) * 40
        let offsetX = cos(animationPhase + Double(index) * 0.7) * 120
        let offsetY = sin(animationPhase + Double(index) * 0.9) * 100
        let angle = rotation + Double(index) * 45
        let scaleAmount = scale + sin(animationPhase + Double(index)) * 0.12
        
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
