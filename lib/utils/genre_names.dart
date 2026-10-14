/// Turkish display names for TMDB's movie + TV genres. The app fetches TMDB
/// in en-US (and stores genre names that way in Firestore, e.g. for the
/// stats charts), so genres are translated only at display time. Unknown
/// names and other locales pass through unchanged.
const _genreNamesTr = {
  'Action': 'Aksiyon',
  'Adventure': 'Macera',
  'Animation': 'Animasyon',
  'Comedy': 'Komedi',
  'Crime': 'Suç',
  'Documentary': 'Belgesel',
  'Drama': 'Dram',
  'Family': 'Aile',
  'Fantasy': 'Fantastik',
  'History': 'Tarih',
  'Horror': 'Korku',
  'Music': 'Müzik',
  'Mystery': 'Gizem',
  'Romance': 'Romantik',
  'Science Fiction': 'Bilim Kurgu',
  'TV Movie': 'TV Filmi',
  'Thriller': 'Gerilim',
  'War': 'Savaş',
  'Western': 'Vahşi Batı',
  'Action & Adventure': 'Aksiyon & Macera',
  'Kids': 'Çocuk',
  'News': 'Haber',
  'Reality': 'Realite',
  'Sci-Fi & Fantasy': 'Bilim Kurgu & Fantastik',
  'Soap': 'Pembe Dizi',
  'Talk': 'Talk Show',
  'War & Politics': 'Savaş & Politika',
};

String localizedGenre(String name, String languageCode) =>
    languageCode == 'tr' ? (_genreNamesTr[name] ?? name) : name;

// Longest first so "Action & Adventure" wins over "Action".
final _byLength = _genreNamesTr.keys.toList()
  ..sort((a, b) => b.length.compareTo(a.length));
final _anyGenre = RegExp(
    '(?<![A-Za-z])(${_byLength.map(RegExp.escape).join('|')})(?![A-Za-z])');

/// Translates every genre name inside an already-joined string such as
/// "Action, Drama" or "Action +1" (game clue summaries).
String localizedGenreText(String text, String languageCode) =>
    languageCode == 'tr'
        ? text.replaceAllMapped(
            _anyGenre, (m) => _genreNamesTr[m[1]!] ?? m[1]!)
        : text;
