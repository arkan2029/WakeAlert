import Foundation
import HealthKit

enum SleepStage: String, Codable {
    case awake = "Awake"
    case core = "Core"
    case deep = "Deep"
    case rem = "REM"
    case unknown = "Unknown"

    // Lower = better time to wake up
    var wakePriority: Int {
        switch self {
        case .awake: return 1
        case .core: return 2
        case .rem: return 3
        case .deep: return 4
        case .unknown: return 5
        }
    }

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

struct SleepNight: Identifiable, Codable {
    let id: UUID
    let date: Date
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
