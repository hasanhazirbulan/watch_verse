# WatchVerse Cloud Functions

Sends push notifications for new followers and friends' activity, and
auto-hides reported comments (see `src/index.ts`). This scaffold has **not
been deployed** — the Flutter app works fully without it; `NotificationService`
on the client side already registers each user's device token, but nothing
sends a push until these functions are deployed.

`onUserDeleted` is also here, but it's optional: `SettingsScreen`'s
delete-account flow already purges every `users/{uid}` subcollection itself
(client-side, no Admin SDK needed, since the schema is fixed) before deleting
the Auth account. `onUserDeleted` only exists as a backstop for the rare case
where the app is killed mid-purge — skip deploying it if you're staying on
the free Spark plan.

## Prerequisites

1. A Google account with access to this project's Firebase console.
2. The project must be on the **Blaze (pay-as-you-go)** plan — Cloud
   Functions with outbound calls (like sending via FCM) aren't available on
   the free Spark plan. Upgrading in the Firebase console doesn't cost
   anything unless usage exceeds the generous free tier.
3. [Node.js 20](https://nodejs.org/) and the Firebase CLI:
   ```
   npm install -g firebase-tools
   ```

## Deploy

```
firebase login
firebase use --add          # pick your Firebase project, run once
cd functions
npm install
cd ..
firebase deploy --only functions
```

## Verify

After deploying, follow a test account from another account, or mark a
movie/episode watched, and confirm a push arrives on a device signed into
the followed/watched-on account. Check `firebase functions:log` if nothing
arrives — the most common cause is the target user never having granted
notification permission (so `users/{uid}.fcmToken` is empty).
