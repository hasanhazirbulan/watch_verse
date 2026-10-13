// Emulator tests for the cross-user array toggles in ../../firestore.rules
// (`users/{uid}.followers`, `comments/{id}.likes`). Mirrors the exact writes
// made by SocialService.follow/unfollow/block, CommentService.toggleLike and
// AccountDeletionService's purge. Run: npm install && npm test
import { test, before, after, beforeEach, describe } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, writeBatch, arrayUnion, arrayRemove,
} from 'firebase/firestore';
import assert from 'node:assert/strict';

const ALICE = 'alice';
const BOB = 'bob';
const CAROL = 'carol';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-watchverse-rules',
    firestore: {
      // RULES_FILE lets you run the suite against another rules file (e.g. an
      // older revision) to compare behavior.
      rules: readFileSync(process.env.RULES_FILE ?? new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env?.cleanup();
});

/** Seed docs bypassing rules. */
async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

async function read(path) {
  let data;
  await env.withSecurityRulesDisabled(async (ctx) => {
    data = (await getDoc(doc(ctx.firestore(), path))).data();
  });
  return data;
}

const db = (uid) => env.authenticatedContext(uid).firestore();

// --- client-equivalent operations (lib/services/social_service.dart) ---
function follow(me, target) {
  const f = db(me);
  const b = writeBatch(f);
  b.set(doc(f, 'users', target), { followers: arrayUnion(me) }, { merge: true });
  b.set(doc(f, 'users', me), { following: arrayUnion(target) }, { merge: true });
  return b.commit();
}
function unfollow(me, target) {
  const f = db(me);
  const b = writeBatch(f);
  b.set(doc(f, 'users', target), { followers: arrayRemove(me) }, { merge: true });
  b.set(doc(f, 'users', me), { following: arrayRemove(target) }, { merge: true });
  return b.commit();
}
function block(me, target) {
  const f = db(me);
  const b = writeBatch(f);
  b.set(doc(f, 'users', me),
    { blocked: arrayUnion(target), following: arrayRemove(target) }, { merge: true });
  b.set(doc(f, 'users', target), { followers: arrayRemove(me) }, { merge: true });
  return b.commit();
}
// lib/services/comment_service.dart toggleLike
function like(me, id) {
  return updateDoc(doc(db(me), 'comments', id), { likes: arrayUnion(me) });
}
function unlike(me, id) {
  return updateDoc(doc(db(me), 'comments', id), { likes: arrayRemove(me) });
}

beforeEach(async () => {
  await env.clearFirestore();
  await seed(`users/${ALICE}`, { name: 'Alice', followers: [], following: [] });
  await seed(`users/${BOB}`, { name: 'Bob', followers: [], following: [] });
  await seed(`users/${CAROL}`, { name: 'Carol', followers: [], following: [] });
  await seed('comments/c1', { uid: BOB, text: 'hi', likes: [] });
});

describe('followers (users/{uid})', () => {
  test('follow succeeds and updates both sides', async () => {
    await assertSucceeds(follow(ALICE, BOB));
    assert.deepEqual((await read(`users/${BOB}`)).followers, [ALICE]);
    assert.deepEqual((await read(`users/${ALICE}`)).following, [BOB]);
  });

  test('unfollow after follow succeeds (batched: own following + target followers)', async () => {
    await assertSucceeds(follow(ALICE, BOB));
    await assertSucceeds(unfollow(ALICE, BOB));
    assert.deepEqual((await read(`users/${BOB}`)).followers, []);
    assert.deepEqual((await read(`users/${ALICE}`)).following, []);
  });

  test('double unfollow (no-op arrayRemove) succeeds — the 2026-10-04 regression', async () => {
    await assertSucceeds(follow(ALICE, BOB));
    await assertSucceeds(unfollow(ALICE, BOB));
    await assertSucceeds(unfollow(ALICE, BOB));
    assert.deepEqual((await read(`users/${BOB}`)).followers, []);
  });

  test('desynced pair: caller has target in following, but is absent from target followers', async () => {
    await seed(`users/${ALICE}`, { name: 'Alice', following: [BOB] });
    await seed(`users/${BOB}`, { name: 'Bob', followers: [CAROL] });
    await assertSucceeds(unfollow(ALICE, BOB));
    assert.deepEqual((await read(`users/${ALICE}`)).following, []);
    assert.deepEqual((await read(`users/${BOB}`)).followers, [CAROL]);
  });

  test('unfollow when target doc has no followers field at all succeeds', async () => {
    await seed(`users/${BOB}`, { name: 'Bob' });
    await assertSucceeds(unfollow(ALICE, BOB));
  });

  test('re-follow when already following (no-op arrayUnion) succeeds', async () => {
    await assertSucceeds(follow(ALICE, BOB));
    await assertSucceeds(follow(ALICE, BOB));
    assert.deepEqual((await read(`users/${BOB}`)).followers, [ALICE]);
  });

  test('block (batched, removes self from target followers) succeeds, incl. when not following', async () => {
    await assertSucceeds(follow(ALICE, BOB));
    await assertSucceeds(block(ALICE, BOB));
    assert.deepEqual((await read(`users/${BOB}`)).followers, []);
    await assertSucceeds(block(ALICE, CAROL)); // no-op remove on Carol
    assert.deepEqual((await read(`users/${ALICE}`)).blocked, [BOB, CAROL]);
  });

  test('adding someone ELSE\'s uid to followers is denied', async () => {
    const f = db(ALICE);
    await assertFails(setDoc(doc(f, 'users', BOB), { followers: arrayUnion(CAROL) }, { merge: true }));
    await assertFails(updateDoc(doc(f, 'users', BOB), { followers: [ALICE, CAROL] }));
  });

  test('removing someone ELSE\'s uid from followers is denied', async () => {
    await seed(`users/${BOB}`, { name: 'Bob', followers: [CAROL] });
    const f = db(ALICE);
    await assertFails(setDoc(doc(f, 'users', BOB), { followers: arrayRemove(CAROL) }, { merge: true }));
    await assertFails(updateDoc(doc(f, 'users', BOB), { followers: [] }));
  });

  test('swapping in self while removing another uid is denied', async () => {
    await seed(`users/${BOB}`, { name: 'Bob', followers: [CAROL] });
    await assertFails(updateDoc(doc(db(ALICE), 'users', BOB), { followers: [ALICE] }));
  });

  test('batched unfollow is all-or-nothing: a bad followers write rolls back own following', async () => {
    await seed(`users/${ALICE}`, { name: 'Alice', following: [BOB] });
    await seed(`users/${BOB}`, { name: 'Bob', followers: [ALICE, CAROL] });
    const f = db(ALICE);
    const b = writeBatch(f);
    b.set(doc(f, 'users', BOB), { followers: arrayRemove(ALICE, CAROL) }, { merge: true });
    b.set(doc(f, 'users', ALICE), { following: arrayRemove(BOB) }, { merge: true });
    await assertFails(b.commit());
    assert.deepEqual((await read(`users/${ALICE}`)).following, [BOB]);
  });

  test('non-owner cannot change other fields alongside followers', async () => {
    await assertFails(setDoc(doc(db(ALICE), 'users', BOB),
      { followers: arrayUnion(ALICE), name: 'pwned' }, { merge: true }));
  });

  test('unauthenticated follow is denied', async () => {
    const f = env.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(f, 'users', BOB), { followers: arrayUnion(ALICE) }, { merge: true }));
  });

  test('owner can still freely edit own followers/profile', async () => {
    await assertSucceeds(updateDoc(doc(db(BOB), 'users', BOB), { followers: [CAROL], name: 'Bobby' }));
  });

  test('account-deletion purge: removing own uid from followers of followed users', async () => {
    await seed(`users/${BOB}`, { name: 'Bob', followers: [ALICE, CAROL] });
    await assertSucceeds(setDoc(doc(db(ALICE), 'users', BOB), { followers: arrayRemove(ALICE) }, { merge: true }));
    assert.deepEqual((await read(`users/${BOB}`)).followers, [CAROL]);
  });
});

describe('likes (comments/{id})', () => {
  test('like succeeds', async () => {
    await assertSucceeds(like(ALICE, 'c1'));
    assert.deepEqual((await read('comments/c1')).likes, [ALICE]);
  });

  test('unlike after like succeeds', async () => {
    await assertSucceeds(like(ALICE, 'c1'));
    await assertSucceeds(unlike(ALICE, 'c1'));
    assert.deepEqual((await read('comments/c1')).likes, []);
  });

  test('double unlike (no-op arrayRemove) succeeds', async () => {
    await assertSucceeds(unlike(ALICE, 'c1'));
    await assertSucceeds(like(ALICE, 'c1'));
    await assertSucceeds(unlike(ALICE, 'c1'));
    await assertSucceeds(unlike(ALICE, 'c1'));
  });

  test('double like (no-op arrayUnion) succeeds', async () => {
    await assertSucceeds(like(ALICE, 'c1'));
    await assertSucceeds(like(ALICE, 'c1'));
    assert.deepEqual((await read('comments/c1')).likes, [ALICE]);
  });

  test('liking own comment succeeds', async () => {
    await assertSucceeds(like(BOB, 'c1'));
  });

  test('adding someone ELSE\'s uid to likes is denied', async () => {
    await assertFails(updateDoc(doc(db(ALICE), 'comments', 'c1'), { likes: arrayUnion(CAROL) }));
    await assertFails(updateDoc(doc(db(ALICE), 'comments', 'c1'), { likes: [ALICE, CAROL] }));
  });

  test('removing someone ELSE\'s uid from likes is denied', async () => {
    await seed('comments/c1', { uid: BOB, text: 'hi', likes: [CAROL] });
    await assertFails(updateDoc(doc(db(ALICE), 'comments', 'c1'), { likes: arrayRemove(CAROL) }));
    await assertFails(updateDoc(doc(db(ALICE), 'comments', 'c1'), { likes: [] }));
  });

  test('changing other comment fields alongside likes is denied', async () => {
    await assertFails(updateDoc(doc(db(ALICE), 'comments', 'c1'),
      { likes: arrayUnion(ALICE), text: 'edited' }));
  });

  test('unlike on comment without a likes field succeeds', async () => {
    await seed('comments/c2', { uid: BOB, text: 'old' });
    await assertSucceeds(unlike(ALICE, 'c2'));
  });
});
