// Franchise/universe vocabulary for the "Plot" game's redaction.
//
// Only used by `tool/generate_plot_higher_lower_pools.dart` (and tests) when
// it precomputes the shipped puzzles — the app itself never imports this, so
// it isn't compiled into the build. Pure Dart, no Flutter imports.

import 'package:watch_verse/services/games/plot_guess_logic.dart';
//
// A TMDB overview of "The Dark Knight Rises" says "Batman" and "Gotham City"
// without either being in its title or its credits ("Bruce Wayne"), and the
// generic-word heuristics keep them because they show up across many films.
// [plotFranchiseVocabulary] gives the generator the per-title words to hide
// instead: the other titles in its collection/universe plus the curated
// universe terms below for every universe the title is recognised as part of.

/// One shared fictional universe.
class PlotUniverse {
  const PlotUniverse(this.key, {required this.triggers, required this.terms});

  /// Stable id, also used to group a universe's titles together when the
  /// generator decides which capitalized words are "generic".
  final String key;

  /// Lower-case phrases that mark a title as part of the universe when they
  /// appear as whole words in its title, collection (name or other films) or
  /// TMDB keywords, or capitalized in its overview or tagline (so "a doctor
  /// who realizes" isn't Doctor Who). Only terms that are unambiguous outside
  /// the universe ("jedi", "gotham", "galactic empire").
  final List<String> triggers;

  /// Words/phrases hidden (capitalized uses only) once the title is in the
  /// universe — including ones too ordinary to be triggers ("Empire",
  /// "Force", "Capitol", "District").
  final List<String> terms;
}

const plotUniverses = <PlotUniverse>[
  PlotUniverse('star-wars', triggers: [
    'star wars', 'jedi', 'sith', 'galactic empire', 'skywalker',
    'mandalorian', 'tatooine', 'death star', 'wookiee', 'obi-wan', 'kenobi',
    'darth vader', 'padawan', 'clone wars',
  ], terms: [
    'Star Wars', 'Jedi', 'Sith', 'Galactic Empire', 'Imperial', 'Empire',
    'Rebel Alliance', 'Rebels', 'Rebellion', 'Republic', 'Galactic Senate',
    'Separatists', 'Clone Wars', 'Clones', 'Death Star', 'First Order',
    'Resistance', 'Force', 'Tatooine', 'Coruscant', 'Naboo', 'Alderaan',
    'Dagobah', 'Hoth', 'Endor', 'Jakku', 'Kashyyyk', 'Mandalore',
    'Mandalorian', 'Wookiee', 'Ewok', 'Hutt', 'Skywalker', 'Kenobi', 'Vader',
    'Darth', 'Yoda', 'Palpatine', 'Padawan', 'Stormtrooper', 'Trade Federation',
  ]),
  PlotUniverse('dc', triggers: [
    'batman', 'gotham', 'arkham', 'bruce wayne', 'dark knight', 'joker',
    'harley quinn', 'superman', 'krypton', 'kryptonian', 'justice league',
    'wonder woman', 'aquaman', 'dc comics', 'dc extended universe', 'dceu',
    'dc universe', 'arrowverse', 'suicide squad', 'smallville',
  ], terms: [
    'Batman', 'Gotham', 'Arkham', 'Wayne', 'Joker', 'Catwoman', 'Penguin',
    'Riddler', 'Robin', 'Harley Quinn', 'Superman', 'Krypton', 'Kryptonian',
    'Metropolis', 'Smallville', 'Luthor', 'Justice League', 'Themyscira',
    'Amazons', 'Atlantis', 'Atlantean', 'Darkseid', 'Apokolips', 'Speed Force',
    'Suicide Squad', 'Task Force X', 'Belle Reve', 'Star City', 'Central City',
  ]),
  PlotUniverse('marvel', triggers: [
    'marvel cinematic universe', 'mcu', 'marvel comics', 'avengers',
    'wakanda', 'asgard', 'asgardian', 's.h.i.e.l.d', 'thanos', 'infinity stones',
    'x-men', 'spider-man', 'stark industries', 'vibranium', 'sokovia',
  ], terms: [
    'Avengers', 'Avenger', 'Marvel', 'Wakanda', 'Wakandan', 'Asgard',
    'Asgardian', 'Hydra', 'Stark', 'Thanos', 'Infinity Stones', 'Infinity',
    'Ultron', 'Hulk', 'Thor', 'Loki', 'Vibranium', 'Sokovia', 'Sokovia Accords',
    'Mjolnir', 'Xandar', 'Kree', 'Skrull', 'Skrulls', 'Nova Corps', 'Ravagers',
    'Quantum Realm', 'Multiverse', 'Spider-Man', 'Parker', 'Osborn', 'Oscorp',
    'X-Men', 'Xavier', 'Magneto', 'Wolverine', 'Mutants', 'Daily Bugle',
    'Hell\'s Kitchen', 'Time Variance Authority', 'Blip', 'SHIELD',
  ]),
  PlotUniverse('wizarding-world', triggers: [
    'harry potter', 'hogwarts', 'wizarding world', 'fantastic beasts',
    'voldemort', 'muggle', 'muggles', 'dumbledore', 'grindelwald',
  ], terms: [
    'Hogwarts', 'Muggle', 'Muggles', 'Voldemort', 'Dumbledore', 'Quidditch',
    'Gryffindor', 'Slytherin', 'Hufflepuff', 'Ravenclaw', 'Azkaban',
    'Ministry of Magic', 'Death Eaters', 'Horcrux', 'Horcruxes', 'Grindelwald',
    'Wizarding', 'Potter', 'Hagrid', 'Diagon Alley', 'Dark Lord',
  ]),
  PlotUniverse('middle-earth', triggers: [
    'middle-earth', 'middle earth', 'tolkien', 'lord of the rings', 'hobbit',
    'hobbits', 'mordor', 'sauron', 'rings of power', 'gandalf',
  ], terms: [
    'Middle-earth', 'Middle', 'Mordor', 'Sauron', 'Gandalf', 'Shire',
    'Hobbit', 'Hobbits', 'Gondor', 'Rohan', 'Rivendell', 'Isengard',
    'Saruman', 'Frodo', 'Bilbo', 'Erebor', 'Smaug', 'Númenor', 'Numenor',
    'Fellowship', 'Ring', 'Rings', 'Dark Lord', 'Elves', 'Dwarves',
  ]),
  PlotUniverse('star-trek', triggers: [
    'star trek', 'starfleet', 'klingon', 'klingons', 'uss enterprise',
    'romulan', 'romulans',
  ], terms: [
    'Star Trek', 'Starfleet', 'Enterprise', 'Federation', 'Klingon',
    'Klingons', 'Vulcan', 'Vulcans', 'Romulan', 'Romulans', 'Borg', 'Kirk',
    'Spock', 'Picard',
  ]),
  PlotUniverse('westeros', triggers: [
    'game of thrones', 'westeros', 'house of the dragon', 'targaryen',
    'iron throne', 'song of ice and fire', 'seven kingdoms',
  ], terms: [
    'Westeros', 'Essos', 'Iron Throne', 'King\'s Landing', 'Seven Kingdoms',
    'Targaryen', 'Targaryens', 'Lannister', 'Lannisters', 'Stark', 'Starks',
    'Winterfell', 'Night\'s Watch', 'Dothraki', 'Valyria', 'Valyrian',
    'Dragonstone', 'Baratheon', 'White Walkers',
  ]),
  PlotUniverse('dune', triggers: [
    'arrakis', 'atreides', 'harkonnen', 'fremen', 'bene gesserit',
  ], terms: [
    'Dune', 'Arrakis', 'Atreides', 'Harkonnen', 'Harkonnens', 'Fremen',
    'Spice', 'Caladan', 'Bene Gesserit', 'Muad\'Dib',
  ]),
  PlotUniverse('hunger-games', triggers: [
    'hunger games', 'panem', 'mockingjay', 'katniss',
  ], terms: [
    'Panem', 'Capitol', 'District', 'Mockingjay', 'Katniss', 'Tributes',
    'Hunger Games',
  ]),
  PlotUniverse('jurassic', triggers: [
    'jurassic park', 'jurassic world', 'isla nublar', 'isla sorna',
  ], terms: ['Jurassic', 'Isla Nublar', 'Isla Sorna', 'Nublar', 'InGen']),
  PlotUniverse('transformers', triggers: [
    'transformers', 'autobot', 'autobots', 'decepticon', 'decepticons',
    'cybertron',
  ], terms: [
    'Transformers', 'Autobot', 'Autobots', 'Decepticon', 'Decepticons',
    'Cybertron', 'Optimus Prime', 'Megatron', 'Bumblebee', 'Allspark',
  ]),
  PlotUniverse('avatar-pandora', triggers: [
    'na\'vi', 'omaticaya', 'avatar collection',
  ], terms: ['Pandora', 'Na\'vi', 'Navi', 'Omaticaya', 'Metkayina', 'RDA']),
  PlotUniverse('airbender', triggers: [
    'airbender', 'fire nation', 'water tribe', 'earth kingdom',
  ], terms: [
    'Avatar', 'Fire Nation', 'Water Tribe', 'Earth Kingdom', 'Air Nomads',
    'Airbender',
  ]),
  PlotUniverse('alien', triggers: [
    'xenomorph', 'weyland-yutani', 'nostromo', 'alien collection',
  ], terms: ['Weyland-Yutani', 'Weyland', 'Xenomorph', 'Nostromo', 'Ripley']),
  PlotUniverse('terminator', triggers: ['terminator', 'skynet', 'cyberdyne'],
      terms: ['Terminator', 'Terminators', 'Skynet', 'Cyberdyne', 'Connor']),
  PlotUniverse('james-bond', triggers: ['james bond', '007'],
      terms: ['Bond', '007', 'MI6', 'SPECTRE', 'Spectre', 'Quantum']),
  PlotUniverse('pirates', triggers: [
    'pirates of the caribbean', 'jack sparrow', 'black pearl', 'davy jones',
  ], terms: [
    'Black Pearl', 'Sparrow', 'Davy Jones', 'Flying Dutchman', 'Caribbean',
  ]),
  PlotUniverse('matrix', triggers: ['matrix collection', 'the matrix'],
      terms: ['Matrix', 'Zion', 'Neo', 'Morpheus', 'Agent Smith']),
  PlotUniverse('witcher', triggers: ['witcher', 'geralt', 'nilfgaard'],
      terms: ['Witcher', 'Geralt', 'Rivia', 'Nilfgaard', 'Cintra', 'Continent']),
  PlotUniverse('doctor-who', triggers: ['doctor who', 'tardis', 'dalek', 'daleks'],
      terms: ['TARDIS', 'Tardis', 'Time Lord', 'Gallifrey', 'Daleks', 'Dalek']),
  PlotUniverse('stranger-things', triggers: ['stranger things'],
      terms: ['Hawkins', 'Upside Down']),
  PlotUniverse('arcane', triggers: ['league of legends', 'piltover'],
      terms: ['Piltover', 'Zaun']),
];

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

final _upper = RegExp(r'\p{Lu}', unicode: true);
final _letter = RegExp(r'\p{L}', unicode: true);

/// Whether [phrase] (lower-case) occurs as whole words in [original]; with
/// [capitalized], only where its first letter is upper-case there.
bool _containsPhrase(String original, String phrase, {bool capitalized = false}) {
  final haystack = original.toLowerCase();
  var from = 0;
  while (true) {
    final i = haystack.indexOf(phrase, from);
    if (i < 0) return false;
    final end = i + phrase.length;
    final okBefore = i == 0 || !_wordChar.hasMatch(haystack[i - 1]);
    final okAfter = end >= haystack.length || !_wordChar.hasMatch(haystack[end]);
    final okCase = !capitalized ||
        !_letter.hasMatch(phrase[0]) ||
        _upper.hasMatch(original[i]);
    if (okBefore && okAfter && okCase) return true;
    from = i + 1;
  }
}

String _plain(String s) => s.replaceAll('’', "'");

/// The universes a title belongs to, judged from its [names] (title,
/// original title, collection name and parts, TMDB keywords — any case) and
/// [texts] (overview, tagline — capitalized mentions only).
List<PlotUniverse> plotUniversesFor(Iterable<String> names,
    {Iterable<String> texts = const []}) {
  final nameText = _plain(names.join('\n'));
  final bodyText = _plain(texts.join('\n'));
  return [
    for (final u in plotUniverses)
      if (u.triggers.any((t) =>
          _containsPhrase(nameText, t) ||
          _containsPhrase(bodyText, t, capitalized: true)))
        u,
  ];
}

/// Franchise giveaways for one title, for `PlotRedactor.redact`:
///
/// * `words` (its `franchise`): the curated terms of its [universes], plus
///   the words of [related] titles (the rest of its collection and universe —
///   "Batman Begins" for The Dark Knight Rises) that aren't in
///   [genericWords] (lower-case, singular: words like "earth" or "world"
///   that plenty of unrelated films use too);
/// * `phrases` (its `franchisePhrases`): the multi-word curated terms and
///   the related titles and their colon/dash-separated parts, so "Captain
///   America: Civil War" is hidden in Spider-Man: Homecoming even though
///   each of its words is ordinary.
({List<String> words, List<String> phrases}) plotFranchiseVocabulary({
  Iterable<PlotUniverse> universes = const [],
  Iterable<String> related = const [],
  Set<String> genericWords = const {},
}) {
  final terms = [for (final u in universes) ...u.terms];
  final phrases = <String>{
    for (final t in terms)
      if (t.contains(' ')) t,
    for (final title in related) ...[
      title,
      for (final part in title.split(_titleSeparator))
        if (_isDistinctivePhrase(part.trim())) part.trim(),
    ],
  };
  return (
    words: [
      ...terms,
      // Not bare numbers: "2" from "Iron Man 2" would hide every "2".
      for (final w in plotTitleWords(related).difference(genericWords))
        if (_letter.hasMatch(w)) w,
    ],
    phrases: [
      for (final p in phrases)
        if (p.contains(' ')) p,
    ],
  );
}

final _titleSeparator = RegExp(r'\s*[:–—]\s*|\s+-\s+');

/// A title part worth hiding as a phrase: two or more words, at least two of
/// them capitalized ("Civil War", "Age of Ultron" — not "the Last").
bool _isDistinctivePhrase(String part) =>
    RegExp(r'\b\p{Lu}', unicode: true).allMatches(part).length >= 2;
