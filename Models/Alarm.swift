import Foundation

struct Alarm: Identifiable, Codable {
    let id: UUID
    var time: Date // User's desired wake time
    var label: String
    var isEnabled: Bool
    var repeatDays: Set<Weekday> // Which days this alarm repeats
    var isSleepAware: Bool // Whether to use sleep-aware adjustment
    var soundName: String
    var snoozeEnabled: Bool

    // Sleep-aware properties
    var adjustedTime: Date? // Actual time alarm will ring (adjusted based on sleep)
    var maxAdjustmentMinutes: Int // Maximum minutes to adjust (default 15)

    init(
        id: UUID = UUID(),
        time: Date = Date(),
        label: String = "Alarm",
        isEnabled: Bool = true,
        repeatDays: Set<Weekday> = [],
        isSleepAware: Bool = true,
        soundName: String = "default",
        snoozeEnabled: Bool = true,
        maxAdjustmentMinutes: Int = 15
    ) {
        self.id = id
        self.time = time
        self.label = label
        self.isEnabled = isEnabled
        self.repeatDays = repeatDays
        self.isSleepAware = isSleepAware
        self.soundName = soundName
        self.snoozeEnabled = snoozeEnabled
        self.maxAdjustmentMinutes = maxAdjustmentMinutes
        self.adjustedTime = nil
    }

    // Get the next occurrence of this alarm
    func nextOccurrence(from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: time)

        if repeatDays.isEmpty {
            // One-time alarm
            var nextDate = calendar.date(bySettingHour: components.hour ?? 0,
                                        minute: components.minute ?? 0,
                                        second: 0,
                                        of: date) ?? date

            // If the time has passed today, schedule for tomorrow
            if nextDate <= date {
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            }

            return nextDate
        } else {
            // Repeating alarm - find next matching day
            let currentWeekday = Weekday.from(date: date)
            let sortedDays = repeatDays.sorted { $0.rawValue < $1.rawValue }

            // Check if alarm time is later today
            let todayAlarmTime = calendar.date(bySettingHour: components.hour ?? 0,
                                              minute: components.minute ?? 0,
                                              second: 0,
                                              of: date) ?? date

            if repeatDays.contains(currentWeekday) && todayAlarmTime > date {
                return todayAlarmTime
            }

            // Find next day in the week
            for daysToAdd in 1...7 {
                guard let futureDate = calendar.date(byAdding: .day, value: daysToAdd, to: date) else { continue }
                let futureWeekday = Weekday.from(date: futureDate)

                if repeatDays.contains(futureWeekday) {
                    return calendar.date(bySettingHour: components.hour ?? 0,
                                       minute: components.minute ?? 0,
                                       second: 0,
                                       of: futureDate)
                }
            }

            return nil
        }
    }

    // Get the effective alarm time (adjusted or original)
    var effectiveTime: Date {
        adjustedTime ?? time
    }
}

enum Weekday: Int, Codable, Comparable, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    static func from(date: Date) -> Weekday {
        let calendar = Calendar.current
        let weekdayInt = calendar.component(.weekday, from: date)
        return Weekday(rawValue: weekdayInt) ?? .sunday
    }
}
