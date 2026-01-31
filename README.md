# FocusOrb

A minimal macOS floating orb for externalizing **Focus / Break** state.

- One-click toggles between **Focus (green)** and **Break (red)**
- **3-second rollback window** when entering Break to reduce accidental taps
- Session summary + day/week/month/year dashboard
- Local-only storage (SQLite via GRDB)

> Product spec (Chinese): `PRD.md`

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

1. Open the folder `FocusOrb` in Xcode (Swift Package)
2. Select the `FocusOrb` executable target
3. Run

## Troubleshooting

### App crashes on launch due to old database data

If you changed schema/decoding and the database contains old or malformed rows, the app may fail to decode events.

To reset local data (this will delete your history):

```bash
rm -f ~/Library/Application\ Support/FocusOrb/focusorb.sqlite
```

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
