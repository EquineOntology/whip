import Foundation

class HistoricalUsageService {
    private let persistenceManager: PersistenceManaging

    init(persistenceManager: PersistenceManaging) {
        self.persistenceManager = persistenceManager
    }

    func getUsageData(for date: Date) throws -> [String: TimeInterval] {
        return try persistenceManager.loadUsageDataForDate(date)
    }

    func getAvailableDates() throws -> [Date] {
        return try persistenceManager.getAvailableDates()
    }
}
