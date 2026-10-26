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
  /// What happens where morphemes meet, vowel harmony, and the spelling, which the sandhi tests
  /// also apply to known forms.
  static let rules = """
    ; Sandhi. A mutation changes the consonant after the prefix, and then the
    ; prefix's vowel is lost before a vowel. A nasal takes the place of the
    ; consonant after it, and of two aspirates in a row, the first loses its
    ; aspiration. That runs twice, so a third aspirate loses it too.
    @sandhi = (
      > *ᴸ·{p t k q}ʰ*={f s h x} *ᴸ·{p t k q}*={b d g ɣ}
        *ᴺ·{p t k q}ʰ*={m̥ n̥ ŋ̊ ŋ̊} *ᴺ·{p t k q b d g}*={m n ŋ ŋ m n ŋ}
        *ᴸ*=_ *ᴺ*=_
        *{I E O U A}·{I E O U A}*={_ _ _ _ _}·{} *·*=_
        *ⁿ{p b f m w}*=m{} *ⁿ{k g q h ŋ}*=ŋ{} *ⁿ*=n
      @grassmann @grassmann)
    @grassmann = (> *{p t k q}ʰ{I E O U A}{p t k q}ʰ*={}{}{}ʰ
      *{p t k q}ʰ{I E O U A}{m n ŋ l r s}{p t k q}ʰ*={}{}{}{}ʰ)

    ; Vowel harmony. A has no advanced partner, so an advanced word can't
    ; have one.
    @advanced = (- *A* > *{I E O U}*={i e o u})
    @retracted = (> *{I E O U A}*={ɪ ɛ ɔ ʊ a})

    ; The spelling. ŋ is written n before a velar or uvular, as in English
    ; "think".
    @spelling = (> *ʰ*=h *ɣ*=gh *{m̥ n̥ ŋ̊}*={mh nh ngh} *ŋ{k g q}*=n{} *ŋ*=ng
      *{ɪ ɛ ɔ ʊ}*={ị ẹ ọ ụ})
    """

  static let source = """
    ; Thelimu, an invented language. Words are built from morphemes, which
    ; meet with the sandhi, and then vowel harmony makes every vowel in the
    ; word advanced or retracted.

    $nouns = 3
    $verbs = 2

    _ = (? $nouns &noun $verbs &verb)

    ; Each word chooses its harmony, and then it's spelled.
    noun = (? (+ &nounForm @advanced) (+ &nounForm @retracted) @spelling)
    verb = (? (+ &verbForm @advanced) (+ &verbForm @retracted) @spelling)

    ; A noun: perhaps a possessive prefix, the root, and perhaps a case
    ; ending. mi- "my" softens the consonant after it, u- "your" makes it a
    ; nasal, and se- "his, her" leaves it alone.
    nounForm = (+ (? 4 _ 1 mIᴸ· 1 Uᴺ· 1 sE·) &nounStart &rest
      (? 4 _ 1 ·nI 1 ·tE 1 ·lU 1 ·rO)
      @sandhi)
    ; The root's first syllable, repeated for the plural, but not if that
    ; would put two vowels together.
    nounStart = (? 4 &first 1 (+ &first ^first) - *{I E O U A}{I E O U A}*)
    rest = (+ (? 4 _ 1 &coda) &syllable (? 2 _ 1 (+ (? 4 _ 1 &coda) &syllable))
      (? 2 _ 1 &coda))

    ; A verb: perhaps a subject prefix, the root, repeated for an action
    ; done again and again, and perhaps an aspect: -re for an action in
    ; progress, -ma for one to come, and -tu for one that's done.
    verbForm = (+ (? 2 _ 2 Iⁿ· 2 kO· 1 tE· 1 sU·) &verbStem
      (? 4 _ 2 ·rE 1 ·mA 1 ·tU)
      @sandhi)
    verbStem = (? 5 &verbRoot 1 (+ &verbRoot ^verbRoot) - *{I E O U A}{I E O U A}*)
    verbRoot = (+ &first (? 4 _ 1 &coda) &syllable)

    ; Syllables. Only a word's first syllable can start with a vowel, and
    ; only a nasal, l, r or s can end one.
    first = (+ (? 8 &C 1 _) &V)
    syllable = (+ &C &V)
    C = (? 3 p 4 t 4 k 2 q 1 pʰ 2 tʰ 2 kʰ 1 qʰ 2 b 3 d 2 g 2 f 4 s 2 š 3 h
      4 m 4 n 2 ŋ 4 l 3 r 2 w 2 y)
    V = (? 4 A 3 I 2 E 2 O 3 U)
    coda = (? 4 ⁿ 2 l 2 r 1 s)

    \(rules)
    """

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
    let generator = try Generator("\(Self.rules)\n_ = (+ \(form) @sandhi \(harmony) @spelling)")
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
