import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    private init() {}

    // Request HealthKit authorization
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            await MainActor.run {
                self.isAuthorized = true
            }
        } catch {
            throw HealthKitError.authorizationFailed(error)
        }
    }

    // Fetch sleep data for a specific date range
    func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> [SleepPeriod] {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let periods = sleepSamples.compactMap { sample -> SleepPeriod? in
                    guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value) else {
                        return nil
                    }

                    let stage = SleepStage.from(hkValue: sleepValue)
                    return SleepPeriod(
                        stage: stage,
                        startDate: sample.startDate,
                        endDate: sample.endDate
                    )
                }

                continuation.resume(returning: periods)
            }

            healthStore.execute(query)
        }
    }

    // Fetch last N nights of sleep data
    func fetchRecentSleepNights(count: Int = 7) async throws -> [SleepNight] {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -count, to: now) ?? now

        let allPeriods = try await fetchSleepData(from: startDate, to: now)

        // Group periods by night
        var nightsDict: [Date: [SleepPeriod]] = [:]

        for period in allPeriods {
            // Determine which night this period belongs to
            // Consider anything before 12 PM as part of the previous night
            let calendar = Calendar.current
            var periodDate = period.startDate

            let hour = calendar.component(.hour, from: periodDate)
            if hour < 12 {
                periodDate = calendar.date(byAdding: .day, value: -1, to: periodDate) ?? periodDate
            }

            let nightDate = calendar.startOfDay(for: periodDate)

            if nightsDict[nightDate] == nil {
                nightsDict[nightDate] = []
            }
            nightsDict[nightDate]?.append(period)
        }

        // Convert to SleepNight objects
        let nights = nightsDict.map { date, periods in
            SleepNight(date: date, periods: periods.sorted { $0.startDate < $1.startDate })
        }.sorted { $0.date > $1.date } // Most recent first

        return nights
    }

    // Fetch current sleep stage (for real-time monitoring)
    func fetchCurrentSleepStage() async throws -> SleepStage? {
        let now = Date()
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now

        let periods = try await fetchSleepData(from: oneHourAgo, to: now)

        // Find the most recent period that contains the current time
        let currentPeriod = periods.last { period in
            period.startDate <= now && period.endDate >= now
        }

        return currentPeriod?.stage
    }

    // Get sleep data for tonight (used for real-time monitoring)
    func fetchTonightsSleep() async throws -> [SleepPeriod] {
        let calendar = Calendar.current
        let now = Date()

        // Start from 6 PM yesterday to capture bedtime
        var startDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
        if startDate > now {
            startDate = calendar.date(byAdding: .day, value: -1, to: startDate) ?? startDate
        }

        return try await fetchSleepData(from: startDate, to: now)
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationFailed(Error)
    case queryFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationFailed(let error):
            return "Failed to authorize HealthKit: \(error.localizedDescription)"
        case .queryFailed(let error):
            return "Failed to query HealthKit: \(error.localizedDescription)"
        }
    }
}
