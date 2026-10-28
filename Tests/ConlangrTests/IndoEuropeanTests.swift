import Conlangr
import Testing

/// A language inspired by Proto-Indo-European, in the standard laryngealist reconstruction
/// (Ringe, Fortson, Beekes), with Kümmel's uvular values for the laryngeals in mind.
///
/// This isn't PIE, only a sketch of its patterns:
///
/// - Three series of stops (voiceless, plain voiced, voiced aspirated) at five places, with
///   palatovelars (ḱ) and labiovelars (kʷ). Plain *b is very rare.
/// - Three laryngeals, h₁ h₂ h₃. h₂ colors a neighboring e to a, and h₃ colors it to o.
/// - Roots are CeC, with an optional s- before a voiceless stop and resonants beside the
///   vowel. A root can't have two plain voiced stops (no *ded-), and can't mix voiceless and
///   voiced aspirated stops (no *tedʰ-). No root starts with a vowel: what looks like one
///   starts with a laryngeal, as in h₁es- "be".
/// - Ablaut: a root's vowel is e or o in the full grade, ē or ō in the lengthened grade, or
///   nothing in the zero grade, where a neighboring resonant becomes syllabic (r̥ l̥ m̥ n̥ i u).
///   The zero grade goes with an unaccented root, as in *ḱlutós "heard" beside *ḱléwos "fame".
/// - Each word has one accent, on the root, a suffix, or the ending.
/// - Sound laws at the end of the word: Szemerényi's law (-ter-s → -tḗr), syllabic -m̥ after a
///   consonant (*ph₂térm̥), s → z before a voiced stop, and t inserted between dentals
///   (*wid-tó- → *witstó-).
struct IndoEuropeanTests {
  /// The grammar, in `Examples/IndoEuropean.conlangr`.
  static var source: String {
    get throws { try example("IndoEuropean") }
  }

  static let accented = Set("éóáíúḗṓ")
  static let vowels = accented.union("eoaiuēō")
  static let letters = vowels.union("ptkbdgḱǵʰʷszh₁₂₃rlmnywr̥l̥m̥n̥")

  /// The words to check, from a fixed seed.
  static func sample() throws -> [String] {
    let generator = try Generator(source)
    var random = SplitMix64(seed: 1786)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  @Test func usesOnlyTheInventory() throws {
    // This also checks that ablaut filled in every root's vowel, since · isn't a letter.
    for word in try Self.sample() {
      #expect(word.allSatisfy(Self.letters.contains), "\(word)")
    }
  }

  @Test func oneAccentPerWord() throws {
    for word in try Self.sample() {
      #expect(word.filter(Self.accented.contains).count == 1, "\(word)")
    }
  }

  @Test func noRootStartsWithAFullVowel() throws {
    // A zero-grade root can start with a syllabic resonant, as in *us- beside *wes-.
    for word in try Self.sample() {
      #expect(!"eoaéóáēōḗṓ".contains(word.first ?? "e"), "\(word)")
    }
  }

  @Test func laryngealsColorTheirNeighbors() throws {
    for word in try Self.sample() {
      for uncolored in ["h₂e", "eh₂", "h₂é", "éh₂", "h₃e", "eh₃", "h₃é", "éh₃"] {
        #expect(!word.contains(uncolored), "\(word)")
      }
    }
  }

  @Test func soundLaws() throws {
    for word in try Self.sample() {
      for cluster in ["sd", "sg", "sǵ", "sb", "tt", "dt"] {
        #expect(!word.contains(cluster), "\(word)")
      }
      for ending in [
        "ers", "érs", "ors", "órs", "ens", "éns", "ons", "óns", "oss", "óss", "rm", "nm", "sm",
        "h₂m",
      ] {
        #expect(!word.hasSuffix(ending), "\(word)")
      }
    }
  }

  @Test func ablautProducesEveryGrade() throws {
    let words = try Self.sample()
    let syllabic = Set("r̥l̥m̥n̥")
    #expect(words.contains { $0.contains(where: syllabic.contains) })
    #expect(words.contains { $0.contains("ḗ") || $0.contains("ṓ") })
    #expect(words.contains { $0.contains("ó") })
  }

  @Test func classicShapes() throws {
    // The generator can produce some textbook forms, which shows the parts fit together.
    let words = Set(try Self.sample())
    #expect(words.contains { $0.hasSuffix("tḗr") })
    #expect(words.contains { $0.hasSuffix("éti") })
    #expect(words.contains { $0.hasSuffix("mn̥") })
    #expect(words.contains { $0.contains("h₂a") || $0.contains("ah₂") })
  }
}
