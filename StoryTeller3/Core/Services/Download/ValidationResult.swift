//
//  ValidationResult.swift
//  StoryTeller3
//
//  Created by Boris Eder on 24.10.25.
//


import Foundation

// MARK: - Validation Result

/// Result of validation
enum ValidationResult {
    case valid
    case invalid(reason: String)
    
    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

// MARK: - Protocol

/// Service responsible for validating downloaded content
protocol DownloadValidationService {
    /// Validates the integrity of a downloaded book
    func validateBookIntegrity(bookId: String, storageService: DownloadStorageService) -> ValidationResult
    
    /// Validates a single file
    func validateFile(at url: URL, minimumSize: Int64) -> Bool
}

// MARK: - Default Implementation

final class DefaultDownloadValidationService: DownloadValidationService {
    
    // MARK: - Properties
    private let fileManager: FileManager
    private let minimumCoverSize: Int64 = 1024 // 1KB
    private let minimumAudioSize: Int64 = 10_240 // 10KB
    
    // MARK: - Initialization
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    // MARK: - DownloadValidationService
    
    func validateBookIntegrity(bookId: String, storageService: DownloadStorageService) -> ValidationResult {
        let bookDir = storageService.bookDirectory(for: bookId)
        let metadataFile = bookDir.appendingPathComponent("metadata.json")
        
        // Check metadata exists
        guard fileManager.fileExists(atPath: metadataFile.path) else {
            return .invalid(reason: "Metadata file missing")
        }
        
        // Load and validate book metadata
        guard let data = try? Data(contentsOf: metadataFile),
              let book = try? JSONDecoder().decode(Book.self, from: data) else {
            return .invalid(reason: "Invalid metadata file")
        }
        
        // Validate all audio files exist and have minimum size
        let audioDir = storageService.audioDirectory(for: bookId)
        for (index, _) in book.chapters.enumerated() {
            let audioFile = audioDir.appendingPathComponent("chapter_\(index).mp3")
            
            if !fileManager.fileExists(atPath: audioFile.path) {
                return .invalid(reason: "Missing chapter \(index + 1)")
            }
            
            if !validateFile(at: audioFile, minimumSize: minimumAudioSize) {
                return .invalid(reason: "Chapter \(index + 1) is corrupted")
            }
        }
        
        // Validate cover exists and has minimum size
        let coverFile = bookDir.appendingPathComponent("cover.jpg")
        if !fileManager.fileExists(atPath: coverFile.path) {
            return .invalid(reason: "Cover image missing")
        }
        
        if !validateFile(at: coverFile, minimumSize: minimumCoverSize) {
            return .invalid(reason: "Cover image is corrupted")
        }
        
        return .valid
    }
    
    func validateFile(at url: URL, minimumSize: Int64) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                return fileSize >= minimumSize
            }
        } catch {
            AppLogger.general.error("[DownloadValidation] Failed to get file attributes: \(error)")
        }
        
        return false
    }
}
