# Changelog

All notable changes to this project are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added (2026-10-14)
- **My streaming services** (Settings, signed-in users): pick a region (defaults to the device's) and the services you subscribe to, from TMDB's JustWatch provider list. Stored on `users/{uid}` as `streamingRegion` / `streamingProviderIds`. The Watchlist and Up Next → My Shows get an **"On my services"** filter (flat-rate, free or with-ads streaming in your region; never rent/buy, never another region's data) with a logo badge on matching posters. Availability is checked 4 titles at a time with "Checking 12/80…" progress and a retry for failures, and cached per title in memory and on disk for 24h. Movie/TV "Where to Watch" now uses your chosen region, lists your services first ("On your Netflix") and credits JustWatch.
- **Games hub** (side menu → Games) with six free games, no streaks: the reworked Daily Movie game, **Frames** (guess from stills), **Title Wordle**, **Plot** (redacted synopsis), **Who's the Actor?** (daily, movie + TV modes where relevant) and **Higher or Lower** (endless rating/box-office rounds). Daily pools are bundled with the app (generators in `tool/`); progress syncs to `users/{uid}/gamePlays` under the existing rules.
- **Patron badge** on own and public profiles.
- On-device smoke tests in `integration_test/` (guest games, and signed-in games with a throwaway account that is deleted afterwards).

### Changed (2026-10-14)
- **The app is English-only now**, whatever the device language (`locale: Locale('en')` in `main.dart`). TMDB content and the game pools are English, so the Turkish UI around them read as half-translated. `app_tr.arb` is kept but unused.
- Daily Movie game: ↑/↓ direction on year/box office/rating, neutral "?" for unknown data, shared cast/genre/studio shown on partial matches, ranked search without unreleased/obscure titles, one cached TMDB call per guess, newest guess on top, how-to-play sheet, better hints (genres, top-billed actor), result card with poster + link, dated spoiler-free share text. Streak display and tracking removed.
- Privacy Policy / Terms: Patron badge, all game results listed (Higher or Lower stays on device).

### Fixed (2026-10-14)
- Daily Movie game: guesses after midnight were saved to the next day's puzzle while still showing the old movie; the board was guessable before saved progress loaded.
- Registration left a half-created account ("email already in use" on retry) when the profile write failed; the auth account is now rolled back.
- Catching up on or removing a long-running show (500+ episodes) failed on Firestore's per-batch write limit; `removeShow` also left episode notes behind.
- Profile/comment image uploads now send an image content type (required by the new `storage.rules`).

### Changed (2026-10-13)
- Flutter 3.35.5 → 3.47.6 and every dependency upgraded to its latest major version. iOS plugins now build via Swift Package Manager (CocoaPods only installs Flutter itself) and the app uses the UIScene lifecycle. CI and Xcode Cloud pinned to 3.47.6.
- Account deletion (`AccountDeletionService`) is now interruption-safe and resumable: it checks for a recent sign-in *before* touching any data, marks the profile `deletionPending`, purges everything (now including `followedLists` and `gamePlays`, previously missed), and if interrupted the app finishes the deletion on the next sign-in (`FinishDeletionScreen`) instead of leaving a live, half-empty account. Still client-side and non-atomic; uploaded images are not yet deleted (the shipped service has no Storage instance).
- Privacy Policy, Terms of Service, README and in-app text corrected to match what the code actually does (see "Fixed" below).

### Fixed (2026-10-13)
- `firestore.rules`: the `followers`/`likes` count-manipulation gap is closed again, this time correctly — `onlyOwnUidToggled()` lets a non-owner add/remove only their own uid and allows no-op writes (double unfollow, retries). Deployed, with 24 emulator tests in `test/firestore_rules/`.
- Daily game showed a blank screen forever on any load failure; it now shows a sign-in prompt for guests and an error with retry otherwise.
- `main.dart` zone mismatch (`runZonedGuarded` wrapped only `runApp`) removed.
- Privacy Policy: removed false claims that the push token is deleted when notifications are turned off (it is removed on sign-out), that images are deleted with the account, that reports contain no reporter identity, that Cloud Functions are in use, and that email/blocked list are strictly private (they are stored on the profile record any signed-in user's app can read); added Patron, group polls, followed lists, daily game data, public lists, analytics legal basis, resumable deletion, and the free CSV export.
- Terms of Service: listed CSV export and the daily game as Pro features (export is free; the game is currently ungated), had no Patron tier, and claimed reported comments are auto-hidden (that Cloud Function isn't deployed).
- In-app text: block confirmation claimed "you won't see their content" (only their comments are hidden, plus you unfollow them); episode note hint called the private note a "comment"; history empty state mentioned only episodes; delete-account dialog now lists what's deleted and that an App Store subscription isn't cancelled automatically; restore/active-subscription messages no longer say "Pro" for Patron subscribers. Turkish translation made consistently informal ("sen"), with terminology fixes ("başlık" → "yapım" for titles). Removed the unused `proFeatureExport` string and a duplicate `movieYourRating` key.

### Added (2026-10-04)
- **Patron** subscription tier above Pro (Pro: unlimited lists, advanced stats; Patron: Pro + exclusive profile themes), with a Pro/Patron toggle in the paywall sheet. Both tiers share one App Store subscription group.
- Free, complete data export: Settings → "Export my data (CSV)" shares movies, shows, diary and lists as four CSV files. Previously a diary-only Pro feature.

### Fixed (2026-10-04)
- Unfollow instantly re-followed in production — caused by the 2026-10-03 rules change below, which was reverted.
- Friends feed made one profile read per followed user per load; batched into a single query per call.

### Added (2026-10-03)
- `docs/terms-of-service.html`, hosted and linked from Settings → About and the paywall sheet alongside the Privacy Policy (`lib/services/legal_links.dart`) — required for the WatchVerse Pro subscription under App Store guideline 3.1.2.
- Explicit subscription-terms disclosure (renewal, pricing, cancellation) directly in the paywall sheet, also required by guideline 3.1.2.
- `ios/ci_scripts/ci_post_clone.sh` so Xcode Cloud can actually build the project (was failing on every run with no Flutter/CocoaPods bootstrap step).

### Fixed (2026-10-03)
- `docs/privacy-policy.html` falsely claimed "no in-app purchases" after the Pro subscription had already shipped; corrected and added a payment-data section.
- `firestore.rules`: `followers`/`likes` array fields let any signed-in user add/remove an arbitrary other uid, not just their own — tightened via `isSelfOnlyArrayToggle()`. **Reverted 2026-10-04** (it rejected no-op removals and broke unfollow); fixed properly on 2026-10-13.
- `ios/Podfile`: pod-level `IPHONEOS_DEPLOYMENT_TARGET`s below 15.0 made Xcode 27 refuse to archive the project at all; clamped in `post_install`.
- Daily movie game was unreachable by any tester — gated behind a Pro subscription that had no purchasable products yet in App Store Connect. Gate temporarily removed pending a confirmed-working subscription.

### Added (2026-08-09)
- WatchVerse Pro subscription (StoreKit via `in_app_purchase`, no backend) and the daily "guess the movie" game.

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
