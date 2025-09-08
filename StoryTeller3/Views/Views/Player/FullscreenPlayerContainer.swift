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
                // Main Content - TabView with permanent TabBar
                content
                
                // MiniPlayer - appears above content but leaves TabBar visible
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
                        .padding(.bottom, 49) // Space for TabBar + safe area
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .zIndex(1)
                }
                
                // Custom Fullscreen Player - Overlay that respects TabBar
                if playerStateManager.showFullscreenPlayer {
                    // Background overlay
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .zIndex(2)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                playerStateManager.dismissFullscreen()
                            }
                        }
                    
                    // Player content that leaves space for TabBar
                    VStack(spacing: 0) {
                        fullscreenPlayerContent
                            .frame(height: geometry.size.height - 90) // Leave space for TabBar
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: -5)
                        
                        // Spacer for TabBar area
                        Spacer()
                            .frame(height: 10)
                    }
                    .offset(y: dragOffset)
                    .gesture(swipeDownGesture)
                    .zIndex(3)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
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
    
    private var fullscreenPlayerContent: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                
                if let api = api {
                    PlayerView(player: player, api: api)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                dismissButton
                            }
                        }
                }
            }
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
                    let translation = max(0, value.translation.height)
                    dragOffset = translation
                }
            }
            .onEnded { value in
                isDragging = false
                
                if value.translation.height > 150 || value.predictedEndTranslation.height > 300 {
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
