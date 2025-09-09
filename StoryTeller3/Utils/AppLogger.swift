//
//  AppLogger.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//


import os

enum AppLogger {
    static let debug = Logger(subsystem: "com.meinefirma.StoryTeller3", category: "Debug")
    static let network = Logger(subsystem: "com.meinefirma.StoryTeller3", category: "Network")
}