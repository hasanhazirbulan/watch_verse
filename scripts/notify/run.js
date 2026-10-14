'use strict';

/**
 * Standalone notification runner — a Blaze-free alternative to the
 * equivalent logic in functions/src/index.ts, driven by GitHub Actions cron
 * instead of Cloud Functions triggers/scheduler (see
 * .github/workflows/notifications.yml). Do NOT deploy the notification
 * Cloud Functions (notifyEpisodesAiringTomorrow/Today, flushActivityDigests,
 * and onNewActivity's digest-enqueue path) alongside this — running both
 * would double-send.
 *
 * One real behavioral difference from the Cloud Functions version:
 * onNewActivity fired instantly on every new activity doc; here,
 * `activity-poll` mode runs on a fixed interval (see the workflow) and
 * catches up on everything created since the last run, tracked via a
 * cursor doc at `system/notificationCursor`. Shared-watch/digest
 * notifications land within one poll interval instead of immediately.
 *
 * Modes (set via the NOTIFY_MODE env var, one per scheduled run):
 *   episode-tomorrow  — shows with nextEpisodeAirDate == tomorrow
 *   episode-today     — shows with nextEpisodeAirDate == today
 *   movie-release     — watchlist movies with releaseDate == today
 *   activity-poll     — new activity since the last run: immediate
 *                        "shared watch" push, or enqueued into the
 *                        recipient's daily digest
 *   digest-flush      — sends one summary push per user for everything
 *                        activity-poll queued, then clears the queue
 */

const admin = require('firebase-admin');

const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
if (!serviceAccountJson) {
  throw new Error('FIREBASE_SERVICE_ACCOUNT env var is required (a service account JSON key).');
}
admin.initializeApp({ credential: admin.credential.cert(JSON.parse(serviceAccountJson)) });

const db = admin.firestore();
const messaging = admin.messaging();

/** Sends a push to one user's stored token, if any; logs (doesn't throw) on failure. */
async function sendToUser(uid, title, body, data) {
  const snap = await db.collection('users').doc(uid).get();
  const token = snap.data()?.fcmToken;
  if (!token) return;
  try {
    await messaging.send({ token, notification: { title, body }, data });
  } catch (err) {
    console.warn(`Failed to notify ${uid}: ${err.message}`);
  }
}

/** "YYYY-MM-DD" for today+[days], in UTC — matches the plain calendar dates
 *  TMDB (and therefore `nextEpisodeAirDate`) uses, which carry no timezone
 *  of their own. */
function isoDateOffset(days) {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

async function notifyEpisodes({ prefField, dayOffset, type, title, bodyFor }) {
  const date = isoDateOffset(dayOffset);
  const snap = await db.collectionGroup('shows').where('nextEpisodeAirDate', '==', date).get();
  console.log(`[${type}] ${snap.size} show(s) airing ${date}`);

  for (const showDoc of snap.docs) {
    const uid = showDoc.ref.parent.parent?.id;
    if (!uid) continue;
    const userSnap = await db.collection('users').doc(uid).get();
    if (userSnap.data()?.[prefField] === false) continue;

    const show = showDoc.data();
    await sendToUser(uid, title, bodyFor(show.name), {
      type,
      id: String(show.id),
      title: show.name || '',
      posterPath: show.posterPath || '',
      mediaType: 'tv',
    });
  }
}

/** "In theaters today" for movies on someone's watchlist whose TMDB release
 *  date is today. Loops over users and queries each user's own `movies`
 *  subcollection (single-field equality, auto-indexed at collection scope)
 *  instead of a collection-group query, which would need an index deploy.
 *  Fine at this app's size; switch to a collectionGroup query + a
 *  COLLECTION_GROUP override on movies.releaseDate if it grows. */
async function notifyMovieReleases() {
  const date = isoDateOffset(0);
  const users = await db.collection('users').select('fcmToken', 'notifyMovieRelease').get();
  let sent = 0;
  for (const user of users.docs) {
    const prefs = user.data();
    if (!prefs.fcmToken || prefs.notifyMovieRelease === false) continue;
    const movies = await user.ref.collection('movies').where('releaseDate', '==', date).get();
    for (const doc of movies.docs) {
      const m = doc.data();
      if (m.status !== 'watchlist') continue;
      await sendToUser(user.id, 'Out today', `${m.title} from your watchlist is released today. 🍿`, {
        type: 'movie-release',
        id: String(m.id),
        title: m.title || '',
        posterPath: m.posterPath || '',
        mediaType: 'movie',
      });
      sent++;
    }
  }
  console.log(`[movie-release] ${sent} notification(s) for ${date}`);
}

/** Adds one event to [uid]'s daily activity digest (count + up to 3 distinct
 *  actor names for the summary text). */
async function enqueueDigest(uid, actorName) {
  const ref = db.collection('users').doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.data()?.pendingActivityDigest ?? { count: 0, actorNames: [] };
    const actorNames = Array.from(new Set([...(current.actorNames || []), actorName])).slice(0, 3);
    tx.set(
      ref,
      {
        pendingActivityDigest: {
          count: (current.count || 0) + 1,
          actorNames,
          firstAt: current.count ? current.firstAt : admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      { merge: true }
    );
  });
}

async function pollActivity() {
  const cursorRef = db.collection('system').doc('notificationCursor');
  const cursorSnap = await cursorRef.get();
  const since = cursorSnap.data()?.lastProcessedAt ?? admin.firestore.Timestamp.fromMillis(0);

  const snap = await db
    .collectionGroup('activity')
    .where('at', '>', since)
    .orderBy('at', 'asc')
    .get();
  console.log(`[activity-poll] ${snap.size} new activity doc(s) since last run`);
  if (snap.empty) return;

  let latest = since;
  for (const doc of snap.docs) {
    const activity = doc.data();
    const actorUid = doc.ref.parent.parent?.id;
    if (!actorUid) continue;
    if (activity.at && activity.at.toMillis() > latest.toMillis()) latest = activity.at;

    const actorSnap = await db.collection('users').doc(actorUid).get();
    const actorName = actorSnap.data()?.name || 'Someone';
    const followers = actorSnap.data()?.followers || [];
    if (followers.length === 0) continue;

    const isMovie = activity.kind === 'movie';
    const contentId = isMovie ? activity.movieId : activity.showId;
    const contentCol = isMovie ? 'movies' : 'shows';
    const contentTitle = (isMovie ? activity.title : activity.showName) || '';
    const posterPath = activity.posterPath || '';

    for (const followerUid of followers.slice(0, 500)) {
      const followerSnap = await db.collection('users').doc(followerUid).get();
      const prefs = followerSnap.data() || {};

      const sharedDoc = contentId
        ? await db.collection('users').doc(followerUid).collection(contentCol).doc(String(contentId)).get()
        : null;

      if (sharedDoc?.exists && prefs.notifySharedWatch !== false) {
        await sendToUser(
          followerUid,
          'Shared watch',
          `${actorName} also watched ${contentTitle || "something you're watching"}.`,
          {
            type: 'shared-watch',
            actorUid,
            actorName,
            id: String(contentId ?? ''),
            title: contentTitle,
            posterPath,
            mediaType: isMovie ? 'movie' : 'tv',
          }
        );
        continue;
      }

      if (prefs.notifyFriendActivity !== false) {
        await enqueueDigest(followerUid, actorName);
      }
    }
  }

  await cursorRef.set({ lastProcessedAt: latest }, { merge: true });
}

async function flushDigests() {
  const snap = await db.collection('users').where('pendingActivityDigest.count', '>', 0).get();
  console.log(`[digest-flush] ${snap.size} user(s) with pending digest`);

  for (const doc of snap.docs) {
    const digest = doc.data().pendingActivityDigest;
    const shown = (digest.actorNames || []).slice(0, 2);
    const remaining = digest.count - shown.length;
    const body =
      digest.count === 1
        ? `${digest.actorNames?.[0] || 'Someone'} watched something new.`
        : remaining > 0
        ? `${shown.join(', ')} and ${remaining} more shared new activity.`
        : `${shown.join(' and ')} shared new activity.`;

    await sendToUser(doc.id, 'Friend activity', body, { type: 'activity-digest' });
    await doc.ref.set(
      { pendingActivityDigest: { count: 0, actorNames: [], firstAt: null } },
      { merge: true }
    );
  }
}

async function main() {
  const mode = process.env.NOTIFY_MODE;
  switch (mode) {
    case 'episode-tomorrow':
      await notifyEpisodes({
        prefField: 'notifyEpisodeTomorrow',
        dayOffset: 1,
        type: 'episode-tomorrow',
        title: 'New episode tomorrow',
        bodyFor: (name) => `${name} airs a new episode tomorrow.`,
      });
      break;
    case 'episode-today':
      await notifyEpisodes({
        prefField: 'notifyEpisodeToday',
        dayOffset: 0,
        type: 'episode-today',
        title: 'New episode today',
        bodyFor: (name) => `${name}'s new episode is out today! 🎬`,
      });
      break;
    case 'movie-release':
      await notifyMovieReleases();
      break;
    case 'activity-poll':
      await pollActivity();
      break;
    case 'digest-flush':
      await flushDigests();
      break;
    default:
      throw new Error(`Unknown NOTIFY_MODE: ${mode}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
