import Conlangr
import Testing

/// A language inspired by Sindarin, the Grey-elven tongue of Tolkien's legendarium, as written
/// in The Lord of the Rings and its appendices.
///
/// This isn't Sindarin, only a sketch of how it looks:
///
/// - c is always /k/; th, dh and ch are fricatives; lh, rh and hw are voiceless, and start a word.
///   There's no k, j, q, x or z.
/// - Long vowels take an acute (Dúnadan), except in a monosyllable, where they take a circumflex
///   (hîr, lhûn).
/// - Final au is written aw, and final [v] is written f.
/// - The grammar writes each digraph as a single letter, and spells it out at the end, so its
///   rules see one letter per sound.
/// - Consonants assimilate where the parts of a word meet: n before r becomes dh (Caradhras), and
///   n before l or m doubles it.
/// - Plurals change their vowels. In the last syllable, a becomes ai, o and u become y, and e
///   becomes i. Elsewhere, a and o become e, and u becomes y: adan → edain, orch → yrch,
///   amon → emyn.
struct SindarinTests {
  /// The grammar, in `Examples/Sindarin.conlangr`.
  static var source: String {
    get throws { try example("Sindarin") }
  }

  static let vowels = Set("aeiouyáéíóúýâêîôûŷ")
  static let letters = vowels.union("bcdfghlmnprstvw")

  /// The number of syllables in `word`, counting each run of vowels as one.
  static func syllables(_ word: String) -> Int {
    var count = 0
    var previous: Character?
    for c in word {
      if vowels.contains(c) && !(previous.map(vowels.contains) ?? false) {
        count += 1
      }
      previous = c
    }
    return count
  }

  /// The words to check, from a fixed seed.
  static func sample(overrides: [String: UInt8] = [:]) throws -> [String] {
    let generator = try Generator(source, overrides: overrides)
    var random = SplitMix64(seed: 1954)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  @Test func usesOnlyTheInventory() throws {
    for word in try Self.sample() {
      #expect(!word.isEmpty)
      #expect(word.allSatisfy(Self.letters.contains), "\(word)")
    }
  }

  @Test func circumflexOnlyInMonosyllables() throws {
    let circumflex = Set("âêîôûŷ")
    let acute = Set("áéíóúý")
    for word in try Self.sample() {
      if word.contains(where: circumflex.contains) {
        #expect(Self.syllables(word) == 1, "\(word)")
      }
      if word.contains(where: acute.contains) {
        #expect(Self.syllables(word) > 1, "\(word)")
      }
    }
  }

  @Test func spellingRules() throws {
    for word in try Self.sample() {
      #expect(!word.hasSuffix("au"), "\(word)")
      #expect(!word.hasSuffix("v"), "\(word)")
      for cluster in ["nr", "nl", "nm", "nb", "np", "mp", "dl"] {
        #expect(!word.contains(cluster), "\(word)")
      }
    }
  }

  @Test func voicelessConsonantsStartAWord() throws {
    for word in try Self.sample() {
      // In "thwen", the h belongs to th, so mask th, ch and dh before looking for hw.
      let masked = word.replacing("th", with: "__").replacing("ch", with: "__")
        .replacing("dh", with: "__")
      for cluster in ["lh", "rh", "hw"] {
        if let range = masked.range(of: cluster) {
          #expect(range.lowerBound == masked.startIndex, "\(word)")
        }
      }
    }
  }

  @Test func pluralsChangeTheirVowels() throws {
    // With only plurals, there's no short o or u left, and every a is part of ai.
    let plurals = try Self.sample(overrides: ["monosyllables": 0, "words": 0])
    for word in plurals {
      #expect(!word.contains("o") && !word.contains("u"), "\(word)")
      let characters = Array(word)
      for i in characters.indices where characters[i] == "a" {
        #expect(i + 1 < characters.count && characters[i + 1] == "i", "\(word)")
      }
    }
    #expect(plurals.contains { $0.contains("ai") })
    #expect(plurals.contains { $0.contains("y") })
  }

  @Test func familiarShapes() throws {
    let words = Set(try Self.sample())
    for ending in ["dor", "ion", "iel", "wen", "aw"] {
      #expect(words.contains { $0.hasSuffix(ending) }, "-\(ending)")
    }
    #expect(words.contains { $0.contains("dhr") })
  }
}
