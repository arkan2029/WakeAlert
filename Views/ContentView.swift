import SwiftUI

struct ContentView: View {
    @StateObject private var alarmManager = AlarmManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var showingAddAlarm = false
    @State private var showingAddSmartAlarm = false
    @State private var showingPermissions = false
    @State private var showSmartWakeInfo = false

    var body: some View {
        NavigationView {
            ZStack {
                if alarmManager.alarms.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "alarm.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("No Alarms")
                            .font(.title2)
                            .foregroundColor(.gray)

                        Text("Tap + to add a sleep-aware alarm")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(alarmManager.alarms) { alarm in
                            AlarmRow(alarm: alarm)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        alarmManager.deleteAlarm(alarm)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        showingAddAlarm = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingPermissions = true
                    } label: {
                        Image(systemName: healthKitManager.isAuthorized ? "heart.fill" : "heart")
                            .foregroundColor(healthKitManager.isAuthorized ? .red : .gray)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSmartWakeInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddAlarm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSmartAlarm = true
                    } label: {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                    }
                }
            }
            .sheet(isPresented: $showingAddAlarm) {
                AddAlarmView(isSmartAlarm: false)
            }
            .sheet(isPresented: $showingAddSmartAlarm) {
                AddAlarmView(isSmartAlarm: true)
            }
            .sheet(isPresented: $showingPermissions) {
                PermissionsView()
            }
            .onAppear {
                alarmManager.setupNotificationActions()

                if !healthKitManager.isAuthorized {
                    showingPermissions = true
                }
            }
            .alert("Smart Wake", isPresented: $showSmartWakeInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Smart Wake uses AI to wake you during lighter sleep stages (Core or REM) for a more refreshing morning.\n\n🧠 How it works:\n• Analyzes your Apple Watch sleep data\n• Learns your personal sleep patterns (after 3+ nights)\n• Uses ML predictions as a fallback\n• Adjusts wake time within your specified window\n\nTap the brain icon (🧠) to create a Smart Wake alarm!")
            }
        }
    }
}

struct AlarmRow: View {
    let alarm: Alarm
    @StateObject private var alarmManager = AlarmManager.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(timeString(from: alarm.time))
                        .font(.system(size: 36, weight: .light, design: .default))

                    if alarm.isSleepAware {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }

                if !alarm.label.isEmpty {
                    Text(alarm.label)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }

                if !alarm.repeatDays.isEmpty {
                    Text(repeatDaysString(alarm.repeatDays))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("One time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let adjustedTime = alarm.adjustedTime, alarm.isSleepAware {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption2)
                        Text("Adjusted to \(timeString(from: adjustedTime))")
                            .font(.caption2)
                    }
                    .foregroundColor(.green)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in alarmManager.toggleAlarm(alarm) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 8)
        .opacity(alarm.isEnabled ? 1.0 : 0.5)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func repeatDaysString(_ days: Set<Weekday>) -> String {
        if days.count == 7 {
            return "Every day"
        } else if days.count == 5 && !days.contains(.saturday) && !days.contains(.sunday) {
            return "Weekdays"
        } else if days.count == 2 && days.contains(.saturday) && days.contains(.sunday) {
            return "Weekends"
        } else {
            return days.sorted().map { $0.displayName }.joined(separator: ", ")
        }
    }
}

#Preview {
    ContentView()
}
