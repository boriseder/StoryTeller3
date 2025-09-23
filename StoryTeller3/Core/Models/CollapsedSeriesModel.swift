//
//  CollapsedSeries.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//


import Foundation

// MARK: - CollapsedSeries Model
struct CollapsedSeries: Codable {
    let id: String
    let name: String
    let nameIgnorePrefix: String?
    let numBooks: Int
}
