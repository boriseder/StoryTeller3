//
//  STateTypes.swift
//  StoryTeller3
//
//  Created by Boris Eder on 23.09.25.
//

import SwiftUI

enum LibraryUIState: Equatable {
    case loading
    case error(String)
    case empty
    case noDownloads
    case noSearchResults
    case content
}

enum HomeUIState: Equatable {
    case loading
    case error(String)
    case empty
    case noDownloads
    case content
}
