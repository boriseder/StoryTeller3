//
//  SettingsButton 2.swift
//  StoryTeller3
//
//  Created by Boris Eder on 24.11.25.
//



import SwiftUI
 
struct BookmarkButton: View {
    var body: some View {
        Button(action: {
            NotificationCenter.default.post(name: .init("showBookmarks"), object: nil)
        }) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
    }
}
