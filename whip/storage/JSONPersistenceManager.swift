import Foundation
import OSLog

class JSONPersistenceManager: PersistenceManaging {
    private let fileManager = FileManager.default
    private let rulesFileURL: URL
    private let usageFileURL: URL
    
    private let logger = Logger(subsystem: "dev.fratta.whip", category: "JSONPersistenceManager")

    init() {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        rulesFileURL = documentsDirectory.appendingPathComponent("timeLimitRules.json")
        usageFileURL = documentsDirectory.appendingPathComponent("usageData.json")
    }

    func saveTimeLimitRules(_ rules: [String: TimeLimit]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(rules)
        try data.write(to: rulesFileURL, options: .atomic)
        logger.debug("Saved rules to file: \(String(data: data, encoding: .utf8) ?? "Unable to read data")")
    }

    func loadTimeLimitRules() throws -> [String: TimeLimit] {
        guard fileManager.fileExists(atPath: rulesFileURL.path) else {
            logger.warning("No file found at \(self.rulesFileURL.path). Returning empty ruleset.")
            return [:]
        }
        let data = try Data(contentsOf: rulesFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rules = try decoder.decode([String: TimeLimit].self, from: data)
        logger.debug("Loaded time limits: \(rules)")
        return rules
    }

    func saveUsageData(_ data: [String: [String: TimeInterval]]) throws {
        let encodedData = try JSONEncoder().encode(data)
        try encodedData.write(to: usageFileURL, options: .atomic)
    }

    func loadUsageData() throws -> [String: [String: TimeInterval]] {
        guard fileManager.fileExists(atPath: usageFileURL.path) else {
            logger.warning("No file found at \(self.usageFileURL.path). Returning empty dataset.")
            return [:]
        }
        let data = try Data(contentsOf: usageFileURL)
        return try JSONDecoder().decode([String: [String: TimeInterval]].self, from: data)
    }
    
    func loadUsageDataForDate(_ date: Date) throws -> [String: TimeInterval] {
        let dateString = TimeUtils.dateAsString(date)
        let allUsageData = try loadUsageData()
        return allUsageData[dateString] ?? [:]
    }

    func getAvailableDates() throws -> [Date] {
        let allUsageData = try loadUsageData()
        return allUsageData.keys.compactMap { TimeUtils.dateFromString($0) }.sorted()
    }
}
