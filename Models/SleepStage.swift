import Foundation
import HealthKit

// Sleep stages as classified by Apple Watch
enum SleepStage: String, Codable {
    case awake = "Awake"
    case core = "Core"      // N1/N2 - Light sleep (IDEAL for waking)
    case deep = "Deep"      // N3 - Deep sleep (AVOID)
    case rem = "REM"        // REM sleep (OK for waking)
    case unknown = "Unknown"

    // Priority for waking up (lower is better)
    var wakePriority: Int {
        switch self {
        case .core: return 1    // Best
        case .rem: return 2     // Good
        case .awake: return 3   // OK
        case .deep: return 4    // Worst
        case .unknown: return 5
        }
    }

    // Convert from HKCategoryValueSleepAnalysis
    static func from(hkValue: HKCategoryValueSleepAnalysis) -> SleepStage {
        switch hkValue {
        case .asleepCore:
            return .core
        case .asleepDeep:
            return .deep
        case .asleepREM:
            return .rem
        case .awake:
            return .awake
        default:
            return .unknown
        }
    }
}

// Represents a sleep stage period
struct SleepPeriod: Identifiable, Codable {
    let id: UUID
    let stage: SleepStage
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    init(id: UUID = UUID(), stage: SleepStage, startDate: Date, endDate: Date) {
        self.id = id
        self.stage = stage
        self.startDate = startDate
        self.endDate = endDate
    }
}

// A full night's sleep data
struct SleepNight: Identifiable, Codable {
    let id: UUID
    let date: Date // Date of the night (bedtime date)
    let periods: [SleepPeriod]

    var totalSleepTime: TimeInterval {
        periods.filter { $0.stage != .awake }.reduce(0) { $0 + $1.duration }
    }

    var bedtime: Date? {
        periods.first?.startDate
    }

    var wakeTime: Date? {
        periods.last?.endDate
    }

    init(id: UUID = UUID(), date: Date, periods: [SleepPeriod]) {
        self.id = id
        self.date = date
        self.periods = periods
    }
}
