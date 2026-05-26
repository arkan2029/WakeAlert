import Foundation

class SleepAnalyzer {
    static let shared = SleepAnalyzer()

    private init() {}

    /// Analyzes historical sleep data to extract personalized sleep patterns
    /// - Parameter nights: Array of sleep nights to analyze (minimum 3 required)
    /// - Returns: SleepPattern if sufficient data exists, nil otherwise
    func analyzeHistoricalPatterns(nights: [SleepNight]) -> SleepPattern? {
        guard nights.count >= 3 else { return nil }

        var cycleDurations: [TimeInterval] = []
        var bedtimes: [Date] = []
        var totalSleepTimes: [TimeInterval] = []
        var stageDistributions: [CycleStageDistribution] = []

        for night in nights {
            if let bedtime = night.bedtime {
                bedtimes.append(bedtime)
            }
            totalSleepTimes.append(night.totalSleepTime)

            let cycles = detectSleepCycles(in: night.periods)
            cycleDurations.append(contentsOf: cycles)

            let distributions = analyzeCycleStageDistributions(in: night.periods)
            stageDistributions.append(contentsOf: distributions)
        }

        let avgBedtime = averageTimeOfDay(from: bedtimes)
        let avgSleepDuration = totalSleepTimes.reduce(0, +) / Double(totalSleepTimes.count)
        let avgCycleDuration = cycleDurations.isEmpty ? 90 * 60 : cycleDurations.reduce(0, +) / Double(cycleDurations.count)

        let avgStageDistribution = averageStageDistribution(from: stageDistributions)

        return SleepPattern(
            averageBedtime: avgBedtime,
            averageSleepDuration: avgSleepDuration,
            averageCycleDuration: avgCycleDuration,
            stageDistribution: avgStageDistribution,
            nightsAnalyzed: nights.count
        )
    }

    /// Analyzes sleep stage distribution patterns within detected cycles
    private func analyzeCycleStageDistributions(in periods: [SleepPeriod]) -> [CycleStageDistribution] {
        var distributions: [CycleStageDistribution] = []
        var cycleStart: Date?
        var cyclePeriods: [SleepPeriod] = []

        for period in periods {
            // Detect cycle boundaries (Core -> Deep/REM -> Core pattern)
            if period.stage == .core && cycleStart == nil {
                cycleStart = period.startDate
                cyclePeriods = [period]
            } else if let start = cycleStart {
                cyclePeriods.append(period)

                // End cycle when we hit the next Core period after Deep/REM
                let hasDeepOrRem = cyclePeriods.contains { $0.stage == .deep || $0.stage == .rem }
                if period.stage == .core && hasDeepOrRem && cyclePeriods.count > 3 {
                    // Calculate distribution for this cycle
                    let cycleDuration = period.endDate.timeIntervalSince(start)
                    if cycleDuration >= 60 * 60 && cycleDuration <= 120 * 60 { // Valid 60-120 min cycle
                        let distribution = calculateStageDistribution(periods: cyclePeriods, cycleDuration: cycleDuration)
                        distributions.append(distribution)
                    }

                    // Start new cycle
                    cycleStart = period.startDate
                    cyclePeriods = [period]
                }
            }
        }

        return distributions
    }

    // Calculate what percentage of cycle time is spent in each stage at different positions
    private func calculateStageDistribution(periods: [SleepPeriod], cycleDuration: TimeInterval) -> CycleStageDistribution {
        guard let cycleStart = periods.first?.startDate else {
            return CycleStageDistribution.default
        }

        // Divide cycle into 10% buckets and track dominant stage in each
        var stagesByBucket: [Int: [SleepStage]] = [:]

        for period in periods {
            let periodStart = period.startDate.timeIntervalSince(cycleStart)
            let periodEnd = period.endDate.timeIntervalSince(cycleStart)

            // Determine which buckets this period overlaps
            let startBucket = Int((periodStart / cycleDuration) * 10)
            let endBucket = Int((periodEnd / cycleDuration) * 10)

            for bucket in startBucket...min(endBucket, 9) {
                if stagesByBucket[bucket] == nil {
                    stagesByBucket[bucket] = []
                }
                stagesByBucket[bucket]?.append(period.stage)
            }
        }

        // For each bucket, determine the dominant stage
        var buckets: [SleepStage?] = Array(repeating: nil, count: 10)
        for bucket in 0..<10 {
            if let stages = stagesByBucket[bucket], !stages.isEmpty {
                // Find most common stage in this bucket
                let stageCounts = Dictionary(grouping: stages, by: { $0 }).mapValues { $0.count }
                buckets[bucket] = stageCounts.max(by: { $0.value < $1.value })?.key
            }
        }

        return CycleStageDistribution(buckets: buckets)
    }

    // Average multiple cycle distributions to find the user's typical pattern
    private func averageStageDistribution(from distributions: [CycleStageDistribution]) -> CycleStageDistribution {
        guard !distributions.isEmpty else {
            return CycleStageDistribution.default
        }

        var buckets: [SleepStage?] = Array(repeating: nil, count: 10)

        // For each bucket position, find the most common stage across all cycles
        for bucketIndex in 0..<10 {
            let stagesInBucket = distributions.compactMap { $0.buckets[bucketIndex] }
            if !stagesInBucket.isEmpty {
                let stageCounts = Dictionary(grouping: stagesInBucket, by: { $0 }).mapValues { $0.count }
                buckets[bucketIndex] = stageCounts.max(by: { $0.value < $1.value })?.key
            }
        }

        return CycleStageDistribution(buckets: buckets)
    }

    // Detect individual sleep cycles in a night's sleep
    private func detectSleepCycles(in periods: [SleepPeriod]) -> [TimeInterval] {
        var cycles: [TimeInterval] = []
        var cycleStart: Date?

        for period in periods {
            // A new cycle typically starts with Core or Light sleep after Deep or REM
            if period.stage == .core && cycleStart == nil {
                cycleStart = period.startDate
            } else if period.stage == .deep || period.stage == .rem {
                if let start = cycleStart {
                    let duration = period.endDate.timeIntervalSince(start)
                    if duration >= 60 * 60 && duration <= 120 * 60 { // 60-120 min cycles
                        cycles.append(duration)
                    }
                    cycleStart = nil
                }
            }
        }

        return cycles
    }

    // Calculate average time of day from multiple dates
    private func averageTimeOfDay(from dates: [Date]) -> Date {
        guard !dates.isEmpty else { return Date() }

        let calendar = Calendar.current
        var totalMinutes = 0

        for date in dates {
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            totalMinutes += hour * 60 + minute
        }

        let avgMinutes = totalMinutes / dates.count
        let avgHour = avgMinutes / 60
        let avgMinute = avgMinutes % 60

        return calendar.date(bySettingHour: avgHour, minute: avgMinute, second: 0, of: Date()) ?? Date()
    }

    // Predict sleep stage at a specific time based on patterns
    func predictSleepStage(
        at targetTime: Date,
        pattern: SleepPattern,
        currentSleepData: [SleepPeriod]
    ) -> SleepStage? {
        guard !currentSleepData.isEmpty else { return nil }

        // PRIORITY 1: If we have recent actual data (within 30 mins), use that
        let recentPeriod = currentSleepData.last { period in
            abs(period.endDate.timeIntervalSince(targetTime)) < 30 * 60
        }

        if let recent = recentPeriod {
            return recent.stage
        }

        // PRIORITY 2: Use current night's data to find position in cycle
        guard let firstSleep = currentSleepData.first(where: { $0.stage != .awake }) else {
            return nil
        }

        let timeAsleep = targetTime.timeIntervalSince(firstSleep.startDate)
        let cycleProgress = timeAsleep.truncatingRemainder(dividingBy: pattern.averageCycleDuration)
        let cyclePercentage = cycleProgress / pattern.averageCycleDuration

        // PRIORITY 3: Use the user's learned cycle pattern from historical data
        // Convert percentage to bucket index (0-9)
        let bucketIndex = min(Int(cyclePercentage * 10), 9)

        // Look up what stage the user is typically in at this point in their cycle
        if let predictedStage = pattern.stageDistribution.buckets[bucketIndex] {
            return predictedStage
        }

        // FALLBACK: If no learned pattern for this bucket, look at nearby buckets
        for offset in 1...3 {
            if bucketIndex - offset >= 0,
               let stage = pattern.stageDistribution.buckets[bucketIndex - offset] {
                return stage
            }
            if bucketIndex + offset < 10,
               let stage = pattern.stageDistribution.buckets[bucketIndex + offset] {
                return stage
            }
        }

        // LAST RESORT: Use generic pattern only if no user data available
        return pattern.stageDistribution.defaultStageForBucket(bucketIndex)
    }

    // Find the best wake time within a window
    func findOptimalWakeTime(
        targetTime: Date,
        maxAdjustment: TimeInterval,
        pattern: SleepPattern,
        currentSleepData: [SleepPeriod]
    ) -> Date {
        let calendar = Calendar.current
        let windowStart = targetTime.addingTimeInterval(-maxAdjustment)
        let windowEnd = targetTime.addingTimeInterval(maxAdjustment)

        var bestTime = targetTime
        var bestPriority = Int.max

        // Sample times every 5 minutes in the window
        var currentTime = windowStart
        while currentTime <= windowEnd {
            if let predictedStage = predictSleepStage(at: currentTime, pattern: pattern, currentSleepData: currentSleepData) {
                if predictedStage.wakePriority < bestPriority {
                    bestTime = currentTime
                    bestPriority = predictedStage.wakePriority
                }

                // If we found Core sleep, that's optimal
                if predictedStage == .core {
                    break
                }
            }

            currentTime = calendar.date(byAdding: .minute, value: 5, to: currentTime) ?? currentTime
        }

        return bestTime
    }

    // Analyze tonight's sleep in real-time
    func analyzeRealtimeSleep(periods: [SleepPeriod]) -> RealtimeSleepAnalysis {
        guard let currentPeriod = periods.last else {
            return RealtimeSleepAnalysis(currentStage: .unknown, cyclePosition: 0, confidence: 0)
        }

        let currentStage = currentPeriod.stage

        // Estimate position in current cycle
        let recentCycles = detectSleepCycles(in: periods)
        let avgCycle = recentCycles.isEmpty ? 90 * 60 : recentCycles.reduce(0, +) / Double(recentCycles.count)

        // Find start of current cycle
        var cycleStart = currentPeriod.startDate
        for i in stride(from: periods.count - 1, through: 0, by: -1) {
            if periods[i].stage == .core {
                cycleStart = periods[i].startDate
                break
            }
        }

        let cyclePosition = currentPeriod.endDate.timeIntervalSince(cycleStart) / avgCycle

        // Confidence based on amount of data
        let confidence = min(Double(periods.count) / 20.0, 1.0)

        return RealtimeSleepAnalysis(
            currentStage: currentStage,
            cyclePosition: cyclePosition,
            confidence: confidence
        )
    }

    // ADAPTIVE MONITORING: Determine optimal monitoring window based on predicted sleep stages
    func recommendMonitoringWindow(
        for alarmTime: Date,
        pattern: SleepPattern,
        currentSleepData: [SleepPeriod]
    ) -> MonitoringRecommendation {
        // Sample sleep stages at multiple points before alarm to assess risk
        let checkTimes = [
            alarmTime.addingTimeInterval(-30 * 60),  // 30 min before
            alarmTime.addingTimeInterval(-20 * 60),  // 20 min before
            alarmTime.addingTimeInterval(-10 * 60),  // 10 min before
            alarmTime                                 // Alarm time itself
        ]

        var deepSleepCount = 0
        var coreREMCount = 0

        for checkTime in checkTimes {
            if let predictedStage = predictSleepStage(at: checkTime, pattern: pattern, currentSleepData: currentSleepData) {
                if predictedStage == .deep {
                    deepSleepCount += 1
                } else if predictedStage == .core || predictedStage == .rem {
                    coreREMCount += 1
                }
            }
        }

        // Decision logic for monitoring window
        let recommendation: MonitoringRecommendation

        if deepSleepCount >= 3 {
            // High risk: User predicted to be in Deep sleep around alarm time
            // Need longer monitoring to find earlier wake window
            recommendation = MonitoringRecommendation(
                startMinutesBeforeAlarm: 90,
                checkIntervalMinutes: 3,
                reason: "Deep sleep predicted near alarm time - extended monitoring to find earlier Core/REM window",
                riskLevel: .high
            )
        } else if deepSleepCount >= 2 {
            // Medium risk: Some Deep sleep predicted
            // Standard monitoring window
            recommendation = MonitoringRecommendation(
                startMinutesBeforeAlarm: 60,
                checkIntervalMinutes: 4,
                reason: "Some Deep sleep predicted - moderate monitoring to track transitions",
                riskLevel: .medium
            )
        } else if deepSleepCount >= 1 {
            // Low risk: Minimal Deep sleep
            // Shorter monitoring, but still cautious
            recommendation = MonitoringRecommendation(
                startMinutesBeforeAlarm: 45,
                checkIntervalMinutes: 5,
                reason: "Minimal Deep sleep predicted - standard monitoring window",
                riskLevel: .low
            )
        } else {
            // No risk: Core/REM predicted throughout
            // Minimal monitoring needed
            recommendation = MonitoringRecommendation(
                startMinutesBeforeAlarm: 30,
                checkIntervalMinutes: 5,
                reason: "Core/REM sleep predicted - light monitoring to confirm optimal time",
                riskLevel: .minimal
            )
        }

        return recommendation
    }

    // Predict if user will be in Deep sleep within a time window
    func isDeepSleepLikely(
        around targetTime: Date,
        windowMinutes: Int,
        pattern: SleepPattern,
        currentSleepData: [SleepPeriod]
    ) -> Bool {
        let windowStart = targetTime.addingTimeInterval(-Double(windowMinutes) * 60)
        let windowEnd = targetTime.addingTimeInterval(Double(windowMinutes) * 60)

        // Sample at 5-minute intervals within window
        var currentTime = windowStart
        var deepSleepSamples = 0
        var totalSamples = 0

        while currentTime <= windowEnd {
            if let stage = predictSleepStage(at: currentTime, pattern: pattern, currentSleepData: currentSleepData) {
                totalSamples += 1
                if stage == .deep {
                    deepSleepSamples += 1
                }
            }
            currentTime = currentTime.addingTimeInterval(5 * 60)
        }

        // Consider Deep sleep "likely" if >40% of samples are Deep
        guard totalSamples > 0 else { return false }
        let deepPercentage = Double(deepSleepSamples) / Double(totalSamples)
        return deepPercentage > 0.4
    }

    /// Exports sleep data to CSV format for ML model training
    /// - Parameter nights: Sleep nights to export
    /// - Returns: CSV string with time-based features and sleep stage labels
    func exportTrainingData(nights: [SleepNight]) -> String {
        var csv: [String] = []
        csv.append("hour,minute,day_of_week,minutes_since_bedtime,days_of_sleep_data,actual_stage")
        for night in nights {
            guard let bedtime = night.bedtime else { continue }
            let samplingInterval: TimeInterval = 5 * 60
            var currentTime = bedtime
            let endTime = night.wakeTime ?? bedtime.addingTimeInterval(12 * 60 * 60)
            while currentTime <= endTime {
                guard let currentPeriod = night.periods.first(where: { period in period.startDate <= currentTime && period.endDate >= currentTime
                }) else {
                    currentTime = currentTime.addingTimeInterval(samplingInterval)
                    continue
                }
                if currentPeriod.stage == .awake || currentPeriod.stage == .unknown {
                    currentTime = currentTime.addingTimeInterval(samplingInterval)
                    continue
                }
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: currentTime)
                let minute = calendar.component(.minute, from: currentTime)
                let weekday = calendar.component(.weekday, from: currentTime)
                let minutesSinceBedtime = Int(currentTime.timeIntervalSince(bedtime) / 60.0)
                let daysOfData = nights.count
                let row = "\(hour),\(minute),\(weekday),\(minutesSinceBedtime),\(daysOfData),\(currentPeriod.stage.rawValue)"
                csv.append(row)
                currentTime = currentTime.addingTimeInterval(samplingInterval)
            }
        }
        return csv.joined(separator: "\n")
    }

    func saveTrainingDataToFile(nights: [SleepNight]) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentsDirectory.appendingPathComponent("sleep_training_data.csv")
        let csvString = exportTrainingData(nights: nights)
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Trainding data saved to: \(fileURL.path)")
            return fileURL
        } catch {
            print("Error saving training data: \(error)")
            return nil
        }
    }
}

/// Distribution of sleep stages across a single sleep cycle
struct CycleStageDistribution {
    /// 10 buckets representing deciles of the sleep cycle (0-10%, 10-20%, etc.)
    let buckets: [SleepStage?]

    /// Default sleep stage distribution based on typical sleep architecture
    static var `default`: CycleStageDistribution {
        CycleStageDistribution(buckets: [
            .core, .core, .core, .deep, .deep,
            .core, .core, .rem, .rem, .rem
        ])
    }

    /// Returns the default stage for a given bucket index (fallback for missing data)
    func defaultStageForBucket(_ index: Int) -> SleepStage? {
        guard index >= 0 && index < 10 else { return nil }
        return CycleStageDistribution.default.buckets[index]
    }
}

/// Personalized sleep pattern derived from historical data
struct SleepPattern {
    let averageBedtime: Date
    let averageSleepDuration: TimeInterval
    let averageCycleDuration: TimeInterval
    let stageDistribution: CycleStageDistribution
    let nightsAnalyzed: Int

    var hasEnoughData: Bool {
        nightsAnalyzed >= 3
    }
}

/// Real-time sleep analysis snapshot
struct RealtimeSleepAnalysis {
    let currentStage: SleepStage
    let cyclePosition: Double
    let confidence: Double
}

/// Adaptive monitoring strategy based on predicted sleep patterns
struct MonitoringRecommendation {
    let startMinutesBeforeAlarm: Int
    let checkIntervalMinutes: Int
    let reason: String
    let riskLevel: RiskLevel

    enum RiskLevel: String {
        case minimal = "Minimal"
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }

    var totalMonitoringDuration: TimeInterval {
        TimeInterval(startMinutesBeforeAlarm * 60)
    }

    var estimatedChecks: Int {
        startMinutesBeforeAlarm / checkIntervalMinutes
    }

    var batteryImpact: String {
        switch riskLevel {
        case .minimal: return "Very Low"
        case .low: return "Low"
        case .medium: return "Moderate"
        case .high: return "Higher"
        }
    }
}
