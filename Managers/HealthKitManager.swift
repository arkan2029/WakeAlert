import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    private init() {}

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

    // Groups sleep periods into nightly sessions
    func fetchRecentSleepNights(count: Int = 7) async throws -> [SleepNight] {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -count, to: now) ?? now

        let allPeriods = try await fetchSleepData(from: startDate, to: now)

        var nightsDict: [Date: [SleepPeriod]] = [:]

        for period in allPeriods {
            // Sleep before noon gets attributed to the previous night's session
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

        let nights = nightsDict.map { date, periods in
            SleepNight(date: date, periods: periods.sorted { $0.startDate < $1.startDate })
        }.sorted { $0.date > $1.date }

        return nights
    }

    // MARK: - Mock Data (commented out - used for ML training dataset generation)
    /*
    func generateMockSleepNights(count: Int) -> [SleepNight] {
        var mockNights: [SleepNight] = []
        let calendar = Calendar.current

        // Create diverse sleep personas
        enum SleepPersona {
            case earlyBird      // 9-10 PM bedtime, 6-7 hours
            case nightOwl       // 12-2 AM bedtime, 6-8 hours
            case regularSleeper // 10-11 PM bedtime, 7-8 hours
            case shortSleeper   // Random bedtime, 5-6 hours
            case longSleeper    // Random bedtime, 8-9 hours
            case irregular      // Highly variable
        }

        for dayOffset in 0..<count {
            let nightDate = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let dayOfWeek = calendar.component(.weekday, from: nightDate)

            // Randomly assign a persona for this night
            let persona: SleepPersona = [.earlyBird, .nightOwl, .regularSleeper, .shortSleeper, .longSleeper, .irregular].randomElement()!

            // Determine bedtime based on persona and day of week
            var bedtimeHour: Int
            var bedtimeMinuteRange: ClosedRange<Int>
            var durationHours: ClosedRange<Int>

            switch persona {
            case .earlyBird:
                bedtimeHour = Int.random(in: 21...22)
                bedtimeMinuteRange = 0...45
                durationHours = 6...7
            case .nightOwl:
                bedtimeHour = dayOfWeek == 1 || dayOfWeek == 7 ? Int.random(in: 0...2) : Int.random(in: 23...24)
                bedtimeMinuteRange = 0...59
                durationHours = 6...8
            case .regularSleeper:
                bedtimeHour = Int.random(in: 22...23)
                bedtimeMinuteRange = 0...45
                durationHours = 7...8
            case .shortSleeper:
                bedtimeHour = Int.random(in: 22...24)
                bedtimeMinuteRange = 0...59
                durationHours = 5...6
            case .longSleeper:
                bedtimeHour = Int.random(in: 21...23)
                bedtimeMinuteRange = 0...59
                durationHours = 8...9
            case .irregular:
                bedtimeHour = Int.random(in: 21...26) // 21-24 (9PM-12AM) or 25-26 (1-2AM)
                if bedtimeHour > 24 { bedtimeHour -= 24 }
                bedtimeMinuteRange = 0...59
                durationHours = 5...9
            }

            // Weekend adjustment (later bedtimes)
            if dayOfWeek == 7 || dayOfWeek == 1 { // Saturday or Sunday
                bedtimeHour += Int.random(in: 0...2)
                if bedtimeHour >= 24 { bedtimeHour -= 24 }
            }

            let bedtime = calendar.date(bySettingHour: bedtimeHour, minute: Int.random(in: bedtimeMinuteRange), second: 0, of: nightDate) ?? nightDate
            let sleepHours = Int.random(in: durationHours)
            let sleepDuration: TimeInterval = Double(sleepHours * 3600 + Int.random(in: 0...1800)) // Add up to 30 min variation

            var periods: [SleepPeriod] = []
            var currentTime = bedtime
            let wakeTime = bedtime.addingTimeInterval(sleepDuration)

            while currentTime < wakeTime {
                let timeAsleep = currentTime.timeIntervalSince(bedtime)
                let progress = timeAsleep / sleepDuration

                let stage: SleepStage
                let duration: TimeInterval

                // More realistic sleep architecture with variation
                let cycleVariation = Double.random(in: 0.8...1.2) // Add 20% variation

                if progress < 0.08 {
                    // Initial light sleep
                    stage = .core
                    duration = TimeInterval(Int.random(in: 5...15) * 60) * cycleVariation
                } else if progress < 0.30 {
                    // First deep sleep period (most deep sleep in first third)
                    stage = Bool.random() ? .deep : .core
                    duration = TimeInterval(Int.random(in: 15...35) * 60) * cycleVariation
                } else if progress < 0.40 {
                    // Transition to first REM
                    stage = .core
                    duration = TimeInterval(Int.random(in: 8...18) * 60) * cycleVariation
                } else if progress < 0.50 {
                    // First REM period
                    stage = .rem
                    duration = TimeInterval(Int.random(in: 5...15) * 60) * cycleVariation
                } else if progress < 0.65 {
                    // Second cycle - less deep sleep
                    stage = [.deep, .core, .core].randomElement()!
                    duration = TimeInterval(Int.random(in: 10...25) * 60) * cycleVariation
                } else if progress < 0.78 {
                    // Second REM period (longer)
                    stage = .rem
                    duration = TimeInterval(Int.random(in: 15...30) * 60) * cycleVariation
                } else if progress < 0.92 {
                    // Final cycle - mostly light and REM
                    stage = [.core, .rem, .rem].randomElement()!
                    duration = TimeInterval(Int.random(in: 10...20) * 60) * cycleVariation
                } else {
                    // Morning awakening preparation
                    stage = [.core, .awake].randomElement()!
                    duration = TimeInterval(Int.random(in: 3...10) * 60) * cycleVariation
                }

                let endTime = min(currentTime.addingTimeInterval(duration), wakeTime)
                periods.append(SleepPeriod(stage: stage, startDate: currentTime, endDate: endTime))
                currentTime = endTime

                // Random micro-awakenings (more realistic)
                if Double.random(in: 0...1) < 0.15 && progress > 0.2 && progress < 0.95 {
                    let awakeDuration = TimeInterval(Int.random(in: 1...5) * 60)
                    let awakeEndTime = min(currentTime.addingTimeInterval(awakeDuration), wakeTime)
                    periods.append(SleepPeriod(stage: .awake, startDate: currentTime, endDate: awakeEndTime))
                    currentTime = awakeEndTime
                }
            }

            let sleepNight = SleepNight(date: calendar.startOfDay(for: nightDate), periods: periods)
            mockNights.append(sleepNight)
        }

        return mockNights.sorted { $0.date > $1.date }
    }
    */

    func fetchCurrentSleepStage() async throws -> SleepStage? {
        let now = Date()
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now

        let periods = try await fetchSleepData(from: oneHourAgo, to: now)

        let currentPeriod = periods.last { period in
            period.startDate <= now && period.endDate >= now
        }

        return currentPeriod?.stage
    }

    // Grabs tonight's sleep data (from 6 PM onward)
    func fetchTonightsSleep() async throws -> [SleepPeriod] {
        let calendar = Calendar.current
        let now = Date()

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
