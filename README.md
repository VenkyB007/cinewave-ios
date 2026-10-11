# Cinewave iOS

iPhone shell around the Cinewave web app at `https://cinewave.nikolatesla.co.in`. It's a WKWebView app built the same way as
`kacheri-ios`:

- Sign-in cookies and local storage persist. Links under `nikolatesla.co.in` stay in the app;
  anything else opens in Safari or the matching app, and swiping from the left edge goes back.
- **Google sign-in** runs in the system sign-in sheet (`ASWebAuthenticationSession`), since Google
  refuses web views. The session is handed back through `/app-auth` on Cinewave's own server (cinewave/lib/app-handoff.js).
  The server returns `cinewave://auth?code=…`, and the code + verifier are POSTed to
  `/app-auth/exchange` inside the web view (`SignInHandoff.swift`).
- Videos play full screen and rotate to landscape. **Picture in Picture** works, and sound keeps
  playing with the screen locked (`UIBackgroundModes: audio`).
- "Play with" links to other players (VLC, Infuse …) open those apps.
- **Download** (1.1+): a movie's Download link, a photo or an album zip becomes a `WKDownload`
  (`Downloads.swift`) saved to the app's Documents folder, which the Files app shows as
  On My iPhone → Cinewave. The page's own Downloads sheet counts the bytes server-side (`?dl=`),
  so it works here too. The Android app's native screen (`CinewaveApp.openDownloads`) stays Android-only.
- The page can recognise the shell by `CinewaveIOS/<version>` in the user agent.
- No self-update: new builds come through TestFlight, or a fresh sideload.

## Build

Builds run on GitHub's macOS runners (`.github/workflows/ios.yml`). Every push builds an unsigned
`Cinewave.ipa` (the run's Artifacts), which Sideloadly or AltStore sign with any Apple ID. Publisher
(`D:\apps\publisher`, iOS tab) starts builds and fetches the .ipa.

**Run workflow → testflight** signs and uploads instead, once the repo has the secrets
`APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8` (an App Store Connect API key
with the Admin role). The app record in App Store Connect uses bundle ID `in.co.nikolatesla.cinewave`.

On a Mac: `brew install xcodegen && xcodegen generate && open Cinewave.xcodeproj`.

Bump `MARKETING_VERSION` in `project.yml` for each release. The build number is the CI run number.
