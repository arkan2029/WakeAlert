import Foundation
import CoreML

class MLSleepPredictor {
    static let shared = MLSleepPredictor()

    private var model: SleepStageNN_Large?

    private init() {
        do {
            self.model = try SleepStageNN_Large(configuration: MLModelConfiguration())
            print("Sleep stage prediction model loaded")
        } catch {
            print("Failed to load ML model: \(error)")
            self.model = nil
        }
    }

    func predictSleepStage(at time: Date, bedtime: Date, daysOfData: Int = 30) -> (stage: SleepStage, confidence: Double)? {
        guard let model = model else {
            print("Model not loaded")
            return nil
        }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        let dayOfWeek = calendar.component(.weekday, from: time)
        let minutesSinceBedtime = Int(time.timeIntervalSince(bedtime) / 60.0)

        do {
            let input = SleepStageNN_LargeInput(
                hour: Int64(hour),
                minute: Int64(minute),
                day_of_week: Int64(dayOfWeek),
                minutes_since_bedtime: Int64(minutesSinceBedtime),
                days_of_sleep_data: Int64(daysOfData)
            )

            let prediction = try model.prediction(input: input)

            guard let predictedStage = SleepStage(rawValue: prediction.actual_stage) else {
                print("Unknown sleep stage: \(prediction.actual_stage)")
                return nil
            }

            let confidence = prediction.actual_stageProbability[prediction.actual_stage] ?? 0.0
            return (predictedStage, confidence)

        } catch {
            print("Prediction failed: \(error)")
            return nil
        }
    }

    func suggestWakeTimes(
        around targetTime: Date,
        bedtime: Date,
        windowMinutes: Int = 15
    ) -> [(time: Date, stage: SleepStage, confidence: Double)] {
        var suggestions: [(Date, SleepStage, Double)] = []
        let calendar = Calendar.current

        let startTime = targetTime.addingTimeInterval(-Double(windowMinutes) * 60)
        let endTime = targetTime.addingTimeInterval(Double(windowMinutes) * 60)

        var currentTime = startTime
        while currentTime <= endTime {
            if let prediction = predictSleepStage(at: currentTime, bedtime: bedtime) {
                suggestions.append((currentTime, prediction.stage, prediction.confidence))
            }
            currentTime = calendar.date(byAdding: .minute, value: 5, to: currentTime) ?? currentTime
        }

        // Sort by best wake times (lighter sleep stages first)
        suggestions.sort { first, second in
            if first.1.wakePriority != second.1.wakePriority {
                return first.1.wakePriority < second.1.wakePriority
            }
            return first.2 > second.2
        }

        return suggestions
    }
}
