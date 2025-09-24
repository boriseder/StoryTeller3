//
//  IdentifiableWrappers.swift
//  StoryTeller3
//
//  Add this file to your project to support sheet presentations

import Foundation

// MARK: - Identifiable String Wrapper for Sheet Presentation
struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
    
    init(_ value: String) {
        self.value = value
    }
}

// MARK: - Sheet item creation helpers
extension String {
    func asIdentifiable() -> IdentifiableString {
        IdentifiableString(self)
    }
}
