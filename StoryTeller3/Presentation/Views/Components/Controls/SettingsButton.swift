//
//  SettingsButton.swift
//  StoryTeller3
//
//  Created by Boris Eder on 29.09.25.
//


import SwiftUI

struct SettingsButton: View {
    var body: some View {
        Button(action: {
            NotificationCenter.default.post(name: .init("ShowSettings"), object: nil)
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
    }
}