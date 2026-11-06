import Foundation
import ServiceManagement

/// User preferences, persisted in UserDefaults.
/// Values are cached in stored properties so the event tap never touches
/// UserDefaults on the hot path.
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "enabled"
        static let reverseVertical = "reverseVertical"
        static let reverseHorizontal = "reverseHorizontal"
        static let reverseTrackpad = "reverseTrackpad"
        static let reverseMouse = "reverseMouse"
        static let stepSize = "stepSize"
    }

    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: Key.enabled) } }
    @Published var reverseVertical: Bool { didSet { defaults.set(reverseVertical, forKey: Key.reverseVertical) } }
    @Published var reverseHorizontal: Bool { didSet { defaults.set(reverseHorizontal, forKey: Key.reverseHorizontal) } }
    @Published var reverseTrackpad: Bool { didSet { defaults.set(reverseTrackpad, forKey: Key.reverseTrackpad) } }
    @Published var reverseMouse: Bool { didSet { defaults.set(reverseMouse, forKey: Key.reverseMouse) } }

    /// Lines per mouse-wheel notch. 0 means "leave the system value alone".
    @Published var stepSize: Double { didSet { defaults.set(stepSize, forKey: Key.stepSize) } }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("ScrollFix: launch-at-login change failed: \(error.localizedDescription)")
            }
        }
    }

    private init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.reverseVertical: true,
            Key.reverseHorizontal: true,
            Key.reverseTrackpad: false,
            Key.reverseMouse: true,
            Key.stepSize: 0.0,
        ])
        enabled = defaults.bool(forKey: Key.enabled)
        reverseVertical = defaults.bool(forKey: Key.reverseVertical)
        reverseHorizontal = defaults.bool(forKey: Key.reverseHorizontal)
        reverseTrackpad = defaults.bool(forKey: Key.reverseTrackpad)
        reverseMouse = defaults.bool(forKey: Key.reverseMouse)
        stepSize = defaults.double(forKey: Key.stepSize)
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
