# Taubey Hub – iOS

Native SwiftUI app for the taubey.com hub dashboard: every farming instance at
a glance, its settings, rejoin / server hop / pause, inventory across accounts,
catches by rarity, events.

## Install

Every push to `main` builds on GitHub Actions and publishes a release
`build-<n>` with `Taubey.ipa` – install it with TrollStore (iOS 16.4.1).

## Sign in

The app uses the same session as the web dashboard, handed out for a code:

1. On the computer: taubey.com/dashboard → **Alerts** → *Sign in a phone* →
   **Get a code for my phone**
2. Type the code into the app. The session lasts 90 days.

## Layout

- `ios/Shared/` – no UI: JSON, models, number formatting, the API client.
  Compiled and tested on the runner with plain `swiftc` before the Xcode build.
- `ios/Tests/` – logic tests with real (shortened) server answers in
  `Fixtures.swift`. New endpoint or field: record a real answer first.
- `ios/Taubey/` – the SwiftUI app.
- `tools/make_icon.py` – draws the app icon.

API: `taubey-hub/api/agents.js` (`/api/overview`, `/api/inventory`,
`/api/events`, `/api/history`, `/api/game/:game/schema`, `/api/agent/:id`,
`/api/config/apply`, `/api/command`, `/api/phone/claim`).
