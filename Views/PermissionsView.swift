import SwiftUI

struct PermissionsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var isRequestingPermissions = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)

                VStack(spacing: 12) {
                    Text("Smart Wake Needs Permissions")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("To wake you during optimal sleep stages, we need access to your Apple Watch sleep data.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 20) {
                    PermissionRow(
                        icon: "moon.zzz.fill",
                        title: "Sleep Data",
                        description: "Read your sleep stages from Apple Watch",
                        isGranted: healthKitManager.isAuthorized
                    )

                    PermissionRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        description: "Alert you when it's time to wake up",
                        isGranted: true // We'll assume notification permission
                    )
                }
                .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 16) {
                    if !healthKitManager.isAuthorized {
                        Button {
                            requestPermissions()
                        } label: {
                            HStack {
                                if isRequestingPermissions {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("Grant Permissions")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isRequestingPermissions)
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Permissions Granted")
                                    .fontWeight(.semibold)
                            }
                            .font(.headline)

                            Button("Done") {
                                dismiss()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }

                    if !healthKitManager.isAuthorized {
                        Button("Skip for Now") {
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func requestPermissions() {
        isRequestingPermissions = true
        errorMessage = nil

        Task {
            do {
                try await healthKitManager.requestAuthorization()
                isRequestingPermissions = false
            } catch {
                errorMessage = error.localizedDescription
                isRequestingPermissions = false
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isGranted ? .green : .blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    PermissionsView()
}
