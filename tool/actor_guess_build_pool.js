#!/usr/bin/env node
// Builds the bundled puzzle pool for the daily "Who's the Actor?" game
// (assets/games/actor_guess_pool.json, read by
// lib/services/actor_guess_service.dart). No backend: the app picks today's
// actor with `dayIndex % pool.length` (same EST-rollover day index as the
// daily movie game), so every clue the game shows is precomputed here and the
// app only hits TMDB for images and the guess search.
//
// Run (from the repo root):
//   node tool/actor_guess_build_pool.js
//
// The TMDB key is read from secrets.json (repo root, or any parent directory
// — git worktrees don't have their own copy) or the TMDB_API_KEY env var. It
// is never printed or written to the output.
//
// Reproducibility: candidate order is fully deterministic (score, then id)
// and the final order comes from a seeded shuffle (SEED below), so re-running
// against the same TMDB data yields the same file. TMDB's data drifts over
// time (popularity, vote counts), so a re-run months later will differ —
// that's expected; commit the regenerated asset when you mean to change the
// rotation. Raw TMDB responses are cached in os.tmpdir() so tuning the
// filters doesn't re-fetch everything (delete the cache dir to refresh).

const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

const SEED = 20261014;
const TARGET_POOL_SIZE = 450;
const MIN_POOL_SIZE = 365;
const TITLES_PER_ACTOR = 9;
const CONCURRENCY = 8;

// Candidate sources: popular people plus the top-billed cast of the most
// voted-on movies and shows (the most reliable "everyone knows them" signal).
const POPULAR_PEOPLE_PAGES = 60;
const TOP_MOVIE_PAGES = 40;
const TOP_TV_PAGES = 12;
const TOP_CAST_ORDER = 4; // billing positions 0..3

// "Well-known" bar, applied to the filtered acting credits (see below).
const FAMOUS_MOVIE_VOTES = 3000;
const FAMOUS_TV_VOTES = 800;
const MIN_FAMOUS_CREDITS = 5;

// Genres whose credits aren't acting roles: documentary, news, reality, talk.
const NON_ACTING_GENRES = new Set([99, 10763, 10764, 10767]);
const SELF_ROLE = /\b(self|himself|herself|themselves|host|co-host|presenter|narrator|archive footage|uncredited|cameo|various|additional voices?)\b/i;
const MIN_TV_EPISODES = 4;

// ------------------------------------------------------------------ key ---

function readApiKey() {
  if (process.env.TMDB_API_KEY) return process.env.TMDB_API_KEY;
  let dir = path.resolve(__dirname, '..');
  for (let i = 0; i < 8; i++) {
    const candidate = path.join(dir, 'secrets.json');
    if (fs.existsSync(candidate)) {
      const key = JSON.parse(fs.readFileSync(candidate, 'utf8')).TMDB_API_KEY;
      if (key) return key;
    }
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  console.error('No TMDB_API_KEY found (secrets.json or env).');
  process.exit(1);
}

const API_KEY = readApiKey();
const CACHE_DIR = path.join(os.tmpdir(), 'watchverse_actor_guess_cache');
fs.mkdirSync(CACHE_DIR, { recursive: true });

// ---------------------------------------------------------------- fetch ---

async function tmdb(pathAndQuery) {
  const cacheFile = path.join(
    CACHE_DIR,
    crypto.createHash('sha1').update(pathAndQuery).digest('hex') + '.json',
  );
  if (fs.existsSync(cacheFile)) return JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
  const sep = pathAndQuery.includes('?') ? '&' : '?';
  const url = `https://api.themoviedb.org/3${pathAndQuery}${sep}api_key=${API_KEY}&language=en-US`;
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(url);
    if (res.ok) {
      const data = await res.json();
      fs.writeFileSync(cacheFile, JSON.stringify(data));
      return data;
    }
    if (res.status === 404) return null;
    if (attempt >= 4) throw new Error(`TMDB ${res.status} for ${pathAndQuery}`);
    await new Promise((r) => setTimeout(r, 1000 * (attempt + 1)));
  }
}

async function runPool(jobs, worker) {
  const queue = [...jobs];
  let done = 0;
  await Promise.all(
    Array.from({ length: CONCURRENCY }, async () => {
      while (queue.length) {
        const job = queue.shift();
        await worker(job);
        done++;
        if (done % 200 === 0) console.log(`  ...${done}/${jobs.length}`);
      }
    }),
  );
}

// -------------------------------------------------------------- helpers ---

/** Lowercase, diacritics stripped — mirrors normalizeActorName() in Dart. */
function normalize(s) {
  return (s || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/** True when [text] contains any 3+ letter word of the actor's name. */
function leaksName(text, name) {
  const words = new Set(normalize(text).split(' '));
  return normalize(name)
    .split(' ')
    .filter((t) => t.length >= 3)
    .some((t) => words.has(t) || [...words].some((w) => w.length > 4 && w.startsWith(t) && t.length >= 5));
}

function yearOf(credit) {
  const d = credit.release_date || credit.first_air_date || '';
  const y = parseInt(d.slice(0, 4), 10);
  return Number.isFinite(y) && y >= 1900 ? y : null;
}

const COUNTRY_ALIASES = {
  'usa': 'USA',
  'us': 'USA',
  'u s a': 'USA',
  'u s': 'USA',
  'united states': 'USA',
  'united states of america': 'USA',
  'uk': 'UK',
  'u k': 'UK',
  'united kingdom': 'UK',
  'england': 'UK',
  'scotland': 'UK',
  'wales': 'UK',
  'northern ireland': 'UK',
  'great britain': 'UK',
  'west germany': 'Germany',
  'east germany': 'Germany',
  'ussr': 'Russia',
  'soviet union': 'Russia',
  'russian federation': 'Russia',
  'republic of korea': 'South Korea',
  'korea': 'South Korea',
  'england uk': 'UK',
  'hong kong': 'Hong Kong',
  'british hong kong': 'Hong Kong',
  'dominion of new zealand': 'New Zealand',
  'british nigeria': 'Nigeria',
  // TMDB occasionally stores the birthplace in another language.
  'stany zjednoczone': 'USA',
  'estados unidos': 'USA',
  'etats unis': 'USA',
  'vereinigte staaten': 'USA',
  'stati uniti': 'USA',
  'reino unido': 'UK',
  'royaume uni': 'UK',
  'deutschland': 'Germany',
  'italia': 'Italy',
  'espana': 'Spain',
};

function countryOf(placeOfBirth) {
  if (!placeOfBirth) return null;
  let p = placeOfBirth.trim();
  const now = p.match(/\[now ([^\]]+)\]/i);
  if (now) p = now[1];
  p = p.replace(/\[[^\]]*\]|\([^)]*\)/g, '').trim();
  const last = p.split(',').map((s) => s.trim()).filter(Boolean).pop();
  if (!last) return null;
  // Non-Latin place names (TMDB sometimes stores them in the local script)
  // would be unreadable to most players.
  if (!/^[\p{Script=Latin}\s.'-]+$/u.test(last)) return null;
  return COUNTRY_ALIASES[normalize(last)] || last;
}

function cleanCharacter(raw) {
  if (!raw) return null;
  let c = raw.split(/\s+\/\s+|;/)[0];
  c = c.replace(/\([^)]*\)/g, '').replace(/\s+/g, ' ').trim();
  c = c.replace(/^["'“]+|["'”]+$/g, '').trim();
  if (c.length < 3 || SELF_ROLE.test(c)) return null;
  // Single generic nouns ("Doctor", "Waitress") aren't a fun clue.
  if (!/\s/.test(c) && /^(man|woman|girl|boy|doctor|nurse|cop|officer|soldier|guard|waitress|waiter|dad|mom|mum|daddy|mommy|dancer|singer|reporter|student|teacher|mother|father|wife|husband|friend|bartender|driver|thug|agent|detective)$/i.test(c)) {
    return null;
  }
  return c;
}

/** Rough franchise grouping: "Toy Story 3" / "John Wick: Chapter 2" -> base. */
function franchiseKey(title) {
  return normalize(title.split(/:| - /)[0])
    .replace(/^the /, '')
    .replace(/ (\d+|ii|iii|iv|v|vi|part \w+)$/, '')
    .trim();
}

function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ----------------------------------------------------------- candidates ---

async function collectCandidates() {
  const ids = new Set();
  const listJobs = [];
  for (let p = 1; p <= POPULAR_PEOPLE_PAGES; p++) listJobs.push(['people', `/person/popular?page=${p}`]);
  for (let p = 1; p <= TOP_MOVIE_PAGES; p++) {
    listJobs.push(['movie', `/discover/movie?sort_by=vote_count.desc&include_adult=false&page=${p}`]);
  }
  for (let p = 1; p <= TOP_TV_PAGES; p++) {
    listJobs.push(['tv', `/discover/tv?sort_by=vote_count.desc&page=${p}`]);
  }
  const titles = [];
  console.log('Fetching candidate lists...');
  await runPool(listJobs, async ([kind, q]) => {
    const data = await tmdb(q);
    for (const r of data?.results ?? []) {
      if (kind === 'people') {
        if (!r.adult && r.known_for_department === 'Acting') ids.add(r.id);
      } else {
        titles.push([kind, r.id]);
      }
    }
  });
  console.log(`Fetching cast of ${titles.length} top titles...`);
  await runPool(titles, async ([kind, id]) => {
    const data = await tmdb(`/${kind}/${id}/credits`);
    for (const c of data?.cast ?? []) {
      if (!c.adult && c.order < TOP_CAST_ORDER && c.known_for_department === 'Acting') ids.add(c.id);
    }
  });
  return [...ids].sort((a, b) => a - b);
}

// ---------------------------------------------------------------- build ---

function buildEntry(person) {
  if (!person || person.adult || person.known_for_department !== 'Acting') return null;
  if (!person.profile_path || !person.name) return null;
  const country = countryOf(person.place_of_birth);
  if (!country) return null;

  const seen = new Set();
  const credits = [];
  for (const c of person.combined_credits?.cast ?? []) {
    if (c.adult || !c.id) continue;
    if ((c.genre_ids ?? []).some((g) => NON_ACTING_GENRES.has(g))) continue;
    if (c.character && SELF_ROLE.test(c.character)) continue;
    const type = c.media_type === 'tv' ? 'tv' : c.media_type === 'movie' ? 'movie' : null;
    if (!type) continue;
    if (type === 'tv' && (c.episode_count ?? 0) < MIN_TV_EPISODES) continue;
    const title = type === 'tv' ? c.name : c.title;
    if (!title || leaksName(title, person.name)) continue;
    const key = `${type}:${c.id}`;
    if (seen.has(key)) continue;
    seen.add(key);
    credits.push({ ...c, type, title, year: yearOf(c) });
  }
  if (credits.length === 0) return null;

  // Debut: year of their first *movie* role of any size. TV is skipped on
  // purpose — a TV credit's date is the show's first air date, not the
  // actor's (a soap that began in 1970 made Michael B. Jordan "debut" then).
  // Years before the actor turned 2 are data noise (re-releases, archive).
  const birthYear = parseInt((person.birthday || '').slice(0, 4), 10);
  const debutYear = Math.min(
    ...(person.combined_credits?.cast ?? [])
      .filter((c) => c.media_type === 'movie' && !c.adult)
      .filter((c) => !(c.genre_ids ?? []).some((g) => NON_ACTING_GENRES.has(g)))
      .filter((c) => !(c.character && SELF_ROLE.test(c.character)))
      .map(yearOf)
      .filter((y) => y != null && (!Number.isFinite(birthYear) || y >= birthYear + 2)),
  );
  if (!Number.isFinite(debutYear)) return null;

  const ranked = credits
    .filter((c) => c.poster_path && c.year != null && (c.vote_count ?? 0) > 0)
    .sort((a, b) => b.vote_count - a.vote_count || a.id - b.id);
  const famous = ranked.filter((c) =>
    c.type === 'movie' ? c.vote_count >= FAMOUS_MOVIE_VOTES : c.vote_count >= FAMOUS_TV_VOTES,
  );
  if (famous.length < MIN_FAMOUS_CREDITS || ranked.length < TITLES_PER_ACTOR) return null;

  // One title per franchise first (three Twilight posters make a dull clue),
  // then top up in vote order if that leaves too few.
  const titles = [];
  const franchises = new Set();
  for (const c of ranked) {
    if (titles.length >= TITLES_PER_ACTOR) break;
    const key = franchiseKey(c.title);
    if (franchises.has(key)) continue;
    franchises.add(key);
    titles.push(c);
  }
  for (const c of ranked) {
    if (titles.length >= TITLES_PER_ACTOR) break;
    if (!titles.includes(c)) titles.push(c);
  }
  titles.sort((a, b) => b.vote_count - a.vote_count || a.id - b.id);

  // Famous character: a leading role in one of their most voted-on titles
  // (top billing preferred), whose name doesn't give the actor away.
  let character = null;
  for (const maxOrder of [1, 3]) {
    for (const c of ranked.slice(0, 15)) {
      if (c.type === 'movie' && (c.order ?? 99) > maxOrder) continue;
      // TV character strings for guest/voice spots are often junk
      // ("Wild Wild West" for Sam Elliott in Family Guy) — series regulars only.
      if (c.type === 'tv' && (c.episode_count ?? 0) < 10) continue;
      const name = cleanCharacter(c.character);
      if (!name || leaksName(name, person.name)) continue;
      character = { name, title: c.title };
      break;
    }
    if (character) break;
  }
  if (!character) return null;

  // Fame score: votes of their biggest titles, discounted for supporting
  // parts so character actors in blockbusters don't outrank leads.
  const weight = (c) =>
    c.type === 'tv' ? ((c.episode_count ?? 0) >= 10 ? 1 : 0.3) : (c.order ?? 99) <= 2 ? 1 : 0.3;
  const score = ranked
    .map((c) => c.vote_count * weight(c))
    .sort((a, b) => b - a)
    .slice(0, TITLES_PER_ACTOR)
    .reduce((s, v) => s + v, 0);
  return {
    score,
    entry: {
      id: person.id,
      name: person.name,
      profilePath: person.profile_path,
      debutYear,
      country,
      character,
      titles: titles.map((c) => ({
        id: c.id,
        type: c.type,
        title: c.title,
        year: c.year,
        posterPath: c.poster_path,
      })),
    },
  };
}

async function main() {
  const ids = await collectCandidates();
  console.log(`Fetching details for ${ids.length} candidate people...`);
  const built = [];
  await runPool(ids, async (id) => {
    const person = await tmdb(`/person/${id}?append_to_response=combined_credits`);
    const b = buildEntry(person);
    if (b) built.push(b);
  });
  built.sort((a, b) => b.score - a.score || a.entry.id - b.entry.id);
  const chosen = built.slice(0, TARGET_POOL_SIZE).map((b) => b.entry);
  if (chosen.length < MIN_POOL_SIZE) {
    throw new Error(`Only ${chosen.length} actors qualified (need ${MIN_POOL_SIZE}).`);
  }

  // Seeded Fisher-Yates so famous faces are spread across the year rather
  // than front-loaded.
  const rand = mulberry32(SEED);
  for (let i = chosen.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [chosen[i], chosen[j]] = [chosen[j], chosen[i]];
  }

  const out = path.join(__dirname, '..', 'assets', 'games', 'actor_guess_pool.json');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, JSON.stringify({ version: 1, seed: SEED, actors: chosen }) + '\n');
  console.log(`Wrote ${chosen.length} actors (of ${built.length} qualifying) to ${path.relative(process.cwd(), out)}.`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
