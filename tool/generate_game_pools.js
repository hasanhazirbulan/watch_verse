#!/usr/bin/env node
// Dev-time generator for the daily Frames and Title Wordle puzzle pools
// (lib/services/games/pools/*.g.dart). There is no server job: the pools ship
// inside the app and every device picks today's entry with the same
// deterministic day index (see lib/services/games/game_day.dart).
//
// What it does:
//   1. Pulls well-known titles from TMDB — movies and TV shows ranked by
//      vote_count (the clearest proxy for "famous enough to be fair"), with a
//      vote floor so the tail doesn't drift into obscure titles. TV excludes
//      news/reality/talk shows; movies exclude documentaries and TV movies.
//   2. Frames: keeps titles with >= 6 language-neutral backdrops
//      (iso_639_1 == null, i.e. no title text burned in) — the app fetches the
//      actual images at runtime and only needs the TMDB id.
//   3. Title Wordle: keeps titles whose English title normalizes (diacritics
//      stripped, punctuation dropped) to 5–8 letters A–Z, at most 3 words,
//      no digits, not on a small blocklist; de-duplicated by answer.
//   4. Sorts by id, shuffles with a fixed seed (so the output only changes
//      when TMDB's data does) and writes Dart constants.
//
// Run (from the repo root):
//   node tool/generate_game_pools.js [--secrets path/to/secrets.json]
//
// The TMDB key is read from the TMDB_API_KEY env var, else from secrets.json
// (default: repo root). It is never printed or written anywhere.

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const OUT_DIR = path.join(ROOT, 'lib/services/games/pools');

function readKey() {
  if (process.env.TMDB_API_KEY) return process.env.TMDB_API_KEY;
  const i = process.argv.indexOf('--secrets');
  const file = i > 0 ? process.argv[i + 1] : path.join(ROOT, 'secrets.json');
  try {
    const key = JSON.parse(fs.readFileSync(file, 'utf8')).TMDB_API_KEY;
    if (key) return key;
  } catch (_) {
    // fall through
  }
  console.error('No TMDB key: set TMDB_API_KEY or pass --secrets <secrets.json>.');
  process.exit(1);
}
const KEY = readKey();

const SEED = 20261014;
const MOVIE_PAGES = 150; // up to 3000 candidates by vote_count
const MOVIE_MIN_VOTES = 1000;
const TV_PAGES = 100; // up to 2000 candidates
const TV_MIN_VOTES = 200;
// Fame floors per pool. Non-English titles need a higher vote count to count
// as "well known" to an international audience (TMDB's English title of a
// local soap is not something most players could guess).
const FLOORS = {
  frames: { movie: { en: 3000, other: 5000 }, tv: { en: 600, other: 2000 } },
  wordle: { movie: { en: 1000, other: 3000 }, tv: { en: 250, other: 2000 } },
};
const famous = (game, type) => (c) => {
  const f = FLOORS[game][type];
  return c.voteCount >= (c.lang === 'en' ? f.en : f.other);
};
const FRAMES_MIN_STILLS = 6;
const CONCURRENCY = 8;

// Words that make a title unfit for a family-friendly daily puzzle.
const BLOCKLIST = ['SEX', 'FUCK', 'SHIT', 'PORN', 'NUDE', 'EROTIC', 'NYMPH', 'BITCH', 'WHORE', 'LOLITA'];

async function get(pathAndQuery, attempt = 0) {
  const sep = pathAndQuery.includes('?') ? '&' : '?';
  const url = `https://api.themoviedb.org/3${pathAndQuery}${sep}api_key=${KEY}`;
  try {
    const res = await fetch(url);
    if (res.status === 429 && attempt < 5) {
      await new Promise((r) => setTimeout(r, 1000 * (attempt + 1)));
      return get(pathAndQuery, attempt + 1);
    }
    // Never echo `url` — it carries the key.
    if (!res.ok) throw new Error(`TMDB ${res.status} for ${pathAndQuery}`);
    return res.json();
  } catch (e) {
    if (attempt < 3 && !String(e.message).startsWith('TMDB 4')) {
      await new Promise((r) => setTimeout(r, 500 * (attempt + 1)));
      return get(pathAndQuery, attempt + 1);
    }
    throw e;
  }
}

async function mapLimit(items, limit, fn) {
  const out = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const i = next++;
      out[i] = await fn(items[i], i);
    }
  }
  await Promise.all(Array.from({ length: limit }, worker));
  return out;
}

async function discover(type, pages, minVotes, extra) {
  const results = await mapLimit(
    Array.from({ length: pages }, (_, i) => i + 1),
    CONCURRENCY,
    (page) =>
      get(`/discover/${type}?language=en-US&include_adult=false&sort_by=vote_count.desc` +
        `&vote_count.gte=${minVotes}&page=${page}${extra}`).then((d) => d.results || []),
  );
  const seen = new Set();
  const out = [];
  for (const r of results.flat()) {
    if (seen.has(r.id) || r.adult) continue;
    seen.add(r.id);
    out.push({
      id: r.id,
      title: type === 'movie' ? r.title : r.name,
      date: (type === 'movie' ? r.release_date : r.first_air_date) || '',
      posterPath: r.poster_path || '',
      voteCount: r.vote_count || 0,
      lang: r.original_language || '',
    });
  }
  return out;
}

async function neutralBackdropCount(type, id) {
  const d = await get(`/${type}/${id}/images?include_image_language=null`);
  // Same filter as pickFrameStills() in lib/services/games/frames_logic.dart.
  return (d.backdrops || []).filter((b) => b.iso_639_1 == null && b.width >= 1280 &&
    b.aspect_ratio >= 1.6 && b.aspect_ratio <= 1.95).length;
}

/** Must stay in sync with normalizeTitle() in lib/services/games/title_wordle_logic.dart. */
function normalizeWords(title) {
  const ascii = title.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/&/g, ' ').toUpperCase();
  if (/[0-9]/.test(ascii)) return null;
  const words = ascii.split(/[\s\-–—:\/.,!?]+/)
    .map((w) => w.replace(/['’`"()]/g, ''))
    .filter((w) => w.length > 0);
  if (words.some((w) => !/^[A-Z]+$/.test(w))) return null;
  return words;
}

const ROMAN = /^(II|III|IV|V|VI|VII|VIII|IX|X|XI|XII)$/;

function wordleAnswer(title) {
  const words = normalizeWords(title);
  if (!words || words.length === 0 || words.length > 3) return null;
  // Sequel numerals ("Saw II", "Fast X") and stray initials ("Dept. Q") make
  // for unfair letter puzzles; a lone "I"/"A" ("I, Robot") is fine.
  if (words.some((w) => ROMAN.test(w) || (w.length === 1 && w !== 'I' && w !== 'A'))) return null;
  const letters = words.join('');
  if (letters.length < 5 || letters.length > 8) return null;
  if (BLOCKLIST.some((b) => letters.includes(b))) return null;
  return words.join(' ');
}

function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffled(items, seed) {
  const arr = [...items].sort((a, b) => a.id - b.id);
  const rand = mulberry32(seed);
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

const dartStr = (s) => `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$')}'`;
const year = (d) => (d && d.length >= 4 ? d.substring(0, 4) : '');

const HEADER = `// GENERATED by tool/generate_game_pools.js — do not edit by hand.
// Re-run the script to refresh; order is a fixed-seed shuffle.
// ignore_for_file: lines_longer_than_80_chars
`;

function writeFrames(movies, tv) {
  const list = (name, items) => `const ${name} = <int>[\n` +
    items.map((m) => `  ${m.id}, // ${m.title.replace(/\n/g, ' ')} (${year(m.date)})`).join('\n') +
    '\n];\n';
  fs.writeFileSync(path.join(OUT_DIR, 'frames_pools.g.dart'),
    `${HEADER}\n/// TMDB movie ids for the daily Frames puzzle (${movies.length}).\n` +
    list('framesMoviePool', movies) +
    `\n/// TMDB TV show ids for the daily Frames puzzle (${tv.length}).\n` +
    list('framesTvPool', tv));
}

function writeWordle(movies, tv) {
  const list = (name, items) => `const ${name} = <WordlePoolEntry>[\n` +
    items.map((m) => `  WordlePoolEntry(${m.id}, ${dartStr(m.title)}, ${dartStr(m.answer)}, ` +
      `${dartStr(m.posterPath)}, ${dartStr(year(m.date))}),`).join('\n') +
    '\n];\n';
  fs.writeFileSync(path.join(OUT_DIR, 'title_wordle_pools.g.dart'),
    `${HEADER}\nimport 'package:watch_verse/services/games/title_wordle_logic.dart';\n\n` +
    `/// Movie answers for the daily Title Wordle (${movies.length}).\n` +
    list('titleWordleMoviePool', movies) +
    `\n/// TV show answers for the daily Title Wordle (${tv.length}).\n` +
    list('titleWordleTvPool', tv));
}

function wordlePool(candidates, seed) {
  const seen = new Set();
  const out = [];
  // Highest vote_count first, so a duplicate answer keeps the famous one.
  for (const c of candidates) {
    const answer = wordleAnswer(c.title);
    if (!answer || !c.posterPath) continue;
    const key = answer.replace(/ /g, '');
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ ...c, answer });
  }
  return shuffled(out, seed);
}

async function framesPool(type, candidates, seed) {
  let done = 0;
  const counts = await mapLimit(candidates, CONCURRENCY, async (c) => {
    const n = await neutralBackdropCount(type, c.id).catch(() => 0);
    if (++done % 200 === 0) console.log(`  ${type} images: ${done}/${candidates.length}`);
    return n;
  });
  return shuffled(candidates.filter((_, i) => counts[i] >= FRAMES_MIN_STILLS), seed);
}

(async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  console.log('Fetching candidates…');
  const movies = await discover('movie', MOVIE_PAGES, MOVIE_MIN_VOTES, '&without_genres=99,10770');
  const tv = await discover('tv', TV_PAGES, TV_MIN_VOTES, '&without_genres=10763,10764,10767');
  console.log(`Candidates: ${movies.length} movies, ${tv.length} TV shows`);

  const wMovies = wordlePool(movies.filter(famous('wordle', 'movie')), SEED + 1);
  const wTv = wordlePool(tv.filter(famous('wordle', 'tv')), SEED + 2);
  console.log(`Title Wordle: ${wMovies.length} movies, ${wTv.length} TV`);
  writeWordle(wMovies, wTv);

  const fMovies = await framesPool('movie', movies.filter(famous('frames', 'movie')), SEED + 3);
  const fTv = await framesPool('tv', tv.filter(famous('frames', 'tv')), SEED + 4);
  console.log(`Frames: ${fMovies.length} movies, ${fTv.length} TV`);
  writeFrames(fMovies, fTv);
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
