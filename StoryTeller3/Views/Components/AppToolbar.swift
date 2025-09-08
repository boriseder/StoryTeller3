//
//  AppToolbar.swift
//  StoryTeller3
//
//  Created by Boris Eder on 08.09.25.
//


import SwiftUI

// MARK: - Zentralisierter Toolbar Manager
struct AppToolbar: ToolbarContent {
    let showSortButton: Bool
    let selectedSortOption: Binding<LibraryView.SortOption>?
    let onSettingsTapped: () -> Void
    let onSortChanged: ((LibraryView.SortOption) -> Void)?
    
    init(
        showSortButton: Bool = false,
        selectedSortOption: Binding<LibraryView.SortOption>? = nil,
        onSettingsTapped: @escaping () -> Void,
        onSortChanged: ((LibraryView.SortOption) -> Void)? = nil
    ) {
        self.showSortButton = showSortButton
        self.selectedSortOption = selectedSortOption
        self.onSettingsTapped = onSettingsTapped
        self.onSortChanged = onSortChanged
    }
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                // Sort Button (nur wenn benötigt)
                if showSortButton, let selectedSort = selectedSortOption {
                    sortButton(selectedSort: selectedSort)
                }
                
                // Settings Button (immer vorhanden)
                settingsButton
            }
        }
    }
    
    private func sortButton(selectedSort: Binding<LibraryView.SortOption>) -> some View {
        Menu {
            ForEach(LibraryView.SortOption.allCases, id: \.self) { option in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSort.wrappedValue = option
                        onSortChanged?(option)
                    }
                }) {
                    Label(option.rawValue, systemImage: option.systemImage)
                    if selectedSort.wrappedValue == option {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 16))
                .foregroundColor(.primary)
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

// MARK: - Convenience Extensions
extension View {
    func appToolbar(
        showSortButton: Bool = false,
        selectedSortOption: Binding<LibraryView.SortOption>? = nil,
        onSettingsTapped: @escaping () -> Void,
        onSortChanged: ((LibraryView.SortOption) -> Void)? = nil
    ) -> some View {
        self.toolbar {
            AppToolbar(
                showSortButton: showSortButton,
                selectedSortOption: selectedSortOption,
                onSettingsTapped: onSettingsTapped,
                onSortChanged: onSortChanged
            )
        }
    }
}