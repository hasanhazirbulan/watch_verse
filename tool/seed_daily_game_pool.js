#!/usr/bin/env node
// One-off script: seeds `gameConfig/dailyMoviePool` in Firestore with a pool
// of well-known movie TMDB IDs for the daily guessing game
// (see lib/services/daily_game_service.dart). NOT a recurring job — run this
// once locally whenever you want to refresh/grow the pool, not on a schedule
// (the whole point of the deterministic day-index design is that no server
// job is needed for the game to keep working day to day).
//
// Pool size matters here: the game rotates through the pool by day index and
// wraps around, so a pool of N movies repeats every N days. 250 was too
// short (~8 months before repeats) — this now targets ~2000 (5+ years).
//
// Setup (once):
//   1. Auth: either run `gcloud auth application-default login`, or download
//      a service account key from Firebase Console → Project Settings →
//      Service Accounts → "Generate new private key" and set
//      GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json before running.
//   2. TMDB_API_KEY env var (same value as secrets.json's TMDB_API_KEY).
//
// Run:
//   TMDB_API_KEY=... node tool/seed_daily_game_pool.js
//
// Uses firebase-admin from functions/node_modules (already a dependency
// there for the notification Cloud Function) rather than adding a second
// package.json just for a one-off script.

const path = require('path');
const fs = require('fs');
const admin = require(path.join(__dirname, '../functions/node_modules/firebase-admin'));

const TMDB_API_KEY = process.env.TMDB_API_KEY;
if (!TMDB_API_KEY) {
  console.error('Set TMDB_API_KEY (see secrets.json) before running this script.');
  process.exit(1);
}

const PROJECT_ID = 'watchvers';
const TARGET_POOL_SIZE = 2000;

// Primary source: movies ranked purely by vote_count (the clearest available
// proxy for "globally well-known enough to be a fair guessing-game answer"),
// with a floor so the tail doesn't drift into obscure titles. TMDB caps
// discover at 500 pages/10,000 results; 120 pages (2,400 candidates) is
// comfortably enough headroom after the floor + de-dupe with the other two
// lists below.
const DISCOVER_PAGES = 120;
const DISCOVER_MIN_VOTES = 300;

// Supplementary sources: catch well-regarded titles that rank lower on raw
// vote_count (older classics, etc.) than sheer popularity would suggest.
const SUPPLEMENTARY_LISTS = ['/movie/popular', '/movie/top_rated'];
const SUPPLEMENTARY_PAGES = 25;

// Small concurrency so ~170 requests don't take forever sequentially, without
// hammering TMDB.
const CONCURRENCY = 6;

async function fetchPage(pathAndQuery) {
  const url = `https://api.themoviedb.org/3${pathAndQuery}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`TMDB request failed (${res.status}): ${pathAndQuery}`);
  const data = await res.json();
  return data.results ?? [];
}

async function runPool(jobs, worker) {
  const queue = [...jobs];
  const workers = Array.from({ length: CONCURRENCY }, async () => {
    while (queue.length) {
      const job = queue.shift();
      await worker(job);
    }
  });
  await Promise.all(workers);
}

async function collectCandidateIds() {
  const seen = new Map(); // id -> vote_count, de-duped across all sources

  const jobs = [];
  for (let page = 1; page <= DISCOVER_PAGES; page++) {
    jobs.push(
      `/discover/movie?api_key=${TMDB_API_KEY}&language=en-US&sort_by=vote_count.desc` +
        `&vote_count.gte=${DISCOVER_MIN_VOTES}&include_adult=false&page=${page}`,
    );
  }
  for (const listPath of SUPPLEMENTARY_LISTS) {
    for (let page = 1; page <= SUPPLEMENTARY_PAGES; page++) {
      jobs.push(`${listPath}?api_key=${TMDB_API_KEY}&language=en-US&page=${page}`);
    }
  }

  let done = 0;
  await runPool(jobs, async (query) => {
    const results = await fetchPage(query);
    for (const m of results) {
      if (m.id && (m.vote_count ?? 0) >= 100) {
        const prev = seen.get(m.id) ?? 0;
        seen.set(m.id, Math.max(prev, m.vote_count ?? 0));
      }
    }
    done++;
    if (done % 20 === 0) console.log(`  ...${done}/${jobs.length} pages fetched`);
  });

  // Highest vote_count first, so if we ever have more candidates than
  // TARGET_POOL_SIZE the ones cut are the least well-known.
  return [...seen.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([id]) => id);
}

const CACHE_PATH = path.join(__dirname, '.pool_cache.json');

async function main() {
  let ids;
  if (fs.existsSync(CACHE_PATH)) {
    console.log(`Using cached candidates from ${CACHE_PATH} (delete it to re-fetch from TMDB).`);
    ids = JSON.parse(fs.readFileSync(CACHE_PATH, 'utf8'));
  } else {
    console.log('Fetching candidate movies from TMDB...');
    ids = await collectCandidateIds();
    fs.writeFileSync(CACHE_PATH, JSON.stringify(ids));
    console.log(`Cached ${ids.length} candidates to ${CACHE_PATH}.`);
  }
  const pool = ids.slice(0, TARGET_POOL_SIZE);
  console.log(`Writing ${pool.length} of ${ids.length} candidates to gameConfig/dailyMoviePool.`);

  admin.initializeApp({ projectId: PROJECT_ID });
  const db = admin.firestore();
  await db.collection('gameConfig').doc('dailyMoviePool').set({
    movieIds: pool,
    seededAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`Done. Pool of ${pool.length} repeats every ${pool.length} days (~${(pool.length / 365).toFixed(1)} years).`);
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
