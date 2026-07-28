/**
 * Cloud Functions for WatchVerse.
 *
 * This is a scaffold, not a deployed function. Deploying requires the
 * Firebase CLI authenticated against this project's Firebase account and
 * the project on the Blaze (pay-as-you-go) plan — see functions/README.md.
 *
 *   - onNewFollower: fires when `users/{uid}.followers` gains an entry
 *     (SocialService.follow() in the Flutter app) and notifies the
 *     newly-followed user. Needs lib/services/notification_service.dart's
 *     FCM token registration to have run for the target user.
 *   - onNewActivity: fires when a doc is created under
 *     `users/{uid}/activity/{activityId}` (written by MovieService /
 *     TvTrackingService when something is marked watched) and notifies
 *     that user's followers.
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
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";
import * as functionsV1 from "firebase-functions/v1";

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

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
      { type: "follow", actorUid: followerUid }
    );
  }
});

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

    const body =
      activity.kind === "movie"
        ? `${actorName} watched ${activity.title ?? "a movie"}`
        : activity.kind === "season"
        ? `${actorName} finished a season of ${activity.showName ?? "a show"}`
        : `${actorName} watched an episode of ${activity.showName ?? "a show"}`;

    // Fan-out is sequential and capped for simplicity; for a large follower
    // base, batch via messaging.sendEachForMulticast (500 tokens/call) instead.
    for (const followerUid of followers.slice(0, 500)) {
      await sendToUser(followerUid, "Friend activity", body, {
        type: "activity",
        actorUid,
      });
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
