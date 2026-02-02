# FocusOrb

A minimal macOS floating orb for externalizing **Focus / Break** state.

- One-click toggles between **Focus (green)** and **Break (red)**
- **3-second rollback window** when entering Break to reduce accidental taps
- Session summary + day/week/month/year dashboard
- Local-only storage (SQLite via GRDB)

> Product spec (Chinese): `PRD.md`

## Quick Start (From Zero)

### 0) Prerequisites

- macOS 14+ (Sonoma)
- Xcode 15+ (recommended) **or** at least the Xcode Command Line Tools

Install Command Line Tools:

```bash
xcode-select --install
```

Verify you have Swift:

```bash
swift --version
```

### 1) Clone the repo

```bash
git clone https://github.com/ZeruiLi/FocusOrb.git
cd FocusOrb
```

### 2) Build & run (SwiftPM)

The Swift Package lives under `./FocusOrb` (this repo contains a top-level PRD and the app package folder).

```bash
cd FocusOrb
swift build
swift run FocusOrb
```

### 3) What you should see

- The app runs as a **menu bar accessory app** (no Dock icon).
- On first run you’ll see the Start screen. Click **Start Flow**.
- A floating orb appears (always-on-top).
  - Click to toggle states
  - When entering Break, you get an **orange pending state** for ~3 seconds; click again to rollback
  - Long press (~0.8s) to end the session and view summary
- Use the menu bar icon to Show/Hide, open Dashboard, Settings, or Quit.

## Why

Some people (especially ADHD/time-blindness users) benefit from making state changes **visible** and **low-friction**:
- no task list
- no pomodoro setup
- no notifications by default

Just a tiny always-on-top orb.

## Features

### Floating Orb
- Always-on-top `NSPanel` floating orb
- Drag to reposition (with drag threshold to reduce mis-taps)
- Click to switch state
  - Green → Orange (pending) → Red
  - During pending, click again to rollback to green (no red segment recorded)
- Long press to end the session and show the summary

### Session Summary
- Total / focus / break durations
- Timeline segments
- Basic focus streak metrics
- Optional auto-merge hint

### Dashboard
- Day / Week / Month / Year
- Focus/break totals and ratios
- Trend chart
- Session list (with auto-merge badge)

### Data
- Event-sourcing style event log
- Stored locally in `~/Library/Application Support/FocusOrb/focusorb.sqlite`

## Requirements

- macOS 14+
- Swift 5.9+

## Build & Run

### SwiftPM

```bash
cd FocusOrb
swift build
swift run FocusOrb
```

### Xcode

1. Open `FocusOrb/Package.swift` in Xcode (Swift Package)
2. Select the `FocusOrb` executable target
3. Run

## Troubleshooting

### “It’s running but I don’t see the app”

FocusOrb is a menu bar accessory app (no Dock icon). Look for the small status item in the macOS menu bar. Use it to Show/Hide the orb, open Dashboard, or Quit.

### App crashes on launch due to old database data

If you changed schema/decoding and the database contains old or malformed rows, the app may fail to decode events.

To reset local data (this will delete your history):

```bash
rm -f ~/Library/Application\ Support/FocusOrb/focusorb.sqlite
```

### Dependencies won’t fetch / build fails on first run

SwiftPM will download dependencies (GRDB) automatically. If your network is restricted, try again on a stable connection, or open the package in Xcode and let it resolve packages.

## Repo Structure

- `FocusOrb/Sources/Domain`: state machine
- `FocusOrb/Sources/Models`: events/settings
- `FocusOrb/Sources/Services`: persistence + stats
- `FocusOrb/Sources/UI`: orb, windows, dashboard

## Roadmap

- Hotkeys
- Launch at login helper
- Export session summary (text/image)
- Better session detail view

## Contributing

Issues and PRs are welcome.

## License

TBD.
