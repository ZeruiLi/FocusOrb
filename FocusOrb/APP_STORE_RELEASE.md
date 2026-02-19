# FocusOrb App Store Release Guide

## 1) One-time project settings in Xcode

1. Generate the App project: `./scripts/generate_xcodeproj.rb`.
2. Open `FocusOrb.xcodeproj` in Xcode.
3. Ensure Signing is Automatic and team is selected.
4. Ensure App Sandbox is enabled and entitlements file points to `FocusOrb.entitlements`.
5. Ensure App Icon set name is `AppIcon`.
6. Ensure App Category is set to Productivity (`LSApplicationCategoryType=public.app-category.productivity`).

## 2) Preflight

```bash
cd FocusOrb
./scripts/release_preflight.sh
```

## 3) Archive for App Store

```bash
cd FocusOrb
DEVELOPMENT_TEAM=YOURTEAMID \
APP_BUNDLE_ID=com.yourcompany.focusorb \
MARKETING_VERSION=1.0.0 \
BUILD_NUMBER=1 \
./scripts/archive_app_store.sh
```

Optional dry-run (no signing):

```bash
cd FocusOrb
DEVELOPMENT_TEAM=YOURTEAMID \
APP_BUNDLE_ID=com.yourcompany.focusorb \
MARKETING_VERSION=1.0.0 \
BUILD_NUMBER=1 \
CODE_SIGNING_ALLOWED=NO \
CODE_SIGNING_REQUIRED=NO \
./scripts/archive_app_store.sh
```

## 4) App Store Connect checklist

1. App Privacy: mark **No tracking**.
2. Data Collection: mark according to your policy (current code is local-first, no backend).
3. Upload screenshots (macOS required sizes).
4. Fill review notes: app is menu-bar accessory app.
5. Fill review notes: launch at login uses `SMAppService`.
6. Fill review notes: data is stored locally in app support SQLite.

## 5) Current repository release artifacts

- Privacy manifest: `Sources/Resources/PrivacyInfo.xcprivacy`
- Entitlements: `FocusOrb.entitlements`
- App icon set: `Sources/Resources/Assets.xcassets/AppIcon.appiconset`
