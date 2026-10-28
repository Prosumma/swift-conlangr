import Conlangr
import Testing

/// A Polynesian language: an ancestor modeled on Proto-Polynesian, and a descendant that has
/// undergone the sound changes that led to Hawaiian.
///
/// This isn't Proto-Polynesian or Hawaiian, only a sketch of their patterns:
///
/// - Every syllable is a vowel, perhaps after one consonant, so there are no clusters, and every
///   word ends in a vowel. Two like vowels together are one long vowel, written with a macron.
/// - Words are roots of two or three syllables, sometimes with the causative prefix faka-, the
///   nominalizing suffix -ŋa, or the passive -ʔia.
/// - Roots are often reduplicated, either entirely (Hawaiian wikiwiki, "quick") or just their
///   first syllable (pule, "pray", and pupule, "crazy").
/// - The descendant loses ʔ and h, turns k into ʔ (written ʻ) and then t into k, and merges f and s
///   into h, ŋ into n, r into l, and v into w. So the ancestor's taŋata becomes kanaka, and its 13
///   consonants become Hawaiian's eight.
///
/// The ancestral forms are the grammar's idealized form, and the sound changes are a rule set
/// with a single substitution, whose class maps every sound at once. Applied one at a time, k → ʔ and t → k
/// would have to be carefully ordered, or every t would end up as ʔ. Reduplication happens in the
/// ancestor, so the sound changes apply to both copies alike.
struct PolynesianTests {
  /// The grammar, in `Examples/Polynesian.conlangr`.
  static var source: String {
    get throws { try example("Polynesian") }
  }

  static let vowels = Set("aeiouāēīōū")
  static let descendantLetters = vowels.union("hklmnpwʻ")
  static let ancestorLetters = vowels.union("ptkʻmngfshlrv")

  /// The words to check, from a fixed seed, starting from `production`.
  static func sample(from production: String = "_") throws -> [String] {
    let generator = try #require(try Generator(source).starting(at: production))
    var random = SplitMix64(seed: 1778)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  /// Whether `word` is made only of syllables of a vowel after at most one consonant. In the
  /// ancestor, ng is one consonant.
  static func isOpenSyllables(_ word: String) -> Bool {
    let consonants = Array(word.replacing("ng", with: "ŋ")).map { !vowels.contains($0) }
    let noClusters = !zip(consonants, consonants.dropFirst()).contains { $0 && $1 }
    return noClusters && consonants.last == false
  }

  @Test func descendantInventory() throws {
    for word in try Self.sample(from: "descendant") {
      #expect(word.allSatisfy(Self.descendantLetters.contains), "\(word)")
      #expect(Self.isOpenSyllables(word), "\(word)")
    }
  }

  @Test func ancestorInventory() throws {
    let words = try Self.sample(from: "ancestor")
    for word in words {
      #expect(word.allSatisfy(Self.ancestorLetters.contains), "\(word)")
      #expect(Self.isOpenSyllables(word), "\(word)")
    }
    for consonant in ["t", "ng", "f", "s", "r", "v", "ʻ"] {
      #expect(words.contains { $0.contains(consonant) }, "\(consonant)")
    }
  }

  @Test func reduplication() throws {
    // A fully reduplicated root with no affix is the same thing twice.
    let doubled = try Self.sample().filter { word in
      word.count.isMultiple(of: 2) && word.prefix(word.count / 2) == word.suffix(word.count / 2)
    }
    #expect(doubled.count > 50)
  }

  @Test func longVowelsAreWrittenWithAMacron() throws {
    for word in try Self.sample() {
      for vowel in ["aa", "ee", "ii", "oo", "uu"] {
        #expect(!word.contains(vowel), "\(word)")
      }
    }
  }

  /// Proto-Polynesian words and their Hawaiian descendants.
  @Test(arguments: [
    ("taku", "kaʻu"),  // my
    ("taŋata", "kanaka"),  // person
    ("ʔariki", "aliʻi"),  // chief
    ("fale", "hale"),  // house
    ("tapu", "kapu"),  // forbidden
    ("ika", "iʻa"),  // fish
    ("waka", "waʻa"),  // canoe
    ("mata", "maka"),  // eye
    ("rua", "lua"),  // two
    ("tolu", "kolu"),  // three
    ("fitu", "hiku"),  // seven
    ("hiva", "iwa"),  // nine
  ])
  func soundChanges(ancestor: String, descendant: String) throws {
    // The grammar's own rule sets, applied to a known word instead of a generated one.
    let generator = try #require(
      try Generator(Self.source + "\nknown = (+ \(ancestor) @soundChanges @spelling)")
        .starting(at: "known"))
    #expect(try generator.generate() == descendant)
  }
}
