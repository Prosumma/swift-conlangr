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
/// - The descendant loses ʔ and h, turns k into ʔ (written ʻ) and then t into k, and merges f and s
///   into h, ŋ into n, r into l, and v into w. So the ancestor's taŋata becomes kanaka, and its 13
///   consonants become Hawaiian's eight.
///
/// The ancestral forms are the grammar's idealized form, and the sound changes are a rule set
/// with a single substitution, whose class maps every sound at once. Applied one at a time, k → ʔ and t → k
/// would have to be carefully ordered, or every t would end up as ʔ. Conlangr can't copy what it
/// generates, so there's no reduplication, which Polynesian languages use a great deal.
struct PolynesianTests {
  /// The sound changes and the spelling, which the cognate tests also apply to known words.
  static let rules = """
    ; The sound changes, all at once, so that the old t becomes k without the
    ; old k, which becomes ʔ, also turning into something else.
    @soundChanges = (> *{ʔ h k t f s ŋ r v}*={_ _ ʔ k h h n l w})

    ; How both languages write long vowels, ŋ and ʔ.
    @spelling = (> *{a e i o u}{}*={ā ē ī ō ū} *ŋ*=ng *ʔ*=ʻ)
    """

  static let source = """
    ; Polynesian. Words are generated in the ancestral language and, usually,
    ; passed through the sound changes of the descendant. Long vowels are
    ; written double until the end.

    $descendant = 3
    $ancestor = 1

    _ = (? $descendant &descendant $ancestor &ancestor)

    ; A lost consonant mustn't leave three like vowels together.
    descendant = (+ &word @soundChanges - *{a e i o u}{}{}* @spelling)
    ancestor = (+ &word @spelling)

    ; A word is a root, perhaps with an affix.
    word = (+ (? 8 &root 2 (+ &prefix &root) 3 (+ &root &suffix) 1 (+ &prefix &root &suffix))
      - *{a e i o u}{}{}*)
    root = (+ &syllable &syllable (? 3 _ 1 &syllable))
    syllable = (+ (? 8 &C 1 _) &V)
    prefix = (? 3 faka 1 fe 1 ma)
    suffix = (? 3 ŋa 2 ʔia 1 ina)

    C = (? 2 p 4 t 4 k 2 ʔ 3 m 3 n 2 ŋ 3 f 2 s 2 h 3 l 2 r 2 v)
    V = (? 8 a 4 e 6 i 6 o 5 u 1 aa 1 ee 1 ii 1 oo 1 uu)

    \(rules)
    """

  static let vowels = Set("aeiouāēīōū")
  static let descendantLetters = vowels.union("hklmnpwʻ")
  static let ancestorLetters = vowels.union("ptkʻmngfshlrv")

  /// The words to check, from a fixed seed.
  static func sample(overrides: [String: UInt8] = [:]) throws -> [String] {
    let generator = try Generator(source, overrides: overrides)
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
    for word in try Self.sample(overrides: ["ancestor": 0]) {
      #expect(word.allSatisfy(Self.descendantLetters.contains), "\(word)")
      #expect(Self.isOpenSyllables(word), "\(word)")
    }
  }

  @Test func ancestorInventory() throws {
    let words = try Self.sample(overrides: ["descendant": 0])
    for word in words {
      #expect(word.allSatisfy(Self.ancestorLetters.contains), "\(word)")
      #expect(Self.isOpenSyllables(word), "\(word)")
    }
    for consonant in ["t", "ng", "f", "s", "r", "v", "ʻ"] {
      #expect(words.contains { $0.contains(consonant) }, "\(consonant)")
    }
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
    let generator = try Generator("\(Self.rules)\n_ = (+ \(ancestor) @soundChanges @spelling)")
    #expect(try generator.generate() == descendant)
  }
}
