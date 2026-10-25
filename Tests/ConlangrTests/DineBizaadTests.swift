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
struct DineBizaadTests {
  static let source = """
    ; Inspired by Diné Bizaad (Navajo). Words with no sibilants, words with
    ; front sibilants (s z ts ts' dz), and words with back sibilants (sh zh
    ; ch ch' j) are built separately, so the two series never mix.

    $prefixes = 3     ; the most prefixes a verb can have
    $nasality = 2     ; how often a stem vowel is nasal, out of 8

    _ = (+ (? 4 &plainWord 2 &frontWord 2 &backWord)
      - nn* nm* n%'* nh* ny* nw* nb* ng* nk*  ; a syllabic n needs a consonant it can join
      > *ghi*=yi *ghí*=yí *ghį*=yį *ghį́*=yį́    ; gh is written y before i and e,
        *ghe*=ye *ghé*=yé *ghę*=yę *ghę́*=yę́
        *gho*=wo *ghó*=wó *ghǫ*=wǫ *ghǫ́*=wǫ́)   ; and w before o

    ; A noun is a stem, with or without a possessor. A verb is one or more
    ; prefixes and a stem. Before a front sibilant, "my" is si-, not shi-.
    ; Before a back sibilant, the perfective prefix is shi-, not si-.
    plainWord = (?
      2 (+ (? 3 _ 3 &possessor 2 shi) &plainStem)
      3 (+ &syllabicN $prefixes &prefix (? 4 _ 1 si) &plainStem))
    frontWord = (?
      2 (+ (? 3 _ 3 &possessor 2 si) &frontStem)
      3 (+ &syllabicN $prefixes &prefix (? 4 _ 1 si 1 dzi) &frontStem))
    backWord = (?
      2 (+ (? 3 _ 3 &possessor 2 shi) &backStem)
      3 (+ &syllabicN $prefixes &prefix (? 4 _ 1 shi 1 ji) &backStem))

    possessor = (? 3 bi 2 ni 2 %'a 1 ha)   ; his or her, your, someone's, its
    syllabicN = (? 9 _ 1 n)

    ; Prefixes are CV, with low tone and a short oral vowel, most often i.
    prefix = (? 3 na 3 ni 3 di 3 yi 2 bi 2 da 2 ha 1 ho 1 %'a
      4 (+ &C (? 4 i 2 a 1 e 1 o)))

    ; Stems. After n or m, a vowel is written without its nasal hook.
    plainStem = (? 4 (+ &C &rhyme) 1 (+ &nasal &oralRhyme))
    frontStem = (? 3 (+ &front &rhyme) 1 (+ &C &vowel *sz) 1 (+ &front &vowel *sz))
    backStem = (? 3 (+ &back &rhyme) 1 (+ &C &vowel &backCoda) 1 (+ &back &vowel &backCoda))
    backCoda = (? 3 sh 1 zh)

    rhyme = (? 4 &vowel 3 (+ &vowel &coda) 1 (+ &oral n) 1 &diphthong)
    oralRhyme = (? 4 &oral 3 (+ &oral &coda) 1 (+ &oral n))
    coda = (? 4 %' 3 h 2 d 2 l 3 ł)

    ; Consonants other than sibilants and nasals: mostly coronal, few labials.
    C = (? 6 d 5 t 6 h 4 y 5 %' 4 ł 3 l 4 g 2 k 2 t%' 2 k%' 2 tł 1 tł%' 1 dl
      2 gh 1 hw 1 kw 1 w 3 b)
    nasal = (? 6 n 1 m)
    front = (? 4 s 3 ts 2 ts%' 2 dz 1 z)
    back = (? 4 sh 3 ch 2 ch%' 2 j 1 zh)

    ; Vowels are short or long, with low or high tone. Only long vowels can
    ; rise (aá) or fall (áa).
    vowel = (? 6 &oral $nasality &nasalVowel)
    oral = (?
      6 a 4 e 6 i 5 o
      3 á 2 é 3 í 2 ó
      3 aa 2 ee 3 ii 3 oo
      2 áá 1 éé 2 íí 2 óó
      1 aá 1 áa 1 eé 1 ée 1 ií 1 íi 1 oó 1 óo)
    nasalVowel = (? 3 ą 2 ę 3 į 2 ǫ 2 ą́ 1 ę́ 2 į́ 1 ǫ́ 1 ąą 1 įį 1 ǫǫ 1 ą́ą́ 1 į́į́)
    diphthong = (? 2 ai 2 ei 1 oi 1 ao 1 aii 1 eii)
    """

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
