import Conlangr
import Testing

/// A Sinitic language, modeled on Mandarin and written in pinyin.
///
/// This isn't Mandarin, only a sketch of its syllables and their spelling:
///
/// - A syllable is an initial, a final, and one of four tones (or the neutral tone). Initials and
///   finals combine as in Mandarin: j, q and x take only finals with i or ü, and zh, ch, sh, r, z,
///   c and s never do, except for the "buzzing" i of zhi, ci and so on.
/// - Words are mostly two syllables, sometimes one or three.
/// - Pinyin's spelling rules: a syllable with no initial is written with y or w (yi, ya, wu, wo,
///   yu); iou, uei and uen shorten to iu, ui and un after a consonant; ü is written u after j, q
///   and x; and an apostrophe separates a syllable starting with a, o or e from the one before.
/// - The tone mark goes on a or e if there is one, on the o of ou, and otherwise on the last vowel.
///   The neutral tone isn't marked, and never falls on a word's first syllable.
///
/// The grammar writes ẑ ĉ ŝ ŋ for zh ch sh ng (as pinyin's own shorthand does), starts each
/// syllable with a dot, and marks the tone with a superscript after the vowel that will carry it,
/// with ⁰ for the neutral tone.
/// The spelling rules turn all of that into ordinary pinyin at the end.
struct SiniticTests {
  /// The grammar, in `Examples/Sinitic.conlangr`.
  static var source: String {
    get throws { try example("Sinitic") }
  }

  static let toneMarked = Set("āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ")
  static let letters = toneMarked.union("abcdefghijklmnopqrstuwxyzü'")

  /// The words to check, from a fixed seed.
  static func sample() throws -> [String] {
    let generator = try Generator(source)
    var random = SplitMix64(seed: 1958)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  /// `word` with its tone marks removed, so that ǚ is ü, ā is a, and so on.
  static func toneless(_ word: String) -> String {
    let bases = Dictionary(
      uniqueKeysWithValues: zip("āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ", "aaaaeeeeiiiioooouuuuüüüü"))
    return String(word.map { bases[$0] ?? $0 })
  }

  @Test func usesOnlyTheInventory() throws {
    for word in try Self.sample() {
      #expect(word.allSatisfy(Self.letters.contains), "\(word)")
      #expect(word.first != "'", "\(word)")
    }
  }

  @Test func zeroInitialsAreWrittenWithYOrW() throws {
    for word in try Self.sample() {
      let plain = Self.toneless(word)
      #expect(!"iuü".contains(plain.first ?? "?"), "\(word)")
      // An apostrophe comes only before a, o or e.
      let characters = Array(plain)
      for i in characters.indices where characters[i] == "'" {
        #expect(i + 1 < characters.count && "aoe".contains(characters[i + 1]), "\(word)")
      }
    }
  }

  @Test func jqxTakeOnlyIAndU() throws {
    for word in try Self.sample() {
      let characters = Array(Self.toneless(word))
      for i in characters.indices where "jqx".contains(characters[i]) {
        #expect(i + 1 < characters.count && "iu".contains(characters[i + 1]), "\(word)")
      }
    }
  }

  @Test func contractions() throws {
    // iou, uei and uen never survive: after a consonant they shorten, and without one they're
    // written you, wei and wen.
    for word in try Self.sample() {
      let plain = Self.toneless(word)
      #expect(!plain.contains("iou") && !plain.contains("uei"), "\(word)")
    }
  }

  @Test func oneToneMarkPerVowelGroup() throws {
    // A run of vowels belongs to one syllable, so it has at most one tone mark.
    let vowels = Self.toneMarked.union("aeiouü")
    for word in try Self.sample() {
      var marks = 0
      for c in word {
        if !vowels.contains(c) {
          marks = 0
        } else if Self.toneMarked.contains(c) {
          marks += 1
          #expect(marks == 1, "\(word)")
        }
      }
    }
  }

  @Test func firstSyllableIsNeverNeutral() throws {
    let vowels = Self.toneMarked.union("aeiouü")
    for word in try Self.sample() {
      let first = word.drop { !vowels.contains($0) }.prefix { vowels.contains($0) }
      #expect(first.contains(where: Self.toneMarked.contains), "\(word)")
    }
  }

  @Test func familiarShapes() throws {
    let words = try Self.sample().map(Self.toneless)
    for part in ["zh", "x", "'", "iu", "ui", "un", "yu", "ü", "ng", "you", "wei"] {
      #expect(words.contains { $0.contains(part) }, "\(part)")
    }
  }
}
