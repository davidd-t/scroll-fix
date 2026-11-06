# ScrollFix

A tiny macOS menu bar app that reverses scroll direction — separately for
trackpad and mouse, and separately for vertical and horizontal.

No telemetry, no network access, no updater, no analytics. ~300 lines of Swift.

## Features

- Reverse vertical and/or horizontal scrolling
- Choose which devices to reverse: trackpad, mouse (or both)
- Optional fixed step size for classic mouse wheels
- Launch at login
- Toggle on/off from the menu bar

## Build

Requires Xcode command line tools (Swift 5.10+), macOS 13+.

```bash
./build.sh
open build/ScrollFix.app
```

Copy `build/ScrollFix.app` to `/Applications` to keep it.

## Permissions

ScrollFix needs **Accessibility** access to modify scroll events
(System Settings → Privacy & Security → Accessibility). It asks on first launch.

`build.sh` signs the app so the permission is tied to its bundle identifier,
so it survives rebuilds. The menu shows **Status: Active** when scrolling is
being modified; if it says it needs Accessibility access, remove any old
ScrollFix entries from that list and add the app again.

## How it works

A `CGEventTap` listens for scroll-wheel and gesture events. Gesture events
tell us how many fingers are on a trackpad; a scroll with two or more fingers
down is a trackpad scroll, anything else is a mouse. Matching scroll events
have their delta fields negated before being passed on.
