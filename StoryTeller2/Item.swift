//
//  Item.swift
//  StoryTeller2
//
//  Created by Boris Eder on 18.08.25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
