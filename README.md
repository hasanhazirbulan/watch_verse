# WatchVerse

A Flutter app for discovering and tracking movies and TV shows, with social features built in. Content data comes from the [TMDB](https://www.themoviedb.org/) API; user accounts, watch history, lists, and social interactions are backed by Firebase (Auth + Firestore). The project runs on Firebase's free Spark plan: there is no Cloud Storage bucket and no deployed Cloud Functions. WatchVerse ships on iOS only, and the UI is English-only.

## Features

- **Discover / Home** — now playing, trending, upcoming, popular, and top-rated movies & TV shows
- **Search** — search movies, TV shows, and people
- **Watchlist** — keep track of what you want to watch
- **Watch history & diary** — mark movies/shows as watched, rate them, favorite them, add notes
- **Episode tracking** — mark episodes watched per season/show, with an "Up Next" screen showing what's next
- **Custom lists** — create user-defined lists of movies/shows; make a list public and follow other users' public lists (free accounts: 3 lists)
- **Watch statistics** — time spent, movies vs shows, genre/weekly/weekday charts (the advanced charts are Pro)
- **Year in Review** — a yearly recap from your library and diary (Profile card + Watch Stats), shareable as PNG cards
- **My streaming services** — pick your region and services in Settings (stored on `users/{uid}` as `streamingRegion` / `streamingProviderIds`); an "On my services" filter chip on Watchlist and My Shows. Provider data from TMDB/JustWatch
- **Post-watch polls** — rate an episode/movie and answer "where did you watch / how did it feel / favorite character", with community percentages
- **Watch polls** — "What should we watch?" group polls with invited friends
- **Games hub** — six free games, no streaks: Daily Movie, Frames, Title Wordle, Plot, Who's the Actor? and Higher or Lower (`lib/screens/games/game_registry.dart`). Puzzle pools are bundled in the app; signed-in progress is saved under `users/{uid}/gamePlays`, Higher or Lower's best score stays on the device
- **Comments** — text + GIF comments (Giphy search, or a pasted GIF link when no Giphy key is configured; no photo uploads), likes, reporting, and blocking
- **Social features** — follow/unfollow users, block users, friends' activity feed, public profiles
- **Authentication** — sign up/login via Firebase Auth, or browse as a guest
- **Settings** — edit profile (the profile photo is a small inline JPEG stored on `users/{uid}`, not a Storage file), light/dark/system theme, notification preferences, My streaming services, and account deletion (resumes automatically on next sign-in if interrupted)
- **Import & export** — import from Letterboxd (zip/CSVs) or IMDb (CSV exports) in Settings; free CSV export of your library (movies, shows, diary, lists) via the share sheet
- **Splash screen** — shows a different trending poster on each launch (pre-cached on the previous run; falls back to bundled posters)
- **WatchVerse Pro / Patron** — optional iOS subscriptions via StoreKit (`in_app_purchase`, no backend). Pro: unlimited lists + advanced stats. Patron: Pro + exclusive profile themes
- **Push notifications** — episode airing reminders, watchlist movie releases, friend-activity digest and shared-watch matches, sent by a scheduled GitHub Actions job (see [Push Notifications](#push-notifications) below)
- **English-only** — `main.dart` forces `Locale('en')`. `lib/l10n/app_tr.arb` still exists but is unused and not maintained

## Tech Stack

- **Flutter 3.47.6** (stable; Dart SDK constraint `^3.9.2`) — the version pinned in CI (`.github/workflows/ci.yml`) and Xcode Cloud (`ios/ci_scripts/ci_post_clone.sh`). All dependencies were upgraded to their latest major versions on 2026-10-13; iOS plugins now build via Swift Package Manager
- **Firebase**: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `firebase_analytics`, `firebase_crashlytics`
- **TMDB API** — movie/TV data
- **Giphy API** — GIF search (used in comments)
- **StoreKit** via `in_app_purchase` — Pro/Patron subscriptions
- Other packages: `equatable`, `carousel_slider`, `cached_network_image`, `shared_preferences`, `curved_navigation_bar`, `flutter_rating_bar`, `fl_chart`, `image_picker`, `file_picker`, `archive`, `url_launcher`, `http`, `csv`, `share_plus`, `package_info_plus`, `flutter_cache_manager`, `flutter_local_notifications`, `flutter_localizations`/`intl`

## Supported Platforms

WatchVerse ships on **iOS only** (TestFlight / App Store). The `android/` project still builds and has the notification setup, but it is not released or regularly tested, and the subscription products only exist in App Store Connect, so Pro/Patron can't be purchased there. The macOS, Windows, Linux and Web folders are unmodified Flutter scaffolding — not configured, tested or deployed (e.g. push notifications don't work on Windows/Linux, and Web has no offline persistence).

## Project Structure

```
lib/
  models/     # Data models: Media, Movie, TvShow, Episode, etc.
  services/   # TMDB API, Firestore, social, list, comment, episode-tracking, Pro, games, import/export, streaming, Year in Review, account-deletion services
  screens/    # App screens (games under screens/games/)
  widgets/    # Reusable UI components
  theme/      # App theme
  l10n/       # ARB files + generated AppLocalizations (run `flutter gen-l10n` after editing; only app_en.arb is used)
docs/         # Privacy Policy + Terms of Service, served by Firebase Hosting at watchvers.web.app
functions/    # Cloud Functions (push senders, moderation, deletion backstop) — NOT deployed (Spark plan)
scripts/notify/  # The push sender that actually runs, on a GitHub Actions schedule
tool/         # Game-pool generators and seeding scripts
```

## Getting Started

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) — 3.47.6, matching CI
2. Install dependencies:
   ```
   flutter pub get
   ```
3. Firebase is already configured in `lib/firebase_options.dart` (generated via the FlutterFire CLI). To connect your own Firebase project instead:
   ```
   flutterfire configure
   ```
4. Set up API secrets (TMDB + Giphy). Copy the template and fill in your own keys:
   ```
   cp secrets.example.json secrets.json
   ```
   Get a TMDB key at [themoviedb.org/settings/api](https://www.themoviedb.org/settings/api) and a Giphy key at [developers.giphy.com](https://developers.giphy.com/). `secrets.json` is gitignored and must never be committed.
5. Run the app, passing the secrets file at build/run time:
   ```
   flutter run --dart-define-from-file=secrets.json
   ```
   Use the same flag for `flutter build ...` commands — e.g. a release build for TestFlight:
   ```
   flutter build ipa --release --dart-define-from-file=secrets.json
   ```

## Testing

```
flutter test
```

Firestore security-rules tests run against the emulator (run them before any rules deploy):

```
cd test/firestore_rules && npm install && npm test
```

## Push Notifications

The client is fully wired up (`lib/services/notification_service.dart`): it requests permission, stores each signed-in user's FCM token on their `users/{uid}` doc, and shows a local notification for foreground pushes. Settings has per-type toggles (episodes airing tomorrow/today, watchlist movies released today, friend activity, shared-watch matches) stored on the user doc. Sending runs in [`scripts/notify/run.js`](scripts/notify/run.js) on a GitHub Actions schedule ([`.github/workflows/notifications.yml`](.github/workflows/notifications.yml): episode reminders, movie releases and the friend-activity digest once a day each, plus an hourly activity poll for shared-watch matches; needs the `FIREBASE_SERVICE_ACCOUNT` repo secret, which is set) — a free stand-in for the Cloud Functions in `functions/`, which are **not** deployed (Spark plan). Don't deploy those notification functions as well, or users get every push twice.

Platform setup in this repo: iOS `Info.plist` background mode, the Push Notifications capability, and an APNs key in the Firebase console (the latter two live in the Apple Developer / Firebase accounts, not in files). The Android manifest permission + notification channel are also present, though Android isn't shipped.

## Roadmap

See [plan.md](plan.md) for planned changes and improvements.
