//
//  RateLimiter.swift
//  StoryTeller3
//
//  Created by Boris Eder on 03.10.25.
//
import SwiftUI

actor RateLimiter {
    private var lastRequestTime: Date?
    private let minimumInterval: TimeInterval
    
    init(minimumInterval: TimeInterval = 0.1) {
        self.minimumInterval = minimumInterval
    }
    
    func waitIfNeeded() async {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minimumInterval {
                let delay = minimumInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }
}
