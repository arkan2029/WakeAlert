import Foundation
import UserNotifications
import BackgroundTasks

@MainActor
class AlarmManager: ObservableObject {
    static let shared = AlarmManager()

    @Published var alarms: [Alarm] = []
    @Published var isMonitoringActive = false

    private let healthKitManager = HealthKitManager.shared
    private let sleepAnalyzer = SleepAnalyzer.shared
    private let mlPredictor = MLSleepPredictor.shared
    private let notificationCenter = UNUserNotificationCenter.current()

    // Background task identifier
    private let backgroundTaskIdentifier = "com.alarmapp.sleepmonitor"

    private init() {
        loadAlarms()
    }

    // MARK: - Alarm CRUD Operations

    func addAlarm(_ alarm: Alarm) {
        alarms.append(alarm)
        saveAlarms()
        if alarm.isEnabled {
            scheduleAlarm(alarm)
        }
    }

    func updateAlarm(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
            saveAlarms()

            // Reschedule
            cancelAlarm(alarm)
            if alarm.isEnabled {
                scheduleAlarm(alarm)
            }
        }
    }

    func deleteAlarm(_ alarm: Alarm) {
        cancelAlarm(alarm)
        alarms.removeAll { $0.id == alarm.id }
        saveAlarms()
    }

    func toggleAlarm(_ alarm: Alarm) {
        var updatedAlarm = alarm
        updatedAlarm.isEnabled.toggle()
        updateAlarm(updatedAlarm)
    }

    // MARK: - Alarm Scheduling

    func scheduleAlarm(_ alarm: Alarm) {
        guard alarm.isEnabled else { return }

        Task {
            // Request notification permission if needed
            try? await requestNotificationPermission()

            if alarm.isSleepAware {
                // Schedule sleep-aware alarm
                try? await scheduleSleepAwareAlarm(alarm)
            } else {
                // Schedule regular alarm
                scheduleRegularAlarm(alarm)
            }
        }
    }

    private func scheduleRegularAlarm(_ alarm: Alarm) {
        guard let nextOccurrence = alarm.nextOccurrence() else { return }

        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.body = "Time to wake up!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(alarm.soundName).caf"))
        content.categoryIdentifier = "ALARM_CATEGORY"

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextOccurrence)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: !alarm.repeatDays.isEmpty)
        let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling alarm: \(error)")
            }
        }
    }

    private func scheduleSleepAwareAlarm(_ alarm: Alarm) async throws {
        // First, analyze historical sleep patterns
        let recentNights = try await healthKitManager.fetchRecentSleepNights(count: 7)
        let sleepPattern = sleepAnalyzer.analyzeHistoricalPatterns(nights: recentNights)

        if let pattern = sleepPattern, pattern.hasEnoughData {
            // We have enough historical data, schedule adaptive monitoring
            try await scheduleAdaptiveMonitoring(for: alarm, pattern: pattern)
        } else {
            // Not enough historical data - try ML model fallback
            print("Insufficient sleep data (\(recentNights.count) nights) for pattern-based prediction")
            print("Using ML model as fallback")
            try await scheduleMLBasedAlarm(alarm)
        }
    }

    private func scheduleMLBasedAlarm(_ alarm: Alarm) async throws {
        guard let nextOccurrence = alarm.nextOccurrence() else { return }

        // Estimate bedtime (default to 8 hours before alarm)
        let estimatedBedtime = nextOccurrence.addingTimeInterval(-8 * 60 * 60)

        // Use ML model to suggest optimal wake times
        let suggestions = mlPredictor.suggestWakeTimes(
            around: nextOccurrence,
            bedtime: estimatedBedtime,
            windowMinutes: alarm.maxAdjustmentMinutes
        )

        if let bestSuggestion = suggestions.first, bestSuggestion.confidence > 0.5 {
            // Found a good ML prediction
            print("   ML Prediction: Wake at \(bestSuggestion.time)")
            print("   Predicted stage: \(bestSuggestion.stage.rawValue)")
            print("   Confidence: \(String(format: "%.1f%%", bestSuggestion.confidence * 100))")

            // Schedule notification for ML-suggested time
            let content = UNMutableNotificationContent()
            content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
            content.body = "Smart wake time (ML-powered)"
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(alarm.soundName).caf"))
            content.categoryIdentifier = "ALARM_CATEGORY"

            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: bestSuggestion.time)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: !alarm.repeatDays.isEmpty)

            let request = UNNotificationRequest(
                identifier: alarm.id.uuidString,
                content: content,
                trigger: trigger
            )

            try await notificationCenter.add(request)
        } else {
            // ML model not confident - fall back to regular alarm
            print("   ML model confidence too low, using standard alarm time")
            scheduleRegularAlarm(alarm)
        }
    }

    private func scheduleAdaptiveMonitoring(for alarm: Alarm, pattern: SleepPattern) async throws {
        guard let nextOccurrence = alarm.nextOccurrence() else { return }

        // ADAPTIVE MONITORING: Use historical pattern to determine optimal monitoring window
        // We need to estimate what tonight's sleep will look like
        // For scheduling purposes, we'll make a conservative estimate
        let currentSleepEstimate = estimateCurrentSleepForScheduling(alarm: alarm, pattern: pattern)

        let recommendation = sleepAnalyzer.recommendMonitoringWindow(
            for: nextOccurrence,
            pattern: pattern,
            currentSleepData: currentSleepEstimate
        )

        print("Adaptive Monitoring for '\(alarm.label)':")
        print("   Risk Level: \(recommendation.riskLevel.rawValue)")
        print("   Monitoring Window: \(recommendation.startMinutesBeforeAlarm) minutes before alarm")
        print("   Check Interval: Every \(recommendation.checkIntervalMinutes) minutes")
        print("   Reason: \(recommendation.reason)")
        print("   Battery Impact: \(recommendation.batteryImpact)")

        // Schedule background task to wake app based on adaptive recommendation
        let monitoringStart = nextOccurrence.addingTimeInterval(-Double(recommendation.startMinutesBeforeAlarm) * 60)

        // For now, we'll schedule a notification to trigger monitoring
        // In a full implementation, we'd use BGTaskScheduler for true background execution
        let content = UNMutableNotificationContent()
        content.title = "Smart Sleep Monitoring"
        content.body = recommendation.reason
        content.sound = nil
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "monitoringStart": true,
            "checkInterval": recommendation.checkIntervalMinutes,
            "riskLevel": recommendation.riskLevel.rawValue
        ]

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: monitoringStart)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "monitoring-\(alarm.id.uuidString)",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)

        // Also schedule a fallback regular alarm in case monitoring fails
        scheduleRegularAlarm(alarm)
    }

    // Estimate what tonight's sleep will look like (for scheduling purposes)
    private func estimateCurrentSleepForScheduling(alarm: Alarm, pattern: SleepPattern) -> [SleepPeriod] {
        guard let alarmTime = alarm.nextOccurrence() else { return [] }

        // Estimate bedtime based on historical pattern
        let calendar = Calendar.current
        let bedtimeHour = calendar.component(.hour, from: pattern.averageBedtime)
        let bedtimeMinute = calendar.component(.minute, from: pattern.averageBedtime)

        var estimatedBedtime = calendar.date(
            bySettingHour: bedtimeHour,
            minute: bedtimeMinute,
            second: 0,
            of: alarmTime
        ) ?? alarmTime

        // If bedtime is after alarm time, it was last night
        if estimatedBedtime > alarmTime {
            estimatedBedtime = calendar.date(byAdding: .day, value: -1, to: estimatedBedtime) ?? estimatedBedtime
        }

        // Create estimated sleep periods based on historical cycle pattern
        var estimatedPeriods: [SleepPeriod] = []
        var currentTime = estimatedBedtime
        let cycleCount = Int(pattern.averageSleepDuration / pattern.averageCycleDuration)

        for cycleIndex in 0..<cycleCount {
            // For each cycle, create periods based on learned stage distribution
            for bucketIndex in 0..<10 {
                if let stage = pattern.stageDistribution.buckets[bucketIndex] {
                    let bucketDuration = pattern.averageCycleDuration / 10.0
                    let periodEnd = currentTime.addingTimeInterval(bucketDuration)

                    estimatedPeriods.append(SleepPeriod(
                        stage: stage,
                        startDate: currentTime,
                        endDate: periodEnd
                    ))

                    currentTime = periodEnd
                }
            }
        }

        return estimatedPeriods
    }

    // MARK: - Real-time Sleep Monitoring

    func startMonitoring(for alarm: Alarm, checkIntervalMinutes: Int = 5) async {
        isMonitoringActive = true

        guard let nextOccurrence = alarm.nextOccurrence() else {
            isMonitoringActive = false
            return
        }

        // Fetch historical pattern
        do {
            let recentNights = try await healthKitManager.fetchRecentSleepNights(count: 7)
            guard let pattern = sleepAnalyzer.analyzeHistoricalPatterns(nights: recentNights) else {
                // No pattern available, use original time
                await triggerAlarm(alarm, at: nextOccurrence)
                isMonitoringActive = false
                return
            }

            // Get current sleep data to determine adaptive monitoring parameters
            let currentSleepData = try await healthKitManager.fetchTonightsSleep()
            let recommendation = sleepAnalyzer.recommendMonitoringWindow(
                for: nextOccurrence,
                pattern: pattern,
                currentSleepData: currentSleepData
            )

            print("Active monitoring started:")
            print("   Check interval: \(recommendation.checkIntervalMinutes) minutes")
            print("   Risk level: \(recommendation.riskLevel.rawValue)")

            // Monitor sleep until alarm time
            let monitoringEnd = nextOccurrence
            let maxAdjustment = TimeInterval(alarm.maxAdjustmentMinutes * 60)

            var optimalTime = nextOccurrence
            let checkInterval = recommendation.checkIntervalMinutes

            // Adaptive monitoring loop - check interval based on risk level
            while Date() < monitoringEnd {
                let currentSleepData = try await healthKitManager.fetchTonightsSleep()

                // Find optimal wake time
                optimalTime = sleepAnalyzer.findOptimalWakeTime(
                    targetTime: nextOccurrence,
                    maxAdjustment: maxAdjustment,
                    pattern: pattern,
                    currentSleepData: currentSleepData
                )

                // Log current status
                if let currentStage = try? await healthKitManager.fetchCurrentSleepStage() {
                    print("   Current stage: \(currentStage.rawValue) → Optimal time: \(optimalTime)")
                }

                // If we found a good time and it's now or in the past, trigger alarm
                if optimalTime <= Date() {
                    print("Optimal wake time reached!")
                    await triggerAlarm(alarm, at: optimalTime)
                    isMonitoringActive = false
                    return
                }

                // Adaptive wait - use recommended check interval
                try? await Task.sleep(nanoseconds: UInt64(checkInterval) * 60 * 1_000_000_000)
            }

            // Monitoring period ended, use the optimal time we found
            print("Monitoring window ended, triggering alarm")
            await triggerAlarm(alarm, at: optimalTime)

        } catch {
            print("Error during monitoring: \(error)")
            // Fall back to original time
            await triggerAlarm(alarm, at: nextOccurrence)
        }

        isMonitoringActive = false
    }

    private func triggerAlarm(_ alarm: Alarm, at time: Date) async {
        // Update the alarm with adjusted time
        var updatedAlarm = alarm
        updatedAlarm.adjustedTime = time
        updateAlarm(updatedAlarm)

        // Cancel existing notification and create immediate one
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [alarm.id.uuidString])

        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.body = "Time to wake up!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(alarm.soundName).caf"))
        content.categoryIdentifier = "ALARM_CATEGORY"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)

        try? await notificationCenter.add(request)
    }

    // MARK: - Helper Functions

    private func cancelAlarm(_ alarm: Alarm) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            alarm.id.uuidString,
            "monitoring-\(alarm.id.uuidString)"
        ])
    }

    private func requestNotificationPermission() async throws {
        let settings = await notificationCenter.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            _ = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    // MARK: - Persistence

    private func saveAlarms() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: "alarms")
        }
    }

    private func loadAlarms() {
        if let data = UserDefaults.standard.data(forKey: "alarms"),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: data) {
            alarms = decoded
        }
    }

    // MARK: - Notification Actions

    func setupNotificationActions() {
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze",
            options: []
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Dismiss",
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: "ALARM_CATEGORY",
            actions: [snoozeAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([category])
    }

    func handleSnooze(for alarmId: String) {
        guard let alarm = alarms.first(where: { $0.id.uuidString == alarmId }) else { return }

        // Snooze for 9 minutes (standard iOS snooze time)
        let snoozeTime = Date().addingTimeInterval(9 * 60)

        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.body = "Time to wake up!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(alarm.soundName).caf"))
        content.categoryIdentifier = "ALARM_CATEGORY"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 9 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "snooze-\(alarm.id.uuidString)",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request)
    }
}
