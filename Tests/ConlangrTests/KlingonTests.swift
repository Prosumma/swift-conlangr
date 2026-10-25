import Conlangr
import Testing

/// A language inspired by Klingon, as Marc Okrand describes it in The Klingon Dictionary.
///
/// This isn't Klingon, only a sketch of its patterns:
///
/// - The spelling is case-sensitive: D, H, I, Q and S are distinct letters, and ch, gh, ng, tlh
///   and ' are single sounds.
/// - Every syllable starts with a consonant (' counts), and vowels never meet. The only clusters
///   that can end a syllable are rgh, w' and y'.
/// - Roots are mostly one syllable, CVC, sometimes two: tlhIngan, Qapla'.
/// - A verb takes an optional prefix for its subject and object, then suffixes in nine ordered
///   types: -'egh before -nIS before -choH, and so on, then a rover such as -be' (not). A noun takes
///   suffixes in five ordered types: -Hom, then -pu', then -qoq, then -wIj, then -Daq.
///
/// The grammar writes each sound as one lowercase symbol (ɖ for D, x for H, ɪ for I, χ for Q, ʂ
/// for S, č for ch, ɣ for gh, ŋ for ng, ƛ for tlh and ʔ for '), and the spelling is filled in at
/// the end.
struct KlingonTests {
  static let source = """
    ; Inspired by Klingon. Each sound is one lowercase symbol until the end:
    ; ɖ x ɪ χ ʂ are D H I Q S, and č ɣ ŋ ƛ ʔ are ch gh ng tlh '.

    $verbs = 5
    $nouns = 4

    _ = (+ (? $verbs &verb $nouns &noun)
      > *č*=ch *ɣ*=gh *ŋ*=ng *ƛ*=tlh *ʔ*=%'
        *ɖ*=D *x*=H *ɪ*=I *χ*=Q *ʂ*=S)

    ; Verbs: a prefix for the subject and object, the root, suffixes in their
    ; nine types (oneself, volition, change, cause, indefinite subject,
    ; qualification, aspect, honorific, syntactic), and a rover.
    verb = (+
      (? 5 _ 1 vɪ 1 ɖa 1 wɪ 1 ma 1 jɪ 1 bɪ 1 qa 1 ʂu 1 lu 1 nu 1 mu 1 čo 1 yɪ)
      &root
      (? 24 _ 1 ʔeɣ 1 čuq)
      (? 24 _ 1 nɪʂ 1 qaŋ 1 rup 1 bex 1 vɪp)
      (? 24 _ 1 čox 1 qaʔ)
      (? 28 _ 1 mox)
      (? 24 _ 1 luʔ 1 lax)
      (? 24 _ 1 čuʔ 1 bej 1 baʔ 1 lawʔ)
      (? 10 _ 1 puʔ 1 taʔ 1 tax 1 lɪʔ)
      (? 30 _ 1 neʂ)
      (? 14 _ 1 ɖɪʔ 1 čuɣ 1 paʔ 1 vɪʂ 1 boɣ 1 mex 1 moʔ 1 jaj 1 wɪʔ 1 ɣač)
      (? 12 _ 1 beʔ 1 χoʔ))

    ; Nouns: the root, then suffixes in their five types (size, number,
    ; qualification, possession, syntactic).
    noun = (+
      &root
      (? 12 _ 1 ʔaʔ 1 xom 1 oy)
      (? 8 _ 2 puʔ 1 ɖuʔ 2 mey)
      (? 16 _ 1 qoq 1 xey 1 naʔ)
      (? 10 _ 1 wɪj 1 lɪj 1 ɖaj 1 maj 1 raj 1 čaj 1 vam 1 veƛ)
      (? 8 _ 1 ɖaq 1 voʔ 1 moʔ 1 vaɖ 1 ʔeʔ))

    ; Roots: CVC, or CV(C)CVC. A syllable can also end in rgh, w' or y'.
    root = (? 8 (+ &C &V &final) 2 (+ &C &V (? 2 _ 1 &C) &C &V &final))
    final = (? 24 &C 1 rɣ 1 wʔ 1 yʔ)

    C = (? 4 b 3 č 4 ɖ 3 ɣ 3 x 4 j 3 l 4 m 4 n 2 ŋ 3 p 4 q 3 χ 3 r 4 ʂ 4 t
      2 ƛ 3 v 3 w 3 y 5 ʔ)
    V = (? 5 a 4 e 4 ɪ 4 o 4 u)
    """

  static let letters = Set("abDeghHIjlmnopqQrStuvwy'c")

  /// The words to check, from a fixed seed.
  static func sample() throws -> [String] {
    let generator = try Generator(source)
    var random = SplitMix64(seed: 1985)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  /// `word` split into its sounds, with tlh, ch, gh and ng each one sound. As in Klingon, ngh is
  /// n followed by gh.
  static func sounds(_ word: String) -> [String] {
    var sounds: [String] = []
    var rest = Substring(word)
    while !rest.isEmpty {
      let sound =
        rest.hasPrefix("ngh")
        ? "n" : ["tlh", "ch", "gh", "ng"].first { rest.hasPrefix($0) } ?? String(rest.first!)
      sounds.append(sound)
      rest = rest.dropFirst(sound.count)
    }
    return sounds
  }

  static let vowels: Set<String> = ["a", "e", "I", "o", "u"]

  @Test func usesOnlyTheInventory() throws {
    for word in try Self.sample() {
      #expect(word.allSatisfy(Self.letters.contains), "\(word)")
      // c, g and lowercase h only appear in ch, gh, ng and tlh.
      let sounds = Set(Self.sounds(word))
      #expect(sounds.isDisjoint(with: ["c", "g", "h"]), "\(word)")
    }
  }

  @Test func syllables() throws {
    for word in try Self.sample() {
      let sounds = Self.sounds(word)
      #expect(!Self.vowels.contains(sounds[0]), "\(word)")
      // Split into runs of consonants. Between vowels, a run is at most two consonants, or three
      // after rgh, w' or y'. At the end of the word, it's one consonant, or one of those.
      var runs: [[String]] = [[]]
      for sound in sounds {
        if Self.vowels.contains(sound) {
          #expect(!runs[runs.count - 1].isEmpty, "\(word): vowels meet")
          runs.append([])
        } else {
          runs[runs.count - 1].append(sound)
        }
      }
      let special: Set<[String]> = [["r", "gh"], ["w", "'"], ["y", "'"]]
      for (i, run) in runs.enumerated().dropFirst() {
        let isLast = i == runs.count - 1
        let coda = run.count > 1 ? Array(run.prefix(2)) : []
        let limit = special.contains(coda) ? 3 : 2
        if isLast {
          #expect(run.count <= 1 || special.contains(run), "\(word)")
        } else {
          #expect(run.count <= limit, "\(word)")
        }
      }
    }
  }

  @Test func familiarShapes() throws {
    let words = try Self.sample()
    for part in ["tlh", "Q", "gh", "be'", "pu'", "mey", "Daq", "'"] {
      #expect(words.contains { $0.contains(part) }, "\(part)")
    }
  }
}
