# Changelog

All notable changes to this project are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added (2026-10-03)
- `docs/terms-of-service.html`, hosted and linked from Settings → About and the paywall sheet alongside the Privacy Policy (`lib/services/legal_links.dart`) — required for the WatchVerse Pro subscription under App Store guideline 3.1.2.
- Explicit subscription-terms disclosure (renewal, pricing, cancellation) directly in the paywall sheet, also required by guideline 3.1.2.
- `ios/ci_scripts/ci_post_clone.sh` so Xcode Cloud can actually build the project (was failing on every run with no Flutter/CocoaPods bootstrap step).

### Fixed (2026-10-03)
- `docs/privacy-policy.html` falsely claimed "no in-app purchases" after the Pro subscription had already shipped; corrected and added a payment-data section.
- `firestore.rules`: `followers`/`likes` array fields let any signed-in user add/remove an arbitrary other uid, not just their own — tightened via `isSelfOnlyArrayToggle()`.
- `ios/Podfile`: pod-level `IPHONEOS_DEPLOYMENT_TARGET`s below 15.0 made Xcode 27 refuse to archive the project at all; clamped in `post_install`.
- Daily movie game was unreachable by any tester — gated behind a Pro subscription that had no purchasable products yet in App Store Connect. Gate temporarily removed pending a confirmed-working subscription.

### Added
- Light/dark/system theme toggle (Settings → Appearance), persisted across launches.
- Localization: English and Turkish, covering the entire app (`lib/l10n`).
- Push notification client: permission request, FCM token registration, foreground local notifications (`lib/services/notification_service.dart`). Server-side sending is scaffolded but not deployed — see `functions/README.md`.
- Shared `StreamListView` / `FutureListView` / `FutureValueView` widgets for consistent loading/error/empty states across screens.
- Unit tests for `ListService` and `MovieService`.
- CI pipeline (GitHub Actions): `dart analyze` + `flutter test` on every push/PR.
- `CONTRIBUTING.md` and this changelog.

### Changed
- TMDB and Giphy API keys moved out of source into `--dart-define-from-file` secrets (see `secrets.example.json`).
- `AppColors` converted from static constants to a `ThemeExtension`, enabling the theme toggle above.
- Turkish in-code comments translated to English for consistency.

### Fixed
- Several screens didn't check `Stream`/`FutureBuilder` snapshots for errors, so failures (e.g. a missing API key) silently showed an infinite spinner or an empty state instead of an error message.

## [1.0.0] - unreleased

Initial tracked state of the app: movie/TV discovery via TMDB, watchlist/watched/diary tracking, episode tracking with an "Up Next" feed, custom lists, GIF-enabled comments, and social features (follow, block, friends' activity, public profiles) on Firebase Auth + Firestore + Storage.
