import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let scrollTap = ScrollTap()
    private var statusItem: NSStatusItem!
    private var enableItem: NSMenuItem!
    private var statusLine: NSMenuItem!
    private var preferencesWindow: NSWindow?
    private var permissionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()

        settings.$enabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)

        if !startTapIfPermitted(prompt: true) {
            showPreferences()
            // Keep checking until the user grants Accessibility access.
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                if self?.startTapIfPermitted(prompt: false) == true { timer.invalidate() }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPreferences()
        return true
    }

    // MARK: - Accessibility

    private func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    private func startTapIfPermitted(prompt: Bool) -> Bool {
        guard isTrusted(prompt: prompt) else { return false }
        return scrollTap.start()
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        menu.delegate = self
        statusLine = NSMenuItem(title: "", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        statusLine.target = self
        menu.addItem(statusLine)
        menu.addItem(.separator())
        enableItem = NSMenuItem(title: "Enable ScrollFix", action: #selector(toggleEnabled), keyEquivalent: "")
        enableItem.target = self
        menu.addItem(enableItem)
        menu.addItem(.separator())

        let prefs = NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(NSMenuItem(title: "Quit ScrollFix", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        updateStatusIcon()
    }

    private func updateStatusIcon() {
        let image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "ScrollFix")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = !settings.enabled
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        enableItem.state = settings.enabled ? .on : .off
        if scrollTap.isRunning {
            statusLine.title = "Status: Active"
            statusLine.isEnabled = false
        } else {
            statusLine.title = "⚠︎ Needs Accessibility access…"
            statusLine.isEnabled = true
        }
    }

    @objc private func openAccessibilitySettings() {
        _ = isTrusted(prompt: true)
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
    }

    @objc private func showPreferences() {
        if preferencesWindow == nil {
            let view = PreferencesView(hasAccessibility: { [weak self] in self?.isTrusted(prompt: false) ?? false })
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "ScrollFix"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            preferencesWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
