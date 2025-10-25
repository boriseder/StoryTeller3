//
//  LibraryHelpers.swift
//  StoryTeller3
//
//  Created by Boris Eder on 29.09.25.
//


//
//  LibraryHelpers.swift
//  StoryTeller3
//
//  Centralized library selection utilities
//

import Foundation

enum LibraryHelpers {
    
    /// Get currently selected library ID from UserDefaults
    /// - Returns: Library ID or nil if none selected
    static func getCurrentLibraryId() -> String? {
        UserDefaults.standard.string(forKey: "selected_library_id")
    }
    
    /// Get currently selected library ID or throw error
    /// - Throws: AudiobookshelfError.noLibrarySelected
    /// - Returns: Library ID string
    static func requireLibraryId() throws -> String {
        guard let id = getCurrentLibraryId() else {
            throw AudiobookshelfError.noLibrarySelected
        }
        return id
    }
    
    /// Save library selection to UserDefaults
    /// - Parameter libraryId: Library ID to save, or nil to clear
    static func saveLibrarySelection(_ libraryId: String?) {
        if let id = libraryId {
            UserDefaults.standard.set(id, forKey: "selected_library_id")
        } else {
            UserDefaults.standard.removeObject(forKey: "selected_library_id")
        }
    }
}