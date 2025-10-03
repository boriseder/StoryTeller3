//
//  StateContainer.swift
//  StoryTeller3
//
//  Created by Boris Eder on 03.10.25.
//
import SwiftUI

// MARK: - State Container with Consistent Layout
struct StateContainer<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    
    init(
        backgroundColor: Color = Color(.systemBackground),
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
