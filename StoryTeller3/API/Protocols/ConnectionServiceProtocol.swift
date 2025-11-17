import Foundation

protocol ConnectionServiceProtocol {
    func testConnection() async throws -> ConnectionTestResult
    func checkHealth() async -> Bool
}
