import Foundation

protocol PersistenceManaging {
    func saveTimeLimitRules(_ rules: [String: TimeLimit]) throws
    func loadTimeLimitRules() throws -> [String: TimeLimit]

    func saveUsageData(_ data: [String: [String: TimeInterval]]) throws
    func loadUsageData() throws -> [String: [String: TimeInterval]]
    
    func loadUsageDataForDate(_ date: Date) throws -> [String: TimeInterval]
    func getAvailableDates() throws -> [Date]
}
