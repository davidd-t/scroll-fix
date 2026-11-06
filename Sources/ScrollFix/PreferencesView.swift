import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings = Settings.shared
    var hasAccessibility: () -> Bool

    @State private var trusted = true

    var body: some View {
        Form {
            Toggle("Enable ScrollFix", isOn: $settings.enabled)

            Section("Scrolling Axes") {
                Toggle("Reverse Vertical", isOn: $settings.reverseVertical)
                Toggle("Reverse Horizontal", isOn: $settings.reverseHorizontal)
            }
            .disabled(!settings.enabled)

            Section("Scrolling Devices") {
                Toggle("Reverse Trackpad", isOn: $settings.reverseTrackpad)
                Toggle("Reverse Mouse", isOn: $settings.reverseMouse)
            }
            .disabled(!settings.enabled)

            Section("Mouse Wheel") {
                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $settings.stepSize, in: 0...10, step: 1) {
                        Text("Step size")
                    }
                    Text(settings.stepSize == 0
                         ? "System default"
                         : "\(Int(settings.stepSize)) line\(settings.stepSize == 1 ? "" : "s") per notch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!settings.enabled)

            Section("App") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                if !trusted {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        Text("Accessibility access is required.")
                        Spacer()
                        Button("Open Settings…") {
                            NSWorkspace.shared.open(URL(string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize()
        .onAppear { trusted = hasAccessibility() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            trusted = hasAccessibility()
        }
    }
}
