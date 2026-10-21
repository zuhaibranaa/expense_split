# EquiSplit — Mobile & Web Client

A cross-platform **expense splitting and group finance** app built with Flutter. Split bills, track who owes whom, settle up — across Android, iOS, Web, macOS, Windows and Linux from a single codebase.

This repository is the **client** side of EquiSplit. The Laravel 12 API it talks to lives in the companion [`equisplit`](https://github.com/zuhaibranaa/equisplit) repository.

---

## ✨ Features

### Groups & people
- Create groups for trips, roommates, events or households
- Invite members by email and claim pending invites
- Member directory with avatars, contact details and per-group roles
- Cash-inflow tracking — money coming *in* (salary, refunds) linked to specific expenses

### Expenses & splitting
- Add expenses with amount, category, date and payer
- Split across any subset of members — equally or by custom shares
- Automatic balance calculation: who owes whom, minimised into a settlement list
- Settlement tracking, so a recorded payment clears the debt

### Analytics
- Spending statistics and trends per group, rendered with FL Chart
- Category breakdowns and cash-flow charts

### Platform & real-time
- **Live group updates** over WebSockets (Pusher/Soketi) — balances and expenses appear without a refresh
- **Push notifications** via Firebase Cloud Messaging, including settlement reminders
- **Offline-first** — a local Drift/SQLite database with sync to the backend
- Google sign-in, secure token storage, in-app currency picker
- Slidable expense rows, emoji picker, image attachments via the API's Cloudinary upload

---

## 🚀 Platform support

| Platform | Status | Notes |
|----------|--------|-------|
| 🌐 Web | ✅ | Runs in Chrome, Firefox, Safari, Edge |
| 🍎 macOS | ✅ | Native macOS application |
| 🪟 Windows | ✅ | Native Windows application |
| 🐧 Linux | ✅ | Native Linux application |
| 🤖 Android | ✅ | Android 5.0+ (API 21+) |
| 📱 iOS | ✅ | iOS 12.0+ |

---

## 🏗️ Architecture

Feature-first structure with a shared layer:

```
lib/
├── main.dart                       # Entry point
└── src/
    ├── app.dart                    # App shell & theme
    ├── config/
    │   └── environment.dart        # Environment / API base URL config
    ├── features/
    │   ├── auth/                   # Sign-in, sign-up, Google auth, token handling
    │   ├── home/                   # Dashboard & personal balances
    │   ├── groups/                 # Group list, group detail, invites
    │   ├── expenses/               # Expense entry, editing, settlement
    │   ├── categories/             # Category management
    │   ├── cash_inflows/           # Income / cash-inflow tracking
    │   ├── people/                 # Member directory
    │   └── analytics/              # Statistics & charts
    └── shared/
        ├── data/api_client.dart    # HTTP client, auth headers, error handling
        ├── services/               # Notification service
        ├── presentation/widgets/   # Reusable UI widgets
        └── utils/                  # Platform detection, formatters, helpers
```

**State management:** [Riverpod](https://riverpod.dev) — providers are scoped per feature so a rebuild in one area doesn't cascade.

**Routing:** [go_router](https://pub.dev/packages/go_router) with declarative routes and shell-based navigation.

**Persistence:** [Drift](https://drift.simonbinder.eu) over SQLite, with a web-compatible implementation, so the app works offline and reconciles with the API when connectivity returns.

**Platform detection:** `PlatformInfo` in `lib/src/shared/utils/platform_info.dart` deliberately uses `flutter/foundation` rather than `dart:io` — importing `dart:io` breaks the web build.

---

## 📦 Tech stack

| Concern | Choice |
|---------|--------|
| Framework | Flutter 3.38 / Dart 3.10+ |
| State management | Riverpod |
| Routing | go_router |
| Local database | Drift + SQLite (`sqlite3_flutter_libs`) |
| HTTP | `http` |
| Real-time | `pusher_channels_flutter` (Soketi-compatible) |
| Push | Firebase Messaging + `firebase_core` |
| Auth | `google_sign_in`, `flutter_secure_storage` |
| Charts | FL Chart |
| UI | Google Fonts, `flutter_slidable`, `emoji_picker_flutter`, `currency_picker` |
| Ads | `google_mobile_ads` |
| Local notifications | `flutter_local_notifications` |
| Media | `image_picker` |
| Utilities | `intl`, `uuid`, `rxdart`, `shared_preferences` |

---

## 🛠️ Getting started

### Prerequisites

- **Flutter SDK** 3.38.1 or higher
- **Dart** 3.10.0 or higher

Platform-specific:

- **macOS / iOS** — Xcode and CocoaPods
- **Android** — Android Studio and Android SDK
- **Windows** — Visual Studio 2022 with the "Desktop development with C++" workload
- **Linux** — see the [Flutter Linux setup guide](https://docs.flutter.dev/get-started/install/linux)

### 1. Clone & install

```bash
git clone https://github.com/zuhaibranaa/expense_split.git
cd expense_split

flutter pub get
```

### 2. Point the app at an API

The base URL is resolved per platform automatically (see `lib/src/config/environment.dart`):

| Target | Base URL |
|--------|----------|
| Web / macOS / Linux / Windows | `http://localhost:8000` |
| Android emulator | `http://10.0.2.2:8000` (the emulator's alias for the host) |
| iOS simulator | `http://localhost:8000` |

**On a physical device**, update the host IP in `lib/src/config/environment.dart` and make sure the API accepts connections from your LAN (not just `localhost`). See the `/run-mobile` workflow in `.agent/workflows/` for the full walkthrough.

Start the backend first — see [`equisplit`](https://github.com/zuhaibranaa/equisplit) for the Docker Compose stack (`php artisan serve` on port 8000).

### 3. Run

```bash
flutter devices              # list available targets

flutter run -d chrome        # web
flutter run -d macos         # macOS
flutter run -d windows       # windows
flutter run -d linux         # linux
flutter run -d <device-id>   # android / ios
```

Predefined workflows are documented in `.agent/workflows/`: `run-web.md`, `run-macos.md`, `run-mobile.md`.

---

## 🏗️ Building for production

```bash
flutter build web     --release   # build/web/
flutter build apk     --release   # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release # build/app/outputs/bundle/release/
flutter build ipa     --release   # requires Xcode signing
flutter build macos   --release
flutter build windows --release
flutter build linux   --release
```

---

## 🧪 Quality

```bash
flutter analyze    # static analysis (analysis_options.yaml)
flutter test       # test suite
```

---

## 🔍 Troubleshooting

**Web**
- Database errors → check the browser console for WASM loading issues
- CORS errors → allow the frontend origin in the API's CORS config

**macOS / iOS**
- CocoaPods errors → `pod install` inside the platform directory
- Signing issues → configure a team and bundle ID in Xcode

**Android**
- Emulator not found → launch it from Android Studio first
- API connection fails → confirm the backend is listening on port 8000 and that `10.0.2.2` is used from the emulator

**General**
- Build errors → `flutter clean && flutter pub get`
- Platform unavailable → `flutter doctor`

---

## 🔗 Related

- **Backend API** — [`zuhaibranaa/equisplit`](https://github.com/zuhaibranaa/equisplit) (Laravel 12)
- **Flutter docs** — [docs.flutter.dev](https://docs.flutter.dev/)
- **Riverpod** — [riverpod.dev](https://riverpod.dev)
- **Drift** — [drift.simonbinder.eu](https://drift.simonbinder.eu)

## 📄 License

MIT
