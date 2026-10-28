import Conlangr
import Foundation
import Testing

/// A language inspired by Diné Bizaad, the Navajo language.
///
/// This isn't Navajo, only a sketch of some of its sound patterns, taken mostly from Ellavina
/// Perkins and Ted Fernald's grammar (https://fernald.domains.swarthmore.edu/nla/grammar/):
///
/// - Every syllable starts with a consonant. A word that seems to start with a vowel starts with
///   a glottal stop, written `'`.
/// - A word is a stem, which comes last, after any number of CV prefixes. Prefixes have low tone.
///   The stem is CV, CVV, CVC or CVVC, and carries tone, vowel length and nasality.
/// - Sibilants agree within a word: the front series (s, z, ts, ts', dz) doesn't mix with the back
///   series (sh, zh, ch, ch', j), and prefixes follow the stem. The perfective si- becomes shi-
///   before a back sibilant, and the possessive shi- ("my") becomes si- before a front one.
/// - Vowels next to n or m are nasal, but they aren't written that way.
/// - The voiced velar fricative is written gh before a, y before i and e, and w before o.
/// - A syllabic n can start a verb, before a consonant it can join, as in "ndi" or "nts'ískees".
///
/// The grammar writes each sound as one symbol, and spells the orthography out at the end.
struct DineBizaadTests {
  /// The grammar, in `Examples/DineBizaad.conlangr`.
  static var source: String {
    get throws { try example("DineBizaad") }
  }

  static let vowels = Set("aeioáéíóąęįǫą́ę́į́ǫ́")
  static let letters = vowels.union("'bcdghjklmnstwyzł")

  /// The words to check, from a fixed seed.
  static func sample() throws -> [String] {
    let generator = try Generator(source)
    var random = SplitMix64(seed: 1868)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  @Test func usesOnlyTheInventory() throws {
    for word in try Self.sample() {
      #expect(!word.isEmpty)
      #expect(word.allSatisfy(Self.letters.contains), "\(word)")
    }
  }

  @Test func wordsStartWithAConsonant() throws {
    for word in try Self.sample() {
      #expect(!Self.vowels.contains(word.first ?? "a"), "\(word)")
    }
  }

  @Test func sibilantsAgree() throws {
    var series: Set<String> = []
    for word in try Self.sample() {
      // "sh" and "zh" contain "s" and "z", so take them out before looking for front sibilants.
      let back = ["sh", "zh", "ch", "j"].contains { word.contains($0) }
      let rest = word.replacing("sh", with: "").replacing("zh", with: "")
      let front = rest.contains("s") || rest.contains("z")
      #expect(!(front && back), "\(word)")
      series.insert(front ? "front" : back ? "back" : "plain")
    }
    #expect(series == ["plain", "front", "back"])
  }

  @Test func ghOnlyBeforeA() throws {
    var sawGh = false
    for word in try Self.sample() {
      let characters = Array(word)
      for i in characters.indices.dropLast(2) where characters[i] == "g" && characters[i + 1] == "h"
      {
        sawGh = true
        // The base letter of the vowel, without its tone mark or nasal hook.
        let vowel = String(characters[i + 2]).decomposedStringWithCanonicalMapping
        #expect(vowel.unicodeScalars.first == "a", "\(word)")
      }
    }
    #expect(sawGh)
  }

  @Test func syllabicNJoinsAConsonant() throws {
    for word in try Self.sample() where word.hasPrefix("n") {
      let second = word.dropFirst().first
      #expect(
        second.map { Self.vowels.contains($0) || "dtłlsczj".contains($0) } ?? false, "\(word)")
    }
  }

  @Test func nasalVowelsAreUnmarkedAfterNasals() throws {
    let nasalVowels = Set("ąęįǫą́ę́į́ǫ́")
    var sawNasalVowel = false
    for word in try Self.sample() {
      let characters = Array(word)
      sawNasalVowel = sawNasalVowel || characters.contains(where: nasalVowels.contains)
      for i in characters.indices.dropFirst() where nasalVowels.contains(characters[i]) {
        #expect(!"nm".contains(characters[i - 1]), "\(word)")
      }
    }
    #expect(sawNasalVowel)
  }
}
