/**
 * Cloud Functions for WatchVerse.
 *
 * This is a scaffold, not a deployed function. Deploying requires the
 * Firebase CLI authenticated against this project's Firebase account and
 * the project on the Blaze (pay-as-you-go) plan — see functions/README.md.
 * The two scheduled functions below additionally need the Cloud Scheduler
 * API enabled (small/free at this app's scale, but a real prerequisite).
 *
 * ⚠️ This project is currently on the free Spark plan, which can't deploy
 * Cloud Functions v2 at all (Cloud Build/Artifact Registry require Blaze).
 * The notification logic below (onNewActivity's digest path,
 * flushActivityDigests, notifyEpisodesAiringTomorrow/Today) is therefore
 * ALSO implemented as a free GitHub Actions cron job instead — see
 * scripts/notify/run.js and .github/workflows/notifications.yml, which is
 * what's actually running in production right now. If this project ever
 * moves to Blaze and these functions get deployed, disable the
 * corresponding GitHub Actions schedules first (or vice versa) — running
 * both at once double-sends every notification.
 *
 *   - onNewFollower: fires when `users/{uid}.followers` gains an entry
 *     (SocialService.follow() in the Flutter app) and notifies the
 *     newly-followed user. Needs lib/services/notification_service.dart's
 *     FCM token registration to have run for the target user.
 *   - onNewActivity: fires when a doc is created under
 *     `users/{uid}/activity/{activityId}` (written by MovieService /
 *     TvTrackingService when something is marked watched). For each
 *     follower: if they already track/watch the same title, they get an
 *     immediate, high-priority "shared watch" push (bypasses the digest
 *     below); otherwise the event is queued into their
 *     `pendingActivityDigest` and flushed once a day by
 *     flushActivityDigests, so a busy day of friend activity doesn't turn
 *     into a stream of individual pushes.
 *   - flushActivityDigests: scheduled, once a day — sends one summary push
 *     per user for everything `onNewActivity` queued that day, then clears
 *     the queue.
 *   - notifyEpisodesAiringTomorrow / notifyEpisodesAiringToday: scheduled,
 *     once a day each — query every tracked show across every user
 *     (`collectionGroup('shows')`) for `nextEpisodeAirDate` matching
 *     tomorrow/today and notify the owner, respecting their per-type
 *     toggle. `nextEpisodeAirDate` is written by
 *     TvTrackingService._metadata() in the Flutter app, refreshed on every
 *     tracking write, so this needs no TMDB call from the function itself.
 *   - onCommentReported: fires when a doc is created under `reports/`
 *     (CommentService.report() in the Flutter app) and auto-hides the
 *     reported comment once it collects 3+ reports. This uses the Admin
 *     SDK, so it bypasses firestore.rules entirely — it's the only way a
 *     comment's `hidden` field gets set (no client path does).
 *   - onUserDeleted: fires when a Firebase Auth account is deleted. NOT the
 *     primary cleanup path — SettingsScreen's delete-account flow already
 *     purges every `users/{uid}` subcollection itself before calling
 *     `user.delete()` (the schema is fixed, so the client can enumerate it
 *     without an Admin SDK). This is only a backstop for the case where the
 *     app is killed mid-purge, using `recursiveDelete` to catch anything
 *     left behind. Safe to skip deploying if you're not on Blaze.
 */

import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import * as functionsV1 from "firebase-functions/v1";

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

const TIME_ZONE = "Europe/Istanbul";

/** Sends a push to one user's stored token, if any, and logs (doesn't throw) on failure. */
async function sendToUser(uid: string, title: string, body: string, data: Record<string, string>) {
  const snap = await db.collection("users").doc(uid).get();
  const token = snap.data()?.fcmToken as string | undefined;
  if (!token) return;

  try {
    await messaging.send({
      token,
      notification: { title, body },
      data,
    });
  } catch (err) {
    logger.warn(`Failed to notify ${uid}`, err);
  }
}

/** "YYYY-MM-DD" for today+[days], in UTC — matches the plain calendar dates
 *  TMDB (and therefore `nextEpisodeAirDate`) uses, which carry no timezone
 *  of their own. */
function isoDateOffset(days: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

export const onNewFollower = onDocumentWritten("users/{uid}", async (event) => {
  const before = (event.data?.before.data()?.followers as string[] | undefined) ?? [];
  const after = (event.data?.after.data()?.followers as string[] | undefined) ?? [];
  const newFollowers = after.filter((uid) => !before.includes(uid));
  if (newFollowers.length === 0) return;

  const targetUid = event.params.uid;
  for (const followerUid of newFollowers) {
    const followerSnap = await db.collection("users").doc(followerUid).get();
    const followerName = (followerSnap.data()?.name as string) || "Someone";
    await sendToUser(
      targetUid,
      "New follower",
      `${followerName} started following you.`,
      { type: "follow", actorUid: followerUid, actorName: followerName }
    );
  }
});

/** Adds one event to [uid]'s daily activity digest (count + up to 3 distinct
 *  actor names for the summary text), created if this is the first event
 *  since the last flush. */
async function enqueueDigest(uid: string, actorName: string) {
  const ref = db.collection("users").doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = (snap.data()?.pendingActivityDigest as
      | { count: number; actorNames: string[] }
      | undefined) ?? { count: 0, actorNames: [] };
    const actorNames = Array.from(new Set([...current.actorNames, actorName])).slice(0, 3);
    tx.set(
      ref,
      {
        pendingActivityDigest: {
          count: current.count + 1,
          actorNames,
          firstAt: current.count === 0 ? FieldValue.serverTimestamp() : (snap.data()?.pendingActivityDigest?.firstAt ?? FieldValue.serverTimestamp()),
        },
      },
      { merge: true }
    );
  });
}

export const onNewActivity = onDocumentCreated(
  "users/{uid}/activity/{activityId}",
  async (event) => {
    const actorUid = event.params.uid;
    const activity = event.data?.data();
    if (!activity) return;

    const actorSnap = await db.collection("users").doc(actorUid).get();
    const actorName = (actorSnap.data()?.name as string) || "Someone";
    const followers = (actorSnap.data()?.followers as string[] | undefined) ?? [];
    if (followers.length === 0) return;

    const isMovie = activity.kind === "movie";
    const contentId = isMovie ? activity.movieId : activity.showId;
    const contentCol = isMovie ? "movies" : "shows";
    const contentTitle = (isMovie ? activity.title : activity.showName) ?? "";
    const posterPath = (activity.posterPath as string) ?? "";

    // Fan-out is sequential and capped for simplicity; for a large follower
    // base, batch via messaging.sendEachForMulticast (500 tokens/call) instead.
    for (const followerUid of followers.slice(0, 500)) {
      const followerSnap = await db.collection("users").doc(followerUid).get();
      const prefs = followerSnap.data() ?? {};

      const sharedDoc = contentId
        ? await db.collection("users").doc(followerUid).collection(contentCol).doc(String(contentId)).get()
        : null;

      if (sharedDoc?.exists && prefs.notifySharedWatch !== false) {
        // Priority path: the follower already tracks/watched this exact
        // title too — sent immediately, and deliberately NOT folded into
        // the daily digest, since batching would bury the "in common" signal.
        await sendToUser(
          followerUid,
          "Shared watch",
          `${actorName} also watched ${contentTitle || "something you're watching"}.`,
          {
            type: "shared-watch",
            actorUid,
            actorName,
            id: String(contentId ?? ""),
            title: contentTitle,
            posterPath,
            mediaType: isMovie ? "movie" : "tv",
          }
        );
        continue;
      }

      if (prefs.notifyFriendActivity !== false) {
        await enqueueDigest(followerUid, actorName);
      }
    }
  }
);

export const flushActivityDigests = onSchedule(
  { schedule: "every day 19:00", timeZone: TIME_ZONE },
  async () => {
    const snap = await db
      .collection("users")
      .where("pendingActivityDigest.count", ">", 0)
      .get();

    for (const doc of snap.docs) {
      const digest = doc.data().pendingActivityDigest as {
        count: number;
        actorNames: string[];
      };
      const shown = digest.actorNames.slice(0, 2);
      const remaining = digest.count - shown.length;
      const body =
        digest.count === 1
          ? `${digest.actorNames[0] ?? "Someone"} watched something new.`
          : remaining > 0
          ? `${shown.join(", ")} and ${remaining} more shared new activity.`
          : `${shown.join(" and ")} shared new activity.`;

      await sendToUser(doc.id, "Friend activity", body, { type: "activity-digest" });

      await doc.ref.set(
        { pendingActivityDigest: { count: 0, actorNames: [], firstAt: null } },
        { merge: true }
      );
    }
  }
);

export const notifyEpisodesAiringTomorrow = onSchedule(
  { schedule: "every day 09:00", timeZone: TIME_ZONE },
  async () => {
    const tomorrow = isoDateOffset(1);
    const snap = await db
      .collectionGroup("shows")
      .where("nextEpisodeAirDate", "==", tomorrow)
      .get();

    for (const showDoc of snap.docs) {
      const uid = showDoc.ref.parent.parent?.id;
      if (!uid) continue;
      const userSnap = await db.collection("users").doc(uid).get();
      if (userSnap.data()?.notifyEpisodeTomorrow === false) continue;

      const show = showDoc.data();
      await sendToUser(
        uid,
        "New episode tomorrow",
        `${show.name} airs a new episode tomorrow.`,
        {
          type: "episode-tomorrow",
          id: String(show.id),
          title: (show.name as string) ?? "",
          posterPath: (show.posterPath as string) ?? "",
          mediaType: "tv",
        }
      );
    }
  }
);

export const notifyEpisodesAiringToday = onSchedule(
  // 20:00 rather than earlier: TMDB only gives a calendar date, not a time,
  // so waiting until evening makes it likely the episode has actually
  // dropped by the time this fires.
  { schedule: "every day 20:00", timeZone: TIME_ZONE },
  async () => {
    const today = isoDateOffset(0);
    const snap = await db
      .collectionGroup("shows")
      .where("nextEpisodeAirDate", "==", today)
      .get();

    for (const showDoc of snap.docs) {
      const uid = showDoc.ref.parent.parent?.id;
      if (!uid) continue;
      const userSnap = await db.collection("users").doc(uid).get();
      if (userSnap.data()?.notifyEpisodeToday === false) continue;

      const show = showDoc.data();
      await sendToUser(
        uid,
        "New episode today",
        `${show.name}'s new episode is out today! 🎬`,
        {
          type: "episode-today",
          id: String(show.id),
          title: (show.name as string) ?? "",
          posterPath: (show.posterPath as string) ?? "",
          mediaType: "tv",
        }
      );
    }
  }
);

const HIDE_AFTER_REPORT_COUNT = 3;

export const onCommentReported = onDocumentCreated("reports/{reportId}", async (event) => {
  const commentId = event.data?.data()?.commentId as string | undefined;
  if (!commentId) return;

  const reportsSnap = await db
    .collection("reports")
    .where("commentId", "==", commentId)
    .count()
    .get();

  if (reportsSnap.data().count >= HIDE_AFTER_REPORT_COUNT) {
    await db.collection("comments").doc(commentId).set({ hidden: true }, { merge: true });
    logger.info(`Auto-hid comment ${commentId} after ${reportsSnap.data().count} reports`);
  }
});

export const onUserDeleted = functionsV1.auth.user().onDelete(async (user) => {
  await db.recursiveDelete(db.collection("users").doc(user.uid));
  logger.info(`Purged Firestore data for deleted user ${user.uid}`);
});
