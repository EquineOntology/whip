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

    func saveTimeLimitRules(_ rules: [String: TimeInterval]) -> Result<Void, Error> {
        do {
            let data = try JSONEncoder().encode(rules)
            try data.write(to: rulesFileURL, options: .atomic)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func loadTimeLimitRules() -> Result<[String: TimeInterval], Error> {
        do {
            guard fileManager.fileExists(atPath: rulesFileURL.path) else {
                logger.warning("No file found at \(self.rulesFileURL.path). Returning empty ruleset.")
                return .success([:])
            }
            let data = try Data(contentsOf: rulesFileURL)
            let rules = try JSONDecoder().decode([String: TimeInterval].self, from: data)
            logger.debug("Data loaded: \(rules)")
            return .success(rules)
        } catch {
            logger.error("Could nod load rules: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    func saveUsageData(_ data: [String: [String: TimeInterval]]) -> Result<Void, Error> {
        do {
            let encodedData = try JSONEncoder().encode(data)
            try encodedData.write(to: usageFileURL, options: .atomic)
            return .success(())
        } catch {
            logger.error("Could nod save usage data: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    func loadUsageData() -> Result<[String: [String: TimeInterval]], Error> {
        do {
            guard fileManager.fileExists(atPath: usageFileURL.path) else {
                logger.warning("No file found at \(self.usageFileURL.path). Returning empty dataset.")
                return .success([:])
            }
            let data = try Data(contentsOf: usageFileURL)
            let usageData = try JSONDecoder().decode([String: [String: TimeInterval]].self, from: data)
            logger.debug("Data loaded: \(usageData)")
            return .success(usageData)
        } catch {
            logger.error("Could nod load usage data: \(error.localizedDescription)")
            return .failure(error)
        }
    }
}
