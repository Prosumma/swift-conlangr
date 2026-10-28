import Conlangr
import Testing

/// Thelimu, a language invented for Conlangr. It isn't based on any real language, but each of
/// its features is found in real ones:
///
/// - Vowel harmony by tongue root, as in many West African and Nilotic languages. Every vowel in a
///   word is advanced (i e o u) or retracted (ị ẹ ọ ụ a), prefixes and suffixes included. A has no
///   advanced partner, so a word with an a anywhere, even in a suffix, is retracted throughout.
/// - Initial consonant mutation, as in the Celtic languages. The possessive prefix mi- "my"
///   softens the consonant after it (p → b, tʰ → s), and u- "your" turns it into a nasal (k → ŋ,
///   pʰ → a voiceless mh).
/// - Aspirate dissimilation, as in Grassmann's law in Greek and Sanskrit: of two aspirates in
///   neighbouring syllables, the first loses its aspiration. A reduplicated aspirate does too, as
///   in Greek títhēmi, "I put", from *thí-thē-mi.
/// - Reduplication, as in many Austronesian languages: a noun's plural repeats its first syllable,
///   and a verb repeated entirely is done again and again.
/// - A nasal at the end of a syllable takes the place of the consonant after it, like Japanese
///   moraic n, and a prefix's vowel is lost before a vowel.
///
/// The language's name for itself is the advanced word thelimu.
///
/// The grammar writes vowels as I E O U A until harmony decides how they sound, aspiration as ʰ,
/// and morpheme boundaries as ·. ᴸ and ᴺ are the prefixes' mutations, and ⁿ is a nasal that
/// takes the place of the consonant after it. The spelling comes last: aspirates are written ph,
/// th, kh and qh, and the retracted vowels with a dot below.
struct ThelimuTests {
  /// The grammar, in `Examples/Thelimu.conlangr`.
  static var source: String {
    get throws { try example("Thelimu") }
  }

  static let advanced = Set("ieou")
  static let retracted = Set("ịẹọụa")
  static let vowels = advanced.union(retracted)
  static let letters = vowels.union("bdfghklmnpqrsštwxy")

  /// The words to check, from a fixed seed, starting from `production`.
  static func sample(from production: String = "_") throws -> [String] {
    let generator = try #require(try Generator(source).starting(at: production))
    var random = SplitMix64(seed: 3141)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  @Test func inventory() throws {
    for word in try Self.sample() {
      #expect(word.allSatisfy(Self.letters.contains), "\(word)")
    }
  }

  @Test func vowelHarmony() throws {
    for word in try Self.sample() {
      let isAdvanced = word.contains(where: Self.advanced.contains)
      let isRetracted = word.contains(where: Self.retracted.contains)
      #expect(isAdvanced != isRetracted, "\(word)")
    }
  }

  @Test func bothHarmoniesAreCommon() throws {
    let words = try Self.sample()
    let advanced = words.filter { $0.contains(where: Self.advanced.contains) }
    #expect(advanced.count > 400)
    #expect(words.count - advanced.count > 400)
  }

  @Test func noTwoVowelsTogether() throws {
    for word in try Self.sample() {
      let isVowel = word.map(Self.vowels.contains)
      #expect(!zip(isVowel, isVowel.dropFirst()).contains { $0 && $1 }, "\(word)")
    }
  }

  @Test func aspiratesDissimilate() throws {
    // An aspirate is written with an h after p, t, k or q, which can't end a syllable. Between
    // two aspirates there's always more than one vowel.
    for word in try Self.sample() {
      let characters = Array(word)
      var vowelsSinceAspirate: Int?
      for (i, character) in characters.enumerated() {
        if Self.vowels.contains(character) {
          vowelsSinceAspirate? += 1
        } else if character == "h", i > 0, "ptkq".contains(characters[i - 1]) {
          #expect(vowelsSinceAspirate.map { $0 > 1 } ?? true, "\(word)")
          vowelsSinceAspirate = 0
        }
      }
    }
  }

  @Test func nasalsTakeThePlaceOfWhatFollows() throws {
    // n is never written before a labial, and m only before a vowel, a labial, or the h of a
    // voiceless mh.
    for word in try Self.sample() {
      for (current, next) in zip(word, word.dropFirst()) {
        if current == "n" {
          #expect(!"pbfm".contains(next), "\(word)")
        } else if current == "m" {
          #expect(Self.vowels.contains(next) || "pbfmwh".contains(next), "\(word)")
        }
      }
    }
  }

  @Test func pluralsRepeatTheFirstSyllable() throws {
    // Nouns without a prefix whose first two letters, a consonant and a vowel, come twice.
    let doubled = try Self.sample(from: "noun").filter { word in
      let start = Array(word.prefix(4))
      return start.count == 4 && !Self.vowels.contains(start[0]) && Self.vowels.contains(start[1])
        && start[0..<2] == start[2..<4]
    }
    #expect(doubled.count > 100)
  }

  @Test func verbsCanRepeatTheirRoot() throws {
    let doubled = try Self.sample(from: "verb").filter { word in
      let characters = Array(word)
      return stride(from: 4, through: characters.count / 2, by: 1).contains { length in
        (0...(characters.count - 2 * length)).contains { start in
          characters[start..<(start + length)]
            == characters[(start + length)..<(start + 2 * length)]
        }
      }
    }
    #expect(doubled.count > 150)
  }

  @Test(arguments: [
    ("tʰElImU", "thelimu"),  // the language's name for itself
    ("mIᴸ·pAlU", "mịbalụ"),  // my ...: p softens to b
    ("mIᴸ·tʰUkE", "misuke"),  // my ...: tʰ softens to s, and harmony is advanced
    ("Uᴺ·kAlI", "ụngalị"),  // your ...: k becomes ŋ
    ("Uᴺ·pʰAlI", "ụmhalị"),  // your ...: pʰ becomes a voiceless mh
    ("sE·pAlU", "sẹpalụ"),  // his, her ...: no mutation
    ("kO·AlI", "kalị"),  // a prefix's vowel is lost before a vowel
    ("Iⁿ·pAkA", "ịmpaka"),  // the nasal becomes m before p
    ("Iⁿ·kAlA", "ịnkala"),  // ŋ, written n before k
    ("pʰAtʰA", "patha"),  // the first of two aspirates loses its aspiration
    ("pʰAⁿtʰA", "pantha"),  // even with a nasal between
    ("tʰAtʰAkʰA", "tatakha"),  // and so does the second of three
  ])
  func sandhi(form: String, spelled: String) throws {
    let harmony = form.contains("A") ? "@retracted" : "@advanced"
    // The grammar's own rule sets, applied to a known form instead of a generated one.
    let generator = try #require(
      try Generator(Self.source + "\nknown = (+ \(form) @sandhi \(harmony) @spelling)")
        .starting(at: "known"))
    #expect(try generator.generate() == spelled)
  }

  @Test func familiarShapes() throws {
    // The rarer mutations, such as qʰ → x, are covered by the sandhi tests.
    let words = try Self.sample()
    for part in ["th", "kh", "ph", "qh", "gh", "ng", "nk", "š", "ị", "ẹ", "ọ", "ụ"] {
      #expect(words.contains { $0.contains(part) }, "\(part)")
    }
  }
}
