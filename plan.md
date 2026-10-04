# WatchVerse — Change Plan

This document lists the gaps and suggested improvements found while reviewing the codebase, prioritized roughly by importance. Each item can be tackled independently.

## 🚧 IN PROGRESS (2026-10-04) — Pro/Patron tier split, resume here if interrupted

Implementing the ASO report's recommendation to split the single flat Pro
tier into **Pro** (functional — lists, stats, daily game, $1.99/mo ·
$14.99/yr, unchanged) and **Patron** (everything in Pro + profile themes +
badge + early access, $4.99/mo · $39.99/yr, new). Confirmed with the project
owner before starting.

**Done so far:**
- `ios/Configuration.storekit` — added `patron.monthly`/`patron.yearly` to
  the same subscription group as Pro, `groupNumber: 2` (StoreKit ranks them
  above Pro's `groupNumber: 1` for native upgrade/downgrade proration).
- `lib/services/pro_service.dart` — fully rewritten around a `ProTier {none,
  pro, patron}` enum instead of a single `bool isPro`. New: `patronMonthlyProductId`
  / `patronYearlyProductId` constants, `isPatron` / `isPatronStream` getters,
  `isPro`/`isProStream` now mean "Pro or Patron" (Patron includes Pro's
  perks). Persists the tier as an int (`watchverse_pro_tier`), with a
  one-time fallback read of the old `watchverse_pro_active` bool key.
- `lib/screens/edit_profile_screen.dart` — profile-theme gating switched
  from `isPro`/`isProStream` to `isPatron`/`isPatronStream` (themes are now
  Patron-exclusive, not Pro).

**Still to do, in order:**
1. **`lib/widgets/paywall_sheet.dart`** — still shows the OLD single-tier UI
   (one feature list, one set of plan tiles calling `ProService.instance
   .fetchPackages()` which now returns all 4 products mixed together). Needs
   a tier toggle (Pro / Patron segmented control) that filters which 2
   products show as plan tiles and which feature bullets display above them
   ("Everything in Pro, plus:" framing for the Patron side). This is the
   main remaining code change — **not started yet**.
2. **New ARB strings** needed in `lib/l10n/app_en.arb` + `app_tr.arb`, then
   `flutter gen-l10n`: tier labels ("Pro"/"Patron"), Patron's three
   exclusive-feature bullets (everything-in-Pro note, Patron badge, early
   access). Check whether `proFeatureProfile` ("Exclusive profile themes")
   already covers the themes bullet or needs tier-specific rewording.
3. **`dart analyze` + `flutter test`** — must stay clean, as every other
   change this session has.
4. **Create the two new subscription products in App Store Connect**
   (`com.example.watchVerse.patron.monthly` / `.yearly`, same subscription
   group as Pro, prices $4.99/$39.99) — this is the one piece that can't be
   done from the repo; the project owner needs to do this in App Store
   Connect → Monetization → Subscriptions, or ask Claude to attempt it via
   the App Store Connect API (auth already working this session — see the
   Xcode Cloud fix below for the JWT approach, `/tmp/asc_jwt.py`).
5. **New TestFlight build** once the above is done and tested locally —
   follow the existing pattern: bump `pubspec.yaml` version, `flutter build
   ipa --release --dart-define-from-file=secrets.json`, `xcrun altool
   --upload-app` with the API key at `~/.appstoreconnect/private_keys/`.
6. Commit + push, then update this file's §09 session log and the roadmap
   table in the (separately published, not in-repo) ASO artifact if it
   still needs updating.

**Why this matters if you're picking this up cold:** the app is
mid-refactor — `pro_service.dart`'s public API already changed (anything
checking the old single-tier shape would need `isPro` → still works, but
`isPatron` is new and `paywall_sheet.dart` hasn't been updated to actually
let a user purchase a Patron product yet, so Patron is currently
unreachable from the UI even though the backend/StoreKit side is ready for
it).

## 1. Security (High Priority)

- [x] **Get API keys out of source code.** Done: `apiKey` in `lib/services/api_service.dart` and `_apiKey` in `lib/services/giphy_service.dart` now read from `String.fromEnvironment(...)`, supplied via `flutter run --dart-define-from-file=secrets.json` (see `secrets.example.json` and the README setup steps). `secrets.json` is gitignored.
- [~] **Review Firestore security rules.** `firestore.rules` matches the data model in `lib/services/*.dart` and has been **deployed to production** since 2026-07-26. The known simplification — `SocialService.follow()`/`unfollow()`/`block()` and `CommentService`'s like toggle writing directly to *another* user's `followers`/`likes` array from the client — was tightened on 2026-10-03 via `isSelfOnlyArrayToggle()`, then **reverted the same day**: the function rejected any no-op `arrayRemove` (removing a uid already absent — a double-tap, a retry, or a desynced followers/following pair), and since `unfollow()` batches two writes atomically, that rejection silently rolled back the caller's own `following` update too — Unfollow appeared to instantly re-follow. Confirmed root cause; correct version needs each of added/removed to be *either empty or exactly the caller's own uid*, not required-to-be-exactly-one. Back to the original permissive gap until that's verified against the emulator (see §08).
- [x] **Comment/GIF content moderation.** Auto-hide workflow: `Comment.hidden` (new field, defaults `false`) is filtered out client-side in `CommentService.stream()`; the `onCommentReported` Cloud Function scaffold (`functions/src/index.ts`) sets `hidden: true` once a comment collects 3+ reports. Same deployment caveat as Notifications above — untested, not deployed.

## 2. Test Infrastructure (High Priority)

- [x] **Update `test/widget_test.dart`.** Done: replaced the default counter test with a smoke test that pumps `SplashScreen` in isolation (no Firebase/timer dependency).
- [x] **Add unit tests for the service layer.** Done for `ListService` and `MovieService` (11 unit tests using `fake_cloud_firestore` + `firebase_auth_mocks`); both services gained constructor-injectable Firestore/Auth for testability. `TvTrackingService` / `SocialService` are not yet covered — same pattern can be applied when needed.
- [x] **Add widget tests for critical screens.** `test/screens/auth_screens_test.dart`: 6 tests covering login/register form validation (empty submission, invalid email, short password, mismatched passwords). Required making `LoginScreen`/`RegisterScreen`'s `FirebaseAuth`/`DatabaseService` instances lazily/optionally injected (same pattern as `ListService`/`MovieService`) so tests never need a real Firebase app. Watchlist add/remove flow is not covered — would need `fake_cloud_firestore` wired into a full screen pump, a bigger lift than form validation.

## 3. Code Quality & Architecture (Medium Priority)

- [x] **Pick a state management strategy.** Decision: keep the existing `StatefulWidget` + Firestore-`Stream` architecture rather than adopting Provider/Riverpod — the per-screen pattern already works, and a framework-wide migration across 24 screens would be high-risk/high-effort for limited incremental value. Instead, the repeated boilerplate itself was extracted into shared widgets (next item).
- [x] **Shared error/loading state components.** Added `lib/widgets/async_state_view.dart` (`StreamListView`, `FutureListView`, `FutureValueView`) and migrated the 9 screens with the clearest duplication (history, watchlist, lists, up next, comments, blocked users, friends activity, follow list, person). This also fixed a real bug: 8 of those 9 screens never checked `snapshot.hasError`, so failures (e.g. a TMDB call with no API key) silently showed an infinite spinner or an empty state instead of an error message.
- [x] **Standardize the language of in-code comments.** Translated the Turkish comments found in `database_service.dart`, `settings_screen.dart`, and `splash_screen.dart` to English.

## 4. Product / Feature Roadmap (Low-Medium Priority)

- [~] **Notifications.** Client fully implemented: `lib/services/notification_service.dart` requests permission, registers/refreshes the FCM token on `users/{uid}.fcmToken`, and shows foreground pushes via `flutter_local_notifications`; wired into sign-in (`main.dart`) and sign-out (`profile_screen.dart`). Android manifest + iOS `Info.plist` updated. **Not deployed**: the Cloud Functions that actually send a push on new-follower / friend-activity events are scaffolded in `functions/` (TypeScript, untested) but require `firebase deploy` with an authenticated Firebase CLI and the project on the Blaze plan — see `functions/README.md`. iOS additionally needs the Push Notifications capability enabled in Xcode + an APNs key uploaded to the Firebase console (both require the project owner's Apple Developer account).
- [x] **Offline support.** Verified, no code change needed: `cloud_firestore` enables on-disk persistence by default on iOS/Android (the app's real targets — see "Supported Platforms"). Web does not enable it by default and would need an explicit `Settings(persistenceEnabled: true)` call, but `web/` is unmodified Flutter scaffolding with no `firebase.json` hosting config, i.e. not an actively deployed target — not worth configuring until it is.
- [x] **Localization.** Full rollout complete: all 27 remaining screens/widgets migrated on top of the 3-screen pilot, for 324 total `AppLocalizations` keys (English + Turkish in `lib/l10n/app_en.arb` / `app_tr.arb`). Verified with `dart analyze` (zero errors) and `flutter test`. Known gap: `movie_detail_screen.dart` and `up_next_screen.dart` format dates using a hardcoded English month-abbreviation array (`'Jan'`, `'Feb'`, …) rather than `intl`'s locale-aware `DateFormat` — left as-is since it's a formatting-logic change, not a string-extraction one; Turkish users will still see English month abbreviations in diary/episode dates.
- [x] **Light/dark theme toggle.** `AppColors` (`lib/theme/app_theme.dart`) is now a `ThemeExtension<AppColors>` with `dark`/`light` instances instead of static consts; a `context.colors` accessor replaced ~300 static `AppColors.x` references across 30 files. `ThemeController` (`lib/theme/theme_controller.dart`) persists the user's System/Light/Dark choice via `shared_preferences`; the picker lives in Settings → Appearance.

## 5. CI/CD and Documentation (Low Priority)

- [x] **Add a CI pipeline.** `.github/workflows/ci.yml` runs `dart analyze` + `flutter test` on every push/PR to `main`. (Fixed one pre-existing `unused_local_variable` warning in `tv_detail_screen.dart` that would otherwise have failed the very first run — `dart analyze` treats warnings as fatal by default.)
- [x] **CONTRIBUTING.md** — added, covering setup, workflow, code-style conventions (services, `context.colors`, `AppLocalizations`, `StreamListView`/`FutureListView`), and testing expectations.
- [x] **CHANGELOG.md** — started, with an `[Unreleased]` section summarizing this round of work.

## 6. Session — 2026-07-26

Post-watch poll redesign, account settings/deletion for App Store readiness, and a couple of theme/nav bugs. Handed off here for a second dev to continue.

- [x] **Poll redesign to match TV Time reference.** `lib/widgets/poll_widgets.dart` rebuilt: emoji options render bare (no colored circle behind them, matching the reference screenshots in `assets/tvtimess.jpg` / `tvshowtime-*.jpg`) with muted labels + bold percentages; grid tiles for platform/emotion, horizontal photo strip for favorite character (uses `CastMember.profilePath`); added a new 5-star "rate this episode/movie" category (`rating` in Firestore, cumulative star fill like TV Time's BAD/OK/GOOD/GREAT/WOW). New ARB keys: `pollRatingQuestionMovie/Episode`, `pollRatingBad/Ok/Good/Great/Wow`.
- [x] **Platform options are now real per-title data.** `PollCard` takes `providers: List<WatchProvider>` (fetched via `getWatchProviders` in both `movie_detail_screen.dart` and — newly — `episode_detail_screen.dart`, which didn't fetch providers before) plus `isMovie` (adds a "Cinema" option only for movies). Filtered/deduped against a fixed well-known-service allow-list (`_knownProviders` in `poll_widgets.dart`) so TMDB's rental/channel-addon noise ("HBO Max Amazon Channel" next to plain "HBO Max") doesn't show up. `PollService.platformOptions` (the old static list) removed.
- [x] **Fixed poll tap hit-testing bug.** `_PollTile`'s `GestureDetector` had no `behavior`, so taps landing on padding/gaps (not on the emoji glyph or a colored decoration) never registered — added `HitTestBehavior.opaque`.
- [x] **Fixed poll bottom-sheet overflow.** `_showPoll()` in both detail screens now wraps `PollCard` in `ConstrainedBox(maxHeight: 85% of screen) + SingleChildScrollView` instead of a bare `Padding` — the taller redesigned poll no longer overflows on smaller screens.
- [x] **Firestore rules were never deployed — this was the actual root cause of "can't vote on polls".** `firestore.rules` had a `/polls` match block written locally but the file's own header said "NOT DEPLOYED"; production rules had no such block and a catch-all deny, so every vote silently failed with `permission-denied`. Deployed (`firebase deploy --only firestore:rules`). Also added `ratingCounts`/`ratingTotal` to the allowed diff keys for the new rating category, and changed `users/{userId}`'s `allow delete` from `false` to `isOwner(userId)` (needed for account deletion below). **Takeaway for whoever edits `firestore.rules` next: it does nothing until you deploy it — there's no CI/hook enforcing that.**
- [x] **Profile screen decluttered.** Removed: the rank-number badge on the top-3 favorite movies, the inline avatar/name editing (moved to a new dedicated `lib/screens/edit_profile_screen.dart`, reachable from Settings, not from Profile — no more pencil icon on Profile), the email display (also removed from the Home drawer header), the "Your {year}" wrapped-style stats card, and the Friends Activity/Settings/Blocked Users/Sign Out tile list (all four consolidated into the Home screen's drawer — Blocked Users was added there since it had no other entry point; the drawer's sign-out now also clears the FCM token + shows errors, matching what Profile's version used to do). "See all" on the Movies tray now opens a new 3-column grid (`lib/screens/watched_movies_screen.dart`) instead of Watch History; "see all" on Series opens `UpNextScreen(initialTab: 1)` ("My Shows"). Watch History is now reachable only from the Home drawer.
- [x] **Settings rewritten for App Store submission.** Old version had a broken placeholder-avatar picker (literal `via.placeholder.com` URLs, never worked) and a duplicate name editor — both removed. Now: Appearance (unchanged), Account → Edit Profile (opens `EditProfileScreen`, which fetches its own data) and **Delete Account** (required by Apple guideline 5.1.1(v) for any app with account creation — confirmation dialog, then `_purgeUserData()` deletes every `users/{uid}` subcollection client-side in batches of 400 *before* deleting the Firestore profile doc and the Auth account, since the security rules gate all of that on `request.auth` still being valid), and About → live app version via the new `package_info_plus` dependency.
- [x] **Optional Cloud Functions backstop.** `functions/src/index.ts` gained `onUserDeleted` (Admin SDK `recursiveDelete` on `users/{uid}`) as a safety net in case the app is killed mid-purge. **Not required and not deployed** — the project is on the free Spark plan, which doesn't support Cloud Functions at all (confirmed by a failed deploy attempt); the client-side purge above is what actually runs. Deploy this later only if/when the project moves to Blaze.
- [x] **iOS `Info.plist` was missing `NSPhotoLibraryUsageDescription`.** `image_picker` (gallery access, used by the edit-profile photo picker) has called a protected API with no usage-description string this whole time — an automatic App Store rejection (or a crash on first access) waiting to happen. Added, plus `ITSAppUsesNonExemptEncryption: false` (app only does standard HTTPS, so it's genuinely exempt — skips the encryption question on every build upload).
- [x] **Bottom nav bar icons invisible in light mode.** `main_screen.dart`'s `CurvedNavigationBar` had `color: context.colors.surface` (pure white in light theme) behind hardcoded white icons. Changed to a fixed dark constant (`_navBarColor`) since the icons can't vary per-theme through this package's API anyway — treated as fixed brand chrome, same reasoning as the existing theme-invariant `posterScrim`. Audited every other `Colors.white` usage in `lib/` for the same class of bug; everything else sits on a gradient/colored background or a photographic backdrop, so nothing else needed changing.
- [x] **Privacy Policy / Terms of Service.** Done 2026-10-03: `docs/privacy-policy.html` and the new `docs/terms-of-service.html` are both hosted (Firebase Hosting, `watchvers.web.app`) and linked from Settings → About and the paywall sheet. See Session 2026-10-03 below for why this became urgent (the Pro subscription shipped without either).
- [~] **Full recursive account-data cleanup is client-side only, not atomic.** `AccountDeletionService.deleteAccount()` (`lib/services/account_deletion_service.dart`) still runs as a sequence of awaited Firestore batches — an interruption can still leave work undone (the `onUserDeleted` Cloud Function would eventually catch this, but only once/if the project moves off the free Spark plan). What changed on 2026-10-03: the profile doc delete now runs *before* the subcollection purge, not after, so an interruption leaves a missing profile (an obvious "mid-deletion" signal) instead of a fully intact profile sitting on empty subcollections — which is indistinguishable from real data loss and is what a real report matched (see Session 2026-10-03). Not a fix for the underlying non-atomicity, just a safer failure mode.

## 7. Session — 2026-08-09

WatchVerse Pro subscription (`in_app_purchase`, `lib/services/pro_service.dart` + `lib/widgets/paywall_sheet.dart`) and a Pro-exclusive daily "guess the movie" game (`lib/screens/daily_game_screen.dart`, deterministic day-index rotation through a 2000-movie pool seeded by `tool/seed_daily_game_pool.js`, no backend needed). Also fixed profile stats overflow and refreshed paywall pricing on every open instead of caching a stale query. Not documented here at the time — see Session 2026-10-03 for the fallout.

## 8. Session — 2026-10-03

Picked up after a long gap. Found: `pubspec.yaml` had an uncommitted `+16` version bump sitting for ~2 months; CI (GitHub Actions) green on the last push; `dart analyze`/`flutter test` clean. Then went deep on getting a real TestFlight build out and closing gaps the 2026-08-09 session left open.

- [x] **Privacy Policy was factually wrong, and there was no Terms of Service at all.** `docs/privacy-policy.html` still said "The app has no in-app purchases" — no longer true after the Pro subscription shipped. Fixed the claim, added a payment-data section (Apple handles billing, WatchVerse never sees it), and wrote `docs/terms-of-service.html` from scratch (auto-renewal/cancellation/refund terms, Apple's required minimum EULA clauses). Both linked from Settings → About and the paywall sheet (`lib/services/legal_links.dart`), both deployed to `watchvers.web.app`. This closes the Session 2026-07-26 item 50 gap, which became an actual App Store compliance risk once Pro shipped without anyone circling back to it.
- [x] **Daily game was unreachable by anyone.** It's gated behind `ProService.instance.isPro` in `home_screen.dart`'s drawer, but the Pro subscription products were never purchasable in App Store Connect (see next item) — so no tester could ever pass the gate. Temporarily removed the gate (commented inline in `home_screen.dart`) so the game is free for everyone until the subscription is confirmed working end-to-end; re-add the `if (!ProService.instance.isPro)` guard once it is.
- [x] **Apple's Paid Applications Agreement wasn't active**, which was silently blocking both IAP product availability and `altool` uploads (`FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED`) — signed in App Store Connect → Business → Agreements, Tax, and Banking. Took a while to propagate even after showing "Active" in the UI.
- [x] **Xcode 27 refused to archive the project at all.** `ios/Podfile`'s `post_install` never clamped individual Pods' `IPHONEOS_DEPLOYMENT_TARGET` to the app's 15.0 floor, and newer Xcode treats any sub-15.0 target in the workspace as a hard error rather than a warning. Fixed by forcing every pod target to 15.0 in `post_install`.
- [x] **First successful TestFlight upload**, build `1.0.0+17` (build `+16` turned out to already be registered in App Store Connect from an earlier attempt, so the version had to bump again). Uploaded via `xcrun altool --upload-app` using an App Store Connect API key (`~/.appstoreconnect/private_keys/`) rather than an Apple ID/password.
- [x] **Xcode Cloud (separate from the GitHub Actions `CI` workflow) had never actually built successfully.** No `ios/ci_scripts/ci_post_clone.sh` existed, so it archived with no Flutter SDK, no `flutter pub get`, no `pod install` — failing on a missing `Generated.xcconfig` every time. Added the standard script, pinned to Flutter 3.35.5 to match `.github/workflows/ci.yml`.
- [~] **Attempted to close the `followers`/`likes` count-manipulation gap in `firestore.rules`**, deployed, then **reverted the next day** after it broke unfollow in production — see Session 2026-10-04 and item 1 above for the confirmed root cause. Also fixed the rules file's header, which still falsely claimed "NOT DEPLOYED" despite being live since 2026-07-26 — the same stale claim that caused the 2026-07-26 polls bug once already; that header fix stands regardless of the revert.
- [~] **`SocialService`'s friends-feed fan-out reads one profile doc per followed user, per call.** `friendsActivity()`, `friendsWatchedMovies()`, and `friendsWatchedShows()` each looped `_users.doc(u).get()` inside their per-friend `Future.wait` — up to 20 extra reads per method, every feed load. Batched into one `_profilesByUid()` call per method via `where(FieldPath.documentId, whereIn: uids)` (cap 30, comfortably above the existing 20-friend limit). Cuts the N profile reads to 1 per call site; the N per-friend *content* queries (activity/movies/shows subcollections) are unchanged — eliminating those needs a `uid` field on every activity/movie/show doc plus a `collectionGroup` query (bigger blast radius: write-path changes across `MovieService`/`TvTrackingService`, a new composite index, and a backfill gap for existing docs) — deferred until there's a real follow-graph large enough to justify it.
- [ ] **Unresolved: a real "my data disappeared" report.** The project owner reported an older TestFlight/App Store build showing an empty library (movies, follows, watch history) while the profile doc (name/photo) loaded fine — on the same account, same email, re-login didn't help. That split (top-level doc intact, subcollections empty) is consistent with `AccountDeletionService.deleteAccount()` (see item 51 above) being triggered and interrupted after `_purgeOwnData()` but before the final account/profile delete — but this was **not confirmed**, only hypothesized; the investigation was dropped before getting read access to Firestore (would need `gcloud auth application-default login` run by the project owner). This project has no Firestore backups (free Spark plan), so if it is real data loss, it is almost certainly unrecoverable. **Revisit this before trusting the account-deletion flow further**, and consider making `deleteAccount()` safer against interruption (e.g., delete the top-level profile doc *first* so a half-finished purge can't masquerade as a live, half-empty account).

## 9. Session — 2026-10-04

- [x] **Xcode Cloud was archiving against `ios/Runner.xcodeproj` instead of `ios/Runner.xcworkspace`**, which is why every build failed with `Module 'cloud_firestore' not found` even after the `ci_post_clone.sh` fix the day before — CocoaPods only links via the workspace. The App Store Connect UI's workflow editor didn't actually change this (user tried); fixed by calling the App Store Connect API directly (`PATCH /v1/ciWorkflows/{id}` with `containerFilePath: "ios/Runner.xcworkspace"`), authenticated with a hand-rolled ES256 JWT built from the existing API key via `openssl` (no `pyjwt`/`cryptography` installed) — script at `/tmp/asc_jwt.py` (not committed; regenerate if needed, it's ~40 lines). Triggered a manual build via `POST /v1/ciBuildRuns` to verify.
- [x] **Batched `SocialService`'s friends-feed profile lookups** — see item 68 above.
- [x] **Competitive & ASO research** — full writeup published as an artifact, not stored in-repo. Headline finding: TV Time (this app's entire UX reference — Up Next, the post-watch poll) shut down July 15, 2026 with 26M+ users; Bingers (TV Time's own founder), Hobi, and Trakt absorbed that wave within weeks. Five concrete pre-launch gaps identified: a name collision with an existing app called ViewVerse, no data-export story despite this being the one fear the category has now confirmed twice (TV Time deletion, Trakt's pricing bait-and-switch), no auto-tracking/scrobbling, a single flat Pro tier vs. competitors' tiered pricing, and the `SocialService` fan-out pattern (see item 68) as a cost-structure risk echoing TV Time's own postmortem.
- [x] **Live production bug: unfollow instantly re-followed.** Root cause and revert — see item 1 and item 67 above.
- [x] **Data export made free and complete**, per the ASO report's #1 "Now" item: `ExportService.exportAll()` replaces `exportDiaryCsv()` — now shares movies, shows, diary, and lists as four CSVs in one action (`MovieService.allMoviesOnce()` / `TvTrackingService.allShowsOnce()` added to support it). Removed the Pro gate in `SettingsScreen._exportData()` and the now-false "Export your data to CSV" Pro-feature bullet in the paywall sheet — a library should always be the user's to take elsewhere, not a subscription perk, especially in a category that's twice in 2026 validated the fear this answers.

---

**Note:** This list reflects observations based on the current state of the codebase; final prioritization and scope are up to the project owner.
