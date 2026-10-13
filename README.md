# WatchVerse

A Flutter app for discovering and tracking movies and TV shows, with social features built in. Content data comes from the [TMDB](https://www.themoviedb.org/) API; user accounts, watch history, lists, and social interactions are backed by Firebase (Auth + Firestore + Storage).

## Features

- **Discover / Home** — now playing, trending, upcoming, popular, and top-rated movies & TV shows
- **Search** — search movies, TV shows, and people
- **Watchlist** — keep track of what you want to watch
- **Watch history & diary** — mark movies/shows as watched, rate them, favorite them, add notes
- **Episode tracking** — mark episodes watched per season/show, with an "Up Next" screen showing what's next
- **Custom lists** — create user-defined lists of movies/shows; make a list public and follow other users' public lists (free accounts: 3 lists)
- **Watch statistics** — time spent, movies vs shows, genre/weekly/weekday charts (the advanced charts are Pro)
- **Post-watch polls** — rate an episode/movie and answer "where did you watch / how did it feel / favorite character", with community percentages
- **Watch polls** — "What should we watch?" group polls with invited friends
- **Daily movie game** — guess the movie from unlocking clues (signed-in users; currently free for everyone — the Pro gate is temporarily removed)
- **Comments** — GIF-enabled commenting (Giphy integration) with photo upload, likes, reporting, and blocking
- **Social features** — follow/unfollow users, block users, friends' activity feed, public profiles
- **Authentication** — sign up/login via Firebase Auth, or browse as a guest
- **Settings** — edit profile, light/dark/system theme, notification preferences, free CSV export of your library (movies, shows, diary, lists), and account deletion (resumes automatically on next sign-in if interrupted)
- **WatchVerse Pro / Patron** — optional iOS subscriptions via StoreKit (`in_app_purchase`, no backend). Pro: unlimited lists + advanced stats. Patron: Pro + exclusive profile themes
- **Push notifications** — client-side only for now; nothing is sent until the Cloud Functions are deployed (see [Push Notifications](#push-notifications) below)
- **Localization** — English and Turkish (`lib/l10n`)

## Tech Stack

- **Flutter 3.47.6** (stable; Dart SDK constraint `^3.9.2`) — the version pinned in CI (`.github/workflows/ci.yml`) and Xcode Cloud (`ios/ci_scripts/ci_post_clone.sh`). All dependencies were upgraded to their latest major versions on 2026-10-13; iOS plugins now build via Swift Package Manager
- **Firebase**: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`, `firebase_analytics`, `firebase_crashlytics`
- **TMDB API** — movie/TV data
- **Giphy API** — GIF search (used in comments)
- **StoreKit** via `in_app_purchase` — Pro/Patron subscriptions
- Other packages: `equatable`, `carousel_slider`, `cached_network_image`, `shared_preferences`, `curved_navigation_bar`, `flutter_rating_bar`, `fl_chart`, `image_picker`, `url_launcher`, `http`, `csv`, `share_plus`, `package_info_plus`, `flutter_local_notifications`, `flutter_localizations`/`intl`

## Supported Platforms

iOS and Android are the real targets (iOS is the one shipped via TestFlight/App Store). The subscription products only exist in App Store Connect, so Pro/Patron can't be purchased on Android. The macOS, Windows, Linux and Web folders are unmodified Flutter scaffolding — not configured, tested or deployed (e.g. push notifications don't work on Windows/Linux, and Web has no offline persistence).

## Project Structure

```
lib/
  models/     # Data models: Media, Movie, TvShow, Episode, etc.
  services/   # TMDB API, Firestore, social, list, comment, episode-tracking, Pro, export, account-deletion services
  screens/    # App screens (32 screens)
  widgets/    # Reusable UI components
  theme/      # App theme
  l10n/       # ARB files + generated AppLocalizations (run `flutter gen-l10n` after editing)
docs/         # Privacy Policy + Terms of Service, served by Firebase Hosting at watchvers.web.app
functions/    # Cloud Functions (push senders, moderation, deletion backstop) — NOT deployed
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
   Use the same flag for `flutter build ...` commands.

## Testing

```
flutter test
```

Firestore security-rules tests run against the emulator (run them before any rules deploy):

```
cd test/firestore_rules && npm install && npm test
```

## Push Notifications

The client is fully wired up (`lib/services/notification_service.dart`): it requests permission, stores each signed-in user's FCM token on their `users/{uid}` doc, and shows a local notification for foreground pushes. Settings has per-type toggles (episodes airing tomorrow/today, friend activity, shared-watch matches) stored on the user doc. Actually **sending** a notification is a server-side job — see [`functions/`](functions/README.md) for the Cloud Functions that do this and how to deploy them. **They are not deployed** (the Firebase project is on the free Spark plan, which can't run Cloud Functions), so today no push notifications are sent at all. The app works normally without them.

Platform setup already done in this repo: Android manifest permission + notification channel, iOS `Info.plist` background mode. Still required on iOS specifically (can't be done via file edits — needs your Apple Developer account): enable the **Push Notifications** capability in Xcode (Signing & Capabilities) and upload an APNs key to the Firebase console.

## Roadmap

See [plan.md](plan.md) for planned changes and improvements.
