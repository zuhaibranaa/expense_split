---
description: Run the app on web (Chrome)
---

# Run on Web Platform

This workflow runs the SettleUp Clone app on the web platform using Chrome.

## Prerequisites

- Flutter SDK installed
- Chrome browser installed
- Backend server running on `http://localhost:8000` (optional, for API features)

## Steps

1. **Clean the project** (optional, but recommended if you encounter issues):
```bash
flutter clean
```

2. **Get dependencies**:
// turbo
```bash
flutter pub get
```

3. **Run the app on Chrome**:
// turbo
```bash
flutter run -d chrome
```

The app will automatically open in Chrome. Hot reload is enabled, so you can make changes and see them reflected immediately.

## Troubleshooting

- If Chrome doesn't launch, ensure it's installed and accessible from the command line
- If you see database errors, check the browser console for WASM-related issues
- For API connectivity issues, verify the backend server is running on port 8000
