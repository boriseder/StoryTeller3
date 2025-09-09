import SwiftUI

// MARK: - Vereinfachte Toolbar
struct AppToolbar: ToolbarContent {
    let showSortButton: Bool
    let onSettingsTapped: () -> Void
    
    init(
        showSortButton: Bool = false,
        onSettingsTapped: @escaping () -> Void
    ) {
        self.showSortButton = showSortButton
        self.onSettingsTapped = onSettingsTapped
    }
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                // Sort Button (Placeholder - jede View implementiert ihr eigenes)
                if showSortButton {
                    // Wird von der jeweiligen View überschrieben
                    EmptyView()
                }
                
                // Settings Button (immer vorhanden)
                settingsButton
            }
        }
    }
    
    private var settingsButton: some View {
        Button(action: onSettingsTapped) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Convenience Extension
extension View {
    func appToolbar(
        showSortButton: Bool = false,
        onSettingsTapped: @escaping () -> Void
    ) -> some View {
        self.toolbar {
            AppToolbar(
                showSortButton: showSortButton,
                onSettingsTapped: onSettingsTapped
            )
        }
    }
}
