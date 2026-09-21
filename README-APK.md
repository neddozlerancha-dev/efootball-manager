# eFootball Tournament Hub — Netlify to Android APK

This project is configured to package the live Netlify website as an Android app using Capacitor.

**Live website:** https://effulgent-trifle-f3b042.netlify.app

**Android app ID:** `com.efootball.tournamenthub`

**App name:** `eFootball Tournament Hub`

## Fastest build: GitHub Actions

1. Create a GitHub repository and upload this folder's contents.
2. Open the repository's **Actions** tab.
3. Run **Build Android APK** manually (or push to `main`).
4. When the workflow finishes, open the run and download the artifact named `efootball-tournament-hub-debug-apk`.
5. The artifact contains `app-debug.apk`.

The GitHub runner supplies Android SDK/Gradle, so Android Studio is not required for this workflow.

## Local build

Requirements: Node.js 20+, Android Studio/SDK, JDK 17 or 21.

```bash
npm install
npx cap add android
npx cap sync android
cd android
./gradlew assembleDebug
```

The APK will be at:
`android/app/build/outputs/apk/debug/app-debug.apk`

## Important

This APK opens the live Netlify site. Changes you deploy to the Netlify website will therefore appear in the app as well, subject to normal app/web caching.

For a fully bundled/offline-capable app, the web build should instead be placed in Capacitor's `www` directory and `server.url` removed.
