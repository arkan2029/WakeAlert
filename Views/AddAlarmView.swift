import SwiftUI

struct AddAlarmView: View {
    let isSmartAlarm: Bool

    @Environment(\.dismiss) var dismiss
    @StateObject private var alarmManager = AlarmManager.shared
    private let mlPredictor = MLSleepPredictor.shared

    @State private var time = Date()
    @State private var label = ""
    @State private var repeatDays: Set<Weekday> = []
    @State private var snoozeEnabled = true
    @State private var maxAdjustmentMinutes = 15
    @State private var mlSuggestions: [(time: Date, stage: SleepStage, confidence: Double)] = []

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .onChange(of: time) { _ in
                            if isSmartAlarm {
                                fetchMLSuggestions()
                            }
                        }
                }

                if isSmartAlarm && !mlSuggestions.isEmpty {
                    Section(header: Text("Smart Time Suggestions")) {
                        Text("Based on typical sleep patterns:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(Array(mlSuggestions.prefix(3).enumerated()), id: \.offset) { index, suggestion in
                            Button {
                                time = suggestion.time
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(timeString(from: suggestion.time))
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.primary)

                                        HStack(spacing: 4) {
                                            Image(systemName: stageIcon(for: suggestion.stage))
                                                .font(.caption2)
                                            Text("\(suggestion.stage.rawValue) sleep")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        if index == 0 {
                                            Text("BEST")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green)
                                                .cornerRadius(4)
                                        }

                                        Text("\(Int(suggestion.confidence * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Section {
                    TextField("Label", text: $label)
                        .autocorrectionDisabled()
                }

                Section(header: Text("Repeat")) {
                    // Quick presets
                    HStack {
                        Button("Never") {
                            repeatDays.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .tint(repeatDays.isEmpty ? .blue : .gray)

                        Button("Weekdays") {
                            repeatDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
                        }
                        .buttonStyle(.bordered)
                        .tint(repeatDays == [.monday, .tuesday, .wednesday, .thursday, .friday] ? .blue : .gray)

                        Button("Weekends") {
                            repeatDays = [.saturday, .sunday]
                        }
                        .buttonStyle(.bordered)
                        .tint(repeatDays == [.saturday, .sunday] ? .blue : .gray)

                        Button("Every Day") {
                            repeatDays = Set(Weekday.allCases)
                        }
                        .buttonStyle(.bordered)
                        .tint(repeatDays.count == 7 ? .blue : .gray)
                    }
                    .font(.caption)

                    // Individual days
                    ForEach(Weekday.allCases, id: \.self) { day in
                        Button {
                            if repeatDays.contains(day) {
                                repeatDays.remove(day)
                            } else {
                                repeatDays.insert(day)
                            }
                        } label: {
                            HStack {
                                Text(day.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if repeatDays.contains(day) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                if isSmartAlarm {
                    Section(header: Text("Smart Wake Settings")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This alarm will wake you during lighter sleep stages (Core or REM) within \(maxAdjustmentMinutes) minutes of your set time.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)

                            HStack {
                                Text("Max Adjustment")
                                Spacer()
                                Picker("", selection: $maxAdjustmentMinutes) {
                                    Text("10 min").tag(10)
                                    Text("15 min").tag(15)
                                    Text("20 min").tag(20)
                                    Text("30 min").tag(30)
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                }

                Section(header: Text("Options")) {
                    Toggle("Snooze", isOn: $snoozeEnabled)
                }

                if isSmartAlarm {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("Smart Wake requires Apple Watch sleep data")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)

                            Text("For the first few nights, the alarm will work normally while gathering your sleep patterns. After 3+ nights of data, it will automatically adjust to wake you during optimal sleep stages.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(isSmartAlarm ? "Add Smart Alarm" : "Add Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAlarm()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if isSmartAlarm {
                    fetchMLSuggestions()
                }
            }
        }
    }

    private func saveAlarm() {
        let alarm = Alarm(
            time: time,
            label: label.isEmpty ? (isSmartAlarm ? "Smart Alarm" : "Alarm") : label,
            isEnabled: true,
            repeatDays: repeatDays,
            isSleepAware: isSmartAlarm,
            soundName: "default",
            snoozeEnabled: snoozeEnabled,
            maxAdjustmentMinutes: maxAdjustmentMinutes
        )

        alarmManager.addAlarm(alarm)
        dismiss()
    }

    private func fetchMLSuggestions() {
        // Estimate bedtime (8 hours before alarm)
        let estimatedBedtime = time.addingTimeInterval(-8 * 60 * 60)

        // Get ML suggestions
        mlSuggestions = mlPredictor.suggestWakeTimes(
            around: time,
            bedtime: estimatedBedtime,
            windowMinutes: maxAdjustmentMinutes
        )
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func stageIcon(for stage: SleepStage) -> String {
        switch stage {
        case .awake: return "eye"
        case .core: return "bed.double"
        case .rem: return "brain.head.profile"
        case .deep: return "moon.zzz.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

#Preview {
    AddAlarmView(isSmartAlarm: true)
}
