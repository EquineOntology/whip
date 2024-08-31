import Foundation

protocol PersistenceManaging {
    func saveTimeLimitRules(_ rules: [String: TimeLimit]) -> Result<Void, Error>
    func loadTimeLimitRules() -> Result<[String: TimeLimit], Error>
    
    func saveUsageData(_ data: [String: [String: TimeInterval]]) -> Result<Void, Error>
    func loadUsageData() -> Result<[String: [String: TimeInterval]], Error>
}
