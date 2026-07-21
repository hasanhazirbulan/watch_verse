# Contributing to WatchVerse

## Getting set up

Follow the [Getting Started](README.md#getting-started) section in the README — install Flutter, run `flutter pub get`, and set up `secrets.json` (TMDB + Giphy API keys) before running the app.

## Workflow

1. Create a branch off `main` for your change.
2. Keep pull requests focused — one feature or fix per PR is easier to review than a bundle of unrelated changes.
3. Before opening a PR, run locally:
   ```
   dart analyze
   flutter test
   ```
   Both must pass; CI (`.github/workflows/ci.yml`) runs the same checks on every push and PR.
4. Write a commit message that explains *why*, not just *what* — the diff already shows what changed.

## Code style

- Follow the lint rules in `analysis_options.yaml` (based on `flutter_lints`); `dart analyze` will flag violations.
- Match the patterns already in the codebase rather than introducing a new one for a single feature:
  - Services are singletons exposed via `Service.instance` (see `lib/services/`), with Firestore/Auth constructor-injectable for testing (see `ListService`, `MovieService`).
  - Screens read colors via `context.colors.*` (see `lib/theme/app_theme.dart`), never hardcoded `Color(...)` values, so light/dark theming keeps working.
  - User-facing strings go through `AppLocalizations` (`l10n.someKey`), not string literals — see `lib/l10n/app_en.arb` / `app_tr.arb`. Add both an English and a Turkish entry for any new string.
  - Loading/error/empty states for `Stream`/`Future`-backed lists use `StreamListView` / `FutureListView` / `FutureValueView` (`lib/widgets/async_state_view.dart`) instead of hand-rolled `StreamBuilder`/`FutureBuilder` branching.
- Comments should be in English and explain *why* something non-obvious is done, not restate the code.

## Tests

- New service methods that touch Firestore/Auth should get unit tests using `fake_cloud_firestore` + `firebase_auth_mocks` (see `test/services/` for examples).
- Widget tests should avoid touching real Firebase — see `test/widget_test.dart` for how the splash screen is tested in isolation to sidestep that.

## Where things live

See [plan.md](plan.md) for the current state of known gaps and in-progress work — check it before starting something that might already be tracked there.
