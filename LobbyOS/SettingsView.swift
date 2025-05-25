import SwiftUI
import UserNotifications
import AppKit

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var systemNotificationsAllowed = true

    var body: some View {
        Form {
            Toggle(isOn: $notificationsEnabled) {
                Text("Enable Notifications")
            }
            .disabled(!systemNotificationsAllowed)

            if !systemNotificationsAllowed {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifications are disabled in System Settings.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Open Notification Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.notifications-Settings") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            refreshSystemNotificationStatus()
        }
    }

    private func refreshSystemNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.systemNotificationsAllowed = (settings.authorizationStatus == .authorized)
            }
        }
    }
}
