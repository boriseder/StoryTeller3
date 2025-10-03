import SwiftUI

// MARK: - Fullscreen Player Container
struct FullscreenPlayerContainer<Content: View>: View {
    let content: Content
    @ObservedObject var player: AudioPlayer
    @ObservedObject var playerStateManager: PlayerStateManager
    let api: AudiobookshelfAPI?
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    init(
        player: AudioPlayer,
        playerStateManager: PlayerStateManager,
        api: AudiobookshelfAPI?,
        @ViewBuilder content: () -> Content
    ) {
        self.player = player
        self.playerStateManager = playerStateManager
        self.api = api
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main Content - TabView with TabBar
                content
                
                // Global MiniPlayer - appears over content but TabBar remains visible
                if playerStateManager.showMiniPlayer && player.book != nil && !playerStateManager.showFullscreenPlayer {
                    VStack {
                        Spacer()
                        
                        MiniPlayerView(
                            player: player,
                            api: api,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    playerStateManager.showFullscreen()
                                }
                            },
                            onDismiss: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    playerStateManager.hideMiniPlayer()
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 49)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .zIndex(1)
                }
                
                // Fullscreen Player - true fullscreen implementation
                if playerStateManager.showFullscreenPlayer {
                    NavigationStack {
                        ZStack {
                            // Fullscreen background
                            Color(.systemBackground)
                                .ignoresSafeArea(.all)
                            
                            if let api = api {
                                PlayerView(player: player, api: api)
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .navigationBarLeading) {
                                            dismissButton
                                        }
                                    }
                            } else {
                                // Fallback when no API available
                                VStack(spacing: 20) {
                                    Image(systemName: "wifi.exclamationmark")
                                        .font(.system(size: 60))
                                        .foregroundColor(.secondary)
                                    
                                    Text("Keine Verbindung zum Server")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                    
                                    Button("Schließen") {
                                        withAnimation(.easeInOut(duration: 0.4)) {
                                            playerStateManager.dismissFullscreen()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding()
                            }
                        }
                    }
                    .offset(y: dragOffset)
                    .gesture(swipeDownGesture)
                    .zIndex(100) // Ensure it's above everything
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom),
                        removal: .move(edge: .bottom)
                    ))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: playerStateManager.showMiniPlayer)
        .animation(.easeInOut(duration: 0.4), value: playerStateManager.showFullscreenPlayer)
        .onChange(of: player.book) { _, newBook in
            playerStateManager.updatePlayerState(hasBook: newBook != nil)
        }
    }
    
    private var dismissButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.4)) {
                playerStateManager.dismissFullscreen()
            }
        }) {
            Image(systemName: "chevron.down")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Circle())
        }
    }
    
    private var swipeDownGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging && value.translation.height > 0 {
                    isDragging = true
                }
                
                if isDragging {
                    // Only allow small drag offset for fullscreen
                    let translation = max(0, min(value.translation.height, 100))
                    dragOffset = translation
                }
            }
            .onEnded { value in
                isDragging = false
                
                if value.translation.height > 80 || value.predictedEndTranslation.height > 200 {
                    // Dismiss fullscreen player
                    withAnimation(.easeInOut(duration: 0.4)) {
                        playerStateManager.dismissFullscreen()
                        dragOffset = 0
                    }
                } else {
                    // Snap back
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }
}
