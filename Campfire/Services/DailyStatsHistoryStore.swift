import Foundation
import OSLog

protocol DailyStatsHistoryStoring {
    func profileStartDate() -> Date
    func loadHistory() -> [DailyWalkingStats]
    func save(_ records: [DailyWalkingStats])
    func upsert(_ records: [DailyWalkingStats])
    func lifetimeStats(from records: [DailyWalkingStats]) -> ProfileLifetimeStats
}

struct DailyStatsHistoryStore: DailyStatsHistoryStoring {
    static let shared = DailyStatsHistoryStore()

    private static let maxStoredDays = 370
    private static let historyKey = "campfire_daily_stats_history"
    private static let profileStartDateKey = "campfire_profile_start_date"
    private static let logger = Logger(subsystem: "com.ficho.Campfire", category: "DailyStatsHistoryStore")

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func profileStartDate() -> Date {
        if let date = defaults.object(forKey: Self.profileStartDateKey) as? Date {
            return dayKey(for: date)
        }

        let startDate = dayKey(for: Date())
        defaults.set(startDate, forKey: Self.profileStartDateKey)
        Self.logger.debug("Saved Campfire profile start date: \(startDate, privacy: .public)")
        return startDate
    }

    func loadHistory() -> [DailyWalkingStats] {
        guard let data = defaults.data(forKey: Self.historyKey) else {
            Self.logger.debug("Loaded daily stats history: 0 records")
            return []
        }

        do {
            let records = try decoder.decode([DailyWalkingStats].self, from: data)
            let normalizedRecords = normalized(records, startDate: profileStartDate())
            Self.logger.debug("Loaded daily stats history: \(normalizedRecords.count) records")
            return normalizedRecords
        } catch {
            Self.logger.warning("Unable to decode daily stats history: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func save(_ records: [DailyWalkingStats]) {
        do {
            let data = try encoder.encode(normalized(records, startDate: profileStartDate()))
            defaults.set(data, forKey: Self.historyKey)
        } catch {
            Self.logger.warning("Unable to encode daily stats history: \(error.localizedDescription, privacy: .public)")
        }
    }

    func upsert(_ records: [DailyWalkingStats]) {
        var recordsByDay = Dictionary(
            uniqueKeysWithValues: loadHistory().map { (dayKey(for: $0.date), $0) }
        )

        for record in records {
            recordsByDay[dayKey(for: record.date)] = record
        }

        save(Array(recordsByDay.values))
    }

    func lifetimeStats(from records: [DailyWalkingStats]) -> ProfileLifetimeStats {
        let normalizedRecords = normalized(records, startDate: profileStartDate())

        return ProfileLifetimeStats(
            lifetimeSticks: normalizedRecords.reduce(0) { $0 + $1.sticksCollected },
            totalSteps: normalizedRecords.reduce(0) { $0 + $1.steps },
            totalActiveCalories: normalizedRecords.reduce(0) { $0 + $1.activeCalories },
            firesCompleted: normalizedRecords.filter(\.hasCompletedFire).count,
            currentStreak: currentStreak(from: normalizedRecords),
            bestStreak: bestStreak(from: normalizedRecords)
        )
    }

    private func currentStreak(from records: [DailyWalkingStats]) -> Int {
        let completedFireDays = completedFireDaySet(from: records)
        guard !completedFireDays.isEmpty else { return 0 }

        let today = dayKey(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let anchorDay: Date

        if completedFireDays.contains(today) {
            anchorDay = today
        } else if completedFireDays.contains(yesterday) {
            anchorDay = yesterday
        } else {
            return 0
        }

        var streak = 0
        var currentDay = anchorDay

        while completedFireDays.contains(currentDay) {
            streak += 1

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                break
            }

            currentDay = previousDay
        }

        return streak
    }

    private func bestStreak(from records: [DailyWalkingStats]) -> Int {
        let sortedCompletedFireDays = completedFireDaySet(from: records).sorted()
        guard !sortedCompletedFireDays.isEmpty else { return 0 }

        var best = 1
        var current = 1

        for index in sortedCompletedFireDays.indices.dropFirst() {
            let previousDay = sortedCompletedFireDays[sortedCompletedFireDays.index(before: index)]
            let day = sortedCompletedFireDays[index]
            let expectedDay = calendar.date(byAdding: .day, value: 1, to: previousDay)

            if expectedDay == day {
                current += 1
            } else {
                best = max(best, current)
                current = 1
            }
        }

        return max(best, current)
    }

    private func completedFireDaySet(from records: [DailyWalkingStats]) -> Set<Date> {
        Set(records.filter(\.hasCompletedFire).map { dayKey(for: $0.date) })
    }

    private func normalized(_ records: [DailyWalkingStats], startDate: Date) -> [DailyWalkingStats] {
        var recordsByDay: [Date: DailyWalkingStats] = [:]

        for record in records {
            recordsByDay[dayKey(for: record.date)] = record
        }

        let sortedRecords = recordsByDay.values.sorted { $0.date < $1.date }
        let campfireStartDate = dayKey(for: startDate)
        let retentionStartDate = calendar.date(
            byAdding: .day,
            value: -Self.maxStoredDays,
            to: calendar.startOfDay(for: Date())
        ) ?? campfireStartDate
        let cutoffDate = max(campfireStartDate, retentionStartDate)

        return sortedRecords.filter { $0.date >= cutoffDate }
    }

    private func dayKey(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}
