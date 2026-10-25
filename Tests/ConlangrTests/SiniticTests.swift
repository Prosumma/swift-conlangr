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
  static let source = """
    ; A Sinitic language, written in pinyin. Each syllable starts with a dot,
    ; and its tone is a superscript number after the vowel that will carry the
    ; mark. The spelling rules at the end, in order, give zero initials y or
    ; w, shorten iou, uei and uen after a consonant, write ü as u after j, q
    ; and x, add apostrophes, and mark the tones.

    _ = (+ &first (? 2 _ 6 &syllable 1 (+ &syllable &syllable))
      > *.ia*=.ya *.ie*=.ye *.io*=.yo *.i*=.yi            ; zero initials
        *.ua*=.wa *.uo*=.wo *.ue*=.we *.u*=.wu *.ü*=.yu
        *io¹u*=iu¹ *io²u*=iu² *io³u*=iu³ *io⁴u*=iu⁴ *io⁰u*=iu⁰  ; iou → iu
        *ue¹i*=ui¹ *ue²i*=ui² *ue³i*=ui³ *ue⁴i*=ui⁴ *ue⁰i*=ui⁰  ; uei → ui
        *ue¹n*=u¹n *ue²n*=u²n *ue³n*=u³n *ue⁴n*=u⁴n *ue⁰n*=u⁰n  ; uen → un
        *jü*=ju *qü*=qu *xü*=xu                             ; ü after j, q, x
        .*=_ *.a*=%'a *.o*=%'o *.e*=%'e *.*=_               ; apostrophes
        *a¹*=ā *a²*=á *a³*=ǎ *a⁴*=à *e¹*=ē *e²*=é *e³*=ě *e⁴*=è  ; tones
        *i¹*=ī *i²*=í *i³*=ǐ *i⁴*=ì *o¹*=ō *o²*=ó *o³*=ǒ *o⁴*=ò
        *u¹*=ū *u²*=ú *u³*=ǔ *u⁴*=ù *ü¹*=ǖ *ü²*=ǘ *ü³*=ǚ *ü⁴*=ǜ
        *⁰*=_ *ẑ*=zh *ĉ*=ch *ŝ*=sh *ŋ*=ng)     ; the neutral tone isn't marked

    ; The first syllable, which can't have the neutral tone.
    first = (+ &syllable - *⁰*)

    ; A syllable: each group of initials takes only the finals it can.
    syllable = (+ . (?
      3 (+ (? b p m) (? 6 &core 1 (+ o &T) 3 &frontL 1 (+ u &T)))
      1 (+ f (? 6 &core 1 (+ o &T) 1 (+ u &T)))
      3 (+ (? d t) (? 6 &core 1 &ong 3 &frontD 3 &roundD))
      2 (+ (? n l) (? 6 &core 1 &ong 3 &front 2 &roundD 1 (+ ü &T) 1 (+ ü e &T)))
      3 (+ (? g k h) (? 6 &core 1 &ong 4 &round))
      3 (+ (? j q x) (? 6 &front 3 &umlaut))
      3 (+ (? ẑ ĉ ŝ r) (? 6 &core 1 &ong 2 (+ i &T) 4 &round))
      2 (+ (? z c s) (? 6 &core 1 &ong 2 (+ i &T) 3 &roundD))
      3 (? 5 &core 1 (+ o &T) 3 &front 3 &round 1 &umlaut 1 (+ e &T r))))

    ; Finals, each with its tone after the vowel that carries the mark.
    core = (? 3 (+ a &T) 2 (+ e &T) 2 (+ a &T i) 2 (+ e &T i) 2 (+ a &T o) 2 (+ o &T u)
      3 (+ a &T n) 3 (+ e &T n) 3 (+ a &T ŋ) 2 (+ e &T ŋ))
    ong = (+ o &T ŋ)
    front = (? 3 (+ i &T) 2 (+ i a &T) 2 (+ i e &T) 2 (+ i a &T o) 2 (+ i o &T u)
      2 (+ i a &T n) 2 (+ i &T n) 2 (+ i a &T ŋ) 2 (+ i &T ŋ) 1 (+ i o &T ŋ))
    frontL = (? 3 (+ i &T) 2 (+ i e &T) 2 (+ i a &T o) 2 (+ i a &T n) 2 (+ i &T n) 2 (+ i &T ŋ))
    frontD = (? 3 (+ i &T) 2 (+ i e &T) 2 (+ i a &T o) 2 (+ i o &T u) 2 (+ i a &T n) 2 (+ i &T ŋ))
    round = (? 3 (+ u &T) 1 (+ u a &T) 2 (+ u o &T) 1 (+ u a &T i) 2 (+ u e &T i)
      2 (+ u a &T n) 2 (+ u e &T n) 1 (+ u a &T ŋ))
    roundD = (? 3 (+ u &T) 2 (+ u o &T) 2 (+ u e &T i) 2 (+ u a &T n) 2 (+ u e &T n))
    umlaut = (? 2 (+ ü &T) 2 (+ ü e &T) 1 (+ ü a &T n) 1 (+ ü &T n))

    ; The four tones, and the neutral tone ⁰, which isn't marked when spelled.
    T = (? 3 ¹ 3 ² 2 ³ 3 ⁴ 1 ⁰)
    """

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
