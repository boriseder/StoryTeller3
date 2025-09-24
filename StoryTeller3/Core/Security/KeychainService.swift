//
//  KeychainService.swift
//  StoryTeller3
//
//  Created by Boris Eder on 24.09.25.
//


//
//  KeychainService.swift
//  StoryTeller3
//

import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    
    private let service = "com.storyteller3.audiobookshelf"
    
    private init() {}
    
    // MARK: - Password Storage
    
    func storePassword(_ password: String, for username: String) throws {
        let data = Data(password.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.storageError(status)
        }
    }
    
    func getPassword(for username: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw KeychainError.retrievalError(status)
        }
        
        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionError
        }
        
        return password
    }
    
    func deletePassword(for username: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deletionError(status)
        }
    }
    
    // MARK: - Token Storage
    
    func storeToken(_ token: String, for username: String) throws {
        let data = Data(token.utf8)
        let account = "\(username)_token"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Delete existing token first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.storageError(status)
        }
    }
    
    func getToken(for username: String) throws -> String {
        let account = "\(username)_token"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw KeychainError.retrievalError(status)
        }
        
        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionError
        }
        
        return token
    }
    
    func deleteToken(for username: String) throws {
        let account = "\(username)_token"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deletionError(status)
        }
    }
    
    // MARK: - Clear All Credentials
    
    func clearAllCredentials() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deletionError(status)
        }
    }
}

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case storageError(OSStatus)
    case retrievalError(OSStatus)
    case deletionError(OSStatus)
    case dataConversionError
    
    var errorDescription: String? {
        switch self {
        case .storageError(let status):
            return "Failed to store in keychain: \(status)"
        case .retrievalError(let status):
            return "Failed to retrieve from keychain: \(status)"
        case .deletionError(let status):
            return "Failed to delete from keychain: \(status)"
        case .dataConversionError:
            return "Failed to convert keychain data"
        }
    }
}