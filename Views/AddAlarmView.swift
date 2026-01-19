import SwiftUI

struct AddAlarmView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var alarmManager = AlarmManager.shared

    @State private var time = Date()
    @State private var label = ""
    @State private var repeatDays: Set<Weekday> = []
    @State private var isSleepAware = true
    @State private var snoozeEnabled = true
    @State private var maxAdjustmentMinutes = 15

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }

                Section {
                    TextField("Label", text: $label)
                        .autocorrectionDisabled()
                }

                Section(header: Text("Repeat")) {
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

                Section(header: Text("Sleep-Aware Settings")) {
                    Toggle("Smart Wake", isOn: $isSleepAware)

                    if isSleepAware {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The alarm will wake you during lighter sleep stages (Core or REM) within \(maxAdjustmentMinutes) minutes of your set time.")
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

                Section {
                    if isSleepAware {
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
            .navigationTitle("Add Alarm")
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
        }
    }

    private func saveAlarm() {
        let alarm = Alarm(
            time: time,
            label: label.isEmpty ? "Alarm" : label,
            isEnabled: true,
            repeatDays: repeatDays,
            isSleepAware: isSleepAware,
            soundName: "default",
            snoozeEnabled: snoozeEnabled,
            maxAdjustmentMinutes: maxAdjustmentMinutes
        )

        alarmManager.addAlarm(alarm)
        dismiss()
    }
}

#Preview {
    AddAlarmView()
}
