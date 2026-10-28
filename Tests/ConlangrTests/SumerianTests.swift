import Conlangr
import Testing

/// A language inspired by Sumerian, written in the standard Assyriological transliteration.
///
/// This isn't Sumerian, only a sketch of its patterns and how they're written:
///
/// - Words are written as cuneiform signs joined by hyphens: lugal-e, mu-un-na-du₃. A subscript
///   number tells apart signs that sound alike, and ᵈ, the determinative for a god, starts a divine
///   name: ᵈen-lil₂.
/// - A noun is a root, then an optional plural, possessive (-ĝu₁₀, -zu, -a-ni, -bi) and case (-e,
///   -ra, -ta, -še₃, -da, and -a). The plural is -e-ne, or the root said twice: kur-kur, "lands". After a consonant, the case -a is written by repeating
///   the consonant: lugal-la.
/// - A verb is an optional modal (ḫa-, nu-), a conjugation prefix (mu-, i₃-, ba-, bi₂-), an
///   optional dimensional prefix (na-, ši-, ta-, da-, ni-), the root, and a person suffix.
/// - Vowel harmony, as in Old Sumerian texts from Lagaš: i₃-, bi₂- and ni- become e-, be₂- and ne-
///   before a root whose vowel is a or e.
///
/// The grammar writes · between signs, I, J, B and N for the harmonizing prefixes (J is the -n-
/// after I), and ª for the case -a, and fills in the spelling at the end.
struct SumerianTests {
  /// The grammar, in `Examples/Sumerian.conlangr`.
  static var source: String {
    get throws { try example("Sumerian") }
  }

  static let consonants = Set("bdgkptĝmnlrsšzḫ")
  static let vowels = Set("aeiu")
  static let subscripts = Set("₀₁₂₃₄₅₆₇₈₉")

  /// The words to check, from a fixed seed.
  static func sample(overrides: [String: UInt8] = [:]) throws -> [String] {
    let generator = try Generator(source, overrides: overrides)
    var random = SplitMix64(seed: 2600)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  /// Whether `segment` could be one sign: letters, at least one of them a vowel, perhaps followed by
  /// a subscript index. A logogram like lugal or sukkal is one sign, so a sign can be any length.
  static func isSign(_ segment: Substring) -> Bool {
    let letters = segment.prefix { !subscripts.contains($0) }
    let index = segment.dropFirst(letters.count)
    return letters.contains(where: vowels.contains)
      && letters.allSatisfy { vowels.contains($0) || consonants.contains($0) }
      && index.allSatisfy(subscripts.contains)
  }

  @Test func signs() throws {
    for word in try Self.sample() {
      let body = word.hasPrefix("ᵈ") ? word.dropFirst() : Substring(word)
      #expect(!body.contains("ᵈ"), "\(word)")
      let segments = body.split(separator: "-", omittingEmptySubsequences: false)
      #expect(segments.allSatisfy(Self.isSign), "\(word)")
    }
  }

  @Test func caseARepeatsAConsonant() throws {
    // The case -a after a consonant is written with that consonant, so a word never ends with the
    // bare sign a after a sign that ends in a consonant.
    for word in try Self.sample(overrides: ["verbs": 0]) where word.hasSuffix("a") {
      let segments = word.split(separator: "-")
      if segments.count > 1, let previous = segments.dropLast().last, segments.last == "a" {
        #expect(!Self.consonants.contains(previous.last!), "\(word)")
      }
    }
  }

  @Test func vowelHarmony() throws {
    let high: Set<Substring> = ["i₃", "bi₂", "ni"]
    let low: Set<Substring> = ["be₂", "ne"]
    for word in try Self.sample(overrides: ["nouns": 0, "gods": 0]) {
      let segments = word.split(separator: "-")
      let conjugation = segments.first { !["ḫa", "nu"].contains($0) }
      let isHigh = !high.isDisjoint(with: segments) || conjugation == "i₃"
      let isLow = !low.isDisjoint(with: segments) || conjugation == "e"
      #expect(!(isHigh && isLow), "\(word)")
    }
  }

  @Test func pluralByReduplication() throws {
    // Some nouns start with their root twice, a sign or more each time.
    let doubled = try Self.sample(overrides: ["verbs": 0, "gods": 0]).filter { word in
      let signs = word.split(separator: "-")
      return stride(from: 1, through: signs.count / 2, by: 1).contains { n in
        signs[0..<n].elementsEqual(signs[n..<(2 * n)])
      }
    }
    #expect(doubled.contains { $0.hasPrefix("kur-kur") || $0.hasPrefix("lugal-lugal") })
    #expect(doubled.count > 30)
  }

  @Test func familiarShapes() throws {
    let words = try Self.sample()
    for part in ["lugal", "mu-un", "ᵈ", "₃", "ĝ", "š", "ḫ", "-la", "e₂"] {
      #expect(words.contains { $0.contains(part) }, "\(part)")
    }
  }
}
