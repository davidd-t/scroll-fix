import AppKit
import CoreGraphics

/// Intercepts scroll-wheel events system-wide and flips their direction.
///
/// Telling a trackpad apart from a mouse: a trackpad (and a Magic Mouse) sends
/// "continuous" scroll events, while a classic wheel sends discrete ones. To
/// separate trackpad from Magic Mouse we also watch gesture events: a trackpad
/// scroll always has two or more fingers resting on the surface.
final class ScrollTap {
    enum Source { case trackpad, mouse }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let settings = Settings.shared

    // Touch tracking (fed by gesture events).
    private var fingersTouching = 0
    private var lastTouchTime: TimeInterval = 0

    // The source of the scroll currently in progress, kept stable through
    // its momentum phase (fingers have already lifted by then).
    private var currentSource: Source = .mouse

    private static let gestureEventType = CGEventType(rawValue: 29)! // NSEventType.gesture

    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.scrollWheel.rawValue) |
            (1 << ScrollTap.gestureEventType.rawValue)

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<ScrollTap>.fromOpaque(refcon).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        tap = port
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
    }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS turns the tap off if we're ever too slow; turn it back on.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case ScrollTap.gestureEventType:
            trackTouches(event)
        case .scrollWheel:
            processScroll(event)
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func trackTouches(_ event: CGEvent) {
        guard let nsEvent = NSEvent(cgEvent: event) else { return }
        let touches = nsEvent.touches(matching: .touching, in: nil).count
        fingersTouching = touches
        if touches > 0 { lastTouchTime = ProcessInfo.processInfo.systemUptime }
    }

    private func detectSource(_ event: CGEvent) -> Source {
        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)

        guard continuous else { return .mouse }

        // During momentum, the fingers are gone; reuse what we decided at the start.
        if momentumPhase != 0 && scrollPhase == 0 { return currentSource }

        let recentlyTouched = ProcessInfo.processInfo.systemUptime - lastTouchTime < 0.25
        return (fingersTouching >= 2 || (recentlyTouched && fingersTouching != 1)) ? .trackpad : .mouse
    }

    private func processScroll(_ event: CGEvent) {
        let s = settings
        guard s.enabled else { return }

        let source = detectSource(event)
        currentSource = source

        let reverse: Bool
        switch source {
        case .trackpad: reverse = s.reverseTrackpad
        case .mouse: reverse = s.reverseMouse
        }

        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let applyStep = !continuous && s.stepSize > 0

        guard reverse || applyStep else { return }

        let vSign: Int64 = (reverse && s.reverseVertical) ? -1 : 1
        let hSign: Int64 = (reverse && s.reverseHorizontal) ? -1 : 1

        // Read everything first: setting one field can recompute the others.
        var v = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        var h = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        var vFixed = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        var hFixed = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        var vPoint = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        var hPoint = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)

        if applyStep {
            let lines = s.stepSize
            let pixelsPerLine = 10.0
            if v != 0 || vFixed != 0 {
                let sign: Double = (v != 0 ? Double(v) : vFixed) > 0 ? 1 : -1
                v = Int64(sign * max(1, lines.rounded()))
                vFixed = sign * lines
                vPoint = Int64(sign * lines * pixelsPerLine)
            }
            if h != 0 || hFixed != 0 {
                let sign: Double = (h != 0 ? Double(h) : hFixed) > 0 ? 1 : -1
                h = Int64(sign * max(1, lines.rounded()))
                hFixed = sign * lines
                hPoint = Int64(sign * lines * pixelsPerLine)
            }
        }

        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: v * vSign)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: h * hSign)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: vFixed * Double(vSign))
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: hFixed * Double(hSign))
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: vPoint * vSign)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: hPoint * hSign)
    }
}
