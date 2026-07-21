# WatchVerse

A Flutter app for discovering and tracking movies and TV shows, with social features built in. Content data comes from the [TMDB](https://www.themoviedb.org/) API; user accounts, watch history, lists, and social interactions are backed by Firebase (Auth + Firestore + Storage).

## Features

- **Discover / Home** — now playing, trending, upcoming, popular, and top-rated movies & TV shows
- **Search** — search movies, TV shows, and people
- **Watchlist** — keep track of what you want to watch
- **Watch history & diary** — mark movies/shows as watched, rate them, favorite them, add notes
- **Episode tracking** — mark episodes watched per season/show, with an "Up Next" screen showing what's next
- **Custom lists** — create user-defined lists of movies/shows
- **Comments** — GIF-enabled commenting (Giphy integration) with likes and reporting
- **Social features** — follow/unfollow users, block users, friends' activity feed, public profiles
- **Authentication** — sign up/login via Firebase Auth
- **Settings** — account preferences, light/dark/system theme
- **Push notifications** — new followers and friends' activity (see [Push Notifications](#push-notifications) below)
- **Localization** — English and Turkish (`lib/l10n`)

## Tech Stack

- **Flutter** (Dart SDK `^3.9.2`)
- **Firebase**: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`
- **TMDB API** — movie/TV data
- **Giphy API** — GIF search (used in comments)
- Other packages: `equatable`, `carousel_slider`, `shared_preferences`, `curved_navigation_bar`, `flutter_rating_bar`, `image_picker`, `url_launcher`, `http`, `flutter_local_notifications`, `flutter_localizations`/`intl`

## Supported Platforms

Android, iOS, macOS, Windows, Linux, Web

## Project Structure

```
lib/
  models/     # Data models: Media, Movie, TvShow, Episode, etc.
  services/   # TMDB API, Firestore, social, list, comment, episode-tracking services
  screens/    # App screens (24 screens)
  widgets/    # Reusable UI components
  theme/      # App theme
```

## Getting Started

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (a version compatible with Dart `^3.9.2`)
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

## Push Notifications

The client is fully wired up (`lib/services/notification_service.dart`): it requests permission, stores each signed-in user's FCM token on their `users/{uid}` doc, and shows a local notification for foreground pushes. Actually **sending** a notification (new follower, friend activity) is a server-side job — see [`functions/`](functions/README.md) for the Cloud Functions that do this and how to deploy them. The app works normally without deploying them; you just won't receive pushes.

Platform setup already done in this repo: Android manifest permission + notification channel, iOS `Info.plist` background mode. Still required on iOS specifically (can't be done via file edits — needs your Apple Developer account): enable the **Push Notifications** capability in Xcode (Signing & Capabilities) and upload an APNs key to the Firebase console.

## Roadmap

See [plan.md](plan.md) for planned changes and improvements.
