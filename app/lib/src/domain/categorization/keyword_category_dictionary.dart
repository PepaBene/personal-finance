/// Built-in keyword → category-name dictionary (docs/05 §6, tier 3), Czech +
/// English. Pure data so it can be unit-tested and reused on every platform.
///
/// Entries map to the **default seeded category names** (see DatabaseSeeder); the
/// [Categorizer] resolves a name to the user's actual category id. Order matters:
/// the first category whose keywords appear in the text wins, so more specific
/// categories are listed before broad ones.
class KeywordCategoryDictionary {
  const KeywordCategoryDictionary([this.entries = _default]);

  /// (categoryName, keywords) in match-priority order.
  final List<(String, List<String>)> entries;

  /// The category name whose keyword set first appears in [text], or null.
  /// Matching is case-insensitive and accent-naive (callers pass raw text).
  String? categoryNameFor(String text) {
    final t = text.toLowerCase();
    for (final (name, keywords) in entries) {
      for (final k in keywords) {
        if (t.contains(k)) return name;
      }
    }
    return null;
  }

  static const List<(String, List<String>)> _default = [
    (
      'Groceries',
      [
        'mléko',
        'mleko',
        'milk',
        'chléb',
        'chleba',
        'bread',
        'máslo',
        'maslo',
        'butter',
        'sýr',
        'syr',
        'cheese',
        'vejce',
        'eggs',
        'rohlík',
        'rohlik',
        'jogurt',
        'yogurt',
        'banán',
        'banana',
        'jablk',
        'apple',
        'zelenina',
        'vegetable',
        'ovoce',
        'fruit',
        'potraviny',
        'groceries',
        'maso',
        'albert',
        'lidl',
        'tesco',
        'kaufland',
        'billa',
        'penny',
        'globus',
      ],
    ),
    (
      'Dining',
      [
        'restaurace',
        'restaurant',
        'kavárna',
        'kavarna',
        'café',
        'cafe',
        'coffee',
        'káva',
        'kava',
        'pizza',
        'bistro',
        'oběd',
        'obed',
        'lunch',
        'dinner',
        'fast food',
        'mcdonald',
        'kfc',
        'burger',
      ],
    ),
    (
      'Fuel',
      [
        'benzín',
        'benzin',
        'nafta',
        'diesel',
        'fuel',
        'gasoline',
        'palivo',
        'natural',
        'shell',
        'omv',
        'eurooil',
        'čerpací',
        'cerpaci',
      ],
    ),
    (
      'Transport',
      [
        'jízdenka',
        'jizdenka',
        'ticket',
        'mhd',
        'metro',
        'tramvaj',
        'tram',
        'autobus',
        'vlak',
        'train',
        'taxi',
        'uber',
        'bolt',
        'parkování',
        'parkovani',
        'parking',
        'dálniční',
        'dalnicni',
        'mýtné',
        'mytne',
      ],
    ),
    (
      'Subscriptions',
      [
        'netflix',
        'spotify',
        'předplatné',
        'predplatne',
        'subscription',
        'hbo',
        'youtube',
        'disney',
        'icloud',
        'google one',
        'patreon',
        'prime',
      ],
    ),
    (
      'Utilities',
      [
        'elektřina',
        'elektrina',
        'electricity',
        'plyn',
        'voda',
        'water',
        'energie',
        'energy',
        'čez',
        'cez',
        'innogy',
        'vodafone',
        't-mobile',
        'o2',
        'internet',
        'telefon',
      ],
    ),
    (
      'Health',
      [
        'lékárna',
        'lekarna',
        'pharmacy',
        'drogerie',
        'dr.max',
        'dr. max',
        'benu',
        'apotheke',
        'doktor',
        'doctor',
        'lékař',
        'lekar',
        'zdraví',
        'zdravi',
        'zubař',
        'zubar',
        'dentist',
      ],
    ),
    (
      'Shopping',
      [
        'oblečení',
        'obleceni',
        'clothing',
        'electro',
        'alza',
        'datart',
        'ikea',
        'action',
        'dm ',
        'mall',
        'sportisimo',
        'decathlon',
        'notino',
      ],
    ),
    (
      'Leisure',
      [
        'kino',
        'cinema',
        'divadlo',
        'theatre',
        'theater',
        'steam',
        'fitness',
        'gym',
        'posilovna',
        'bazén',
        'bazen',
        'hra',
        'game',
        'koncert',
      ],
    ),
    (
      'Rent',
      ['nájem', 'najem', 'rent', 'nájemné', 'najemne'],
    ),
    (
      'Housing',
      ['hypotéka', 'hypoteka', 'mortgage', 'sjbd', 'společenství vlastníků'],
    ),
    (
      'Fees',
      ['poplatek', 'fee', 'úrok', 'urok', 'interest', 'provize', 'commission'],
    ),
    (
      'Salary',
      ['mzda', 'plat', 'salary', 'výplata', 'vyplata', 'wage', 'net pay'],
    ),
  ];
}
