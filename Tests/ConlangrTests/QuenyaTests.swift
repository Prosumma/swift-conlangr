import Conlangr
import Testing

/// A language inspired by Quenya, the High-elven tongue of Tolkien's legendarium, in the spelling
/// of The Lord of the Rings and The Silmarillion.
///
/// This isn't Quenya, only a sketch of how it looks:
///
/// - c is written for k, qu for kw, and x for ks. A final e, and an e or o in hiatus, take a
///   diaeresis: Ainulindalë, Eärendil, Eönwë.
/// - A word ends in a vowel or in one of n, l, r, s and t.
/// - No cluster starts a word, except qu, ny, ty, hy and hw. b, d and g appear only in the
///   clusters mb, nd, ld, rd and ng.
/// - A long vowel never comes before a cluster.
/// - Plurals take -r after a vowel (Vala → Valar), -i after a consonant (Elen → Eleni), and turn a
///   final -ë into -i (lassë → lassi).
///
/// The grammar writes k, kw, ks and plain e, and fills in the spelling at the end.
struct QuenyaTests {
  static let source = """
    ; Inspired by Quenya. The grammar writes k for c, kw for qu, ks for x,
    ; and e for ë, and the spelling is filled in at the end.

    $words = 4
    $plurals = 1      ; so one word in five is plural

    _ = (+ (? $words &word $plurals &plural)
      > *ea*=eä *eo*=eö *oe*=oë *e=ë      ; an e or o in hiatus, or a final e, takes a diaeresis
        *kw*=qu *ks*=x *k*=c)            ; and k is written c

    ; A word is a first syllable, perhaps another, and an ending. A syllable
    ; here is a vowel and the consonants after it, and only a short vowel can
    ; come before a cluster.
    word = (+ &first (? 3 _ 2 &syllable) &last)
    first = (? 80 (+ &onset &syllable) 2 (+ e a &single) 1 (+ e o &single) 1 (+ o e &single))
    syllable = (?
      6 (+ &short &single) 4 (+ &short &cluster) 2 (+ &long &single) 1 (+ &diphthong &single))

    ; The ending: a vowel, perhaps with a dental after it, or a name element
    ; such as -ndil (friend), -ndur (servant), -ion (son) or -wë.
    last = (?
      8 (+ &end (? 3 _ 2 &final))
      2 (+ &short (? 3 ndil 2 ndur))
      2 (+ (? 3 &short 1 &long) &single (? 3 ion 2 ie))
      1 (+ &short (? 3 n 3 l 1 r 1 s 1 ng) we))

    ; Plurals: -i after a consonant, -ier for -ië, -i for -ë, and -r after
    ; any other vowel. Each rule sees the word as the one before left it.
    plural = (+ &word > *n=ni *l=li *r=ri *s=si *t=ti *ie=ier *e=i *a=ar *o=or *u=ur)

    onset = (? 7 _ 2 p 4 t 3 k 3 m 3 n 3 l 2 r 3 s 2 h 3 v 1 f 1 y
      1 kw 1 ny 1 ty 1 hy 1 hw)
    single = (? 4 l 4 n 4 r 3 m 4 s 3 t 3 k 1 p 2 v 1 f 1 h 2 y 1 w
      1 kw 1 ny 1 ty 1 ly 1 ry 1 hy)
    cluster = (? 3 nd 3 nt 2 ng 2 nk 1 ngw 1 nkw 2 mb 2 mp 2 ld 2 lt 1 lk
      3 ll 2 lm 1 lv 1 lw 2 rd 2 rt 2 rm 2 rn 1 rk 1 rkw 1 rv 1 rw 3 ss 2 st
      1 sk 1 ps 1 ts 1 ks 3 nn 2 mm 3 rr 1 ht 1 tt 1 pt 1 nw 1 ndy 1 lty)
    final = (? 4 n 3 r 3 l 3 s 2 t)

    short = (? 7 a 5 e 5 i 4 o 3 u)
    long = (? 3 á 3 é 3 í 3 ó 2 ú)
    diphthong = (? 3 ai 3 au 1 eu 1 iu 1 oi 1 ui)
    end = (? 6 a 6 e 2 i 4 o 2 u 1 ai)
    """

  static let vowels = Set("aeiouáéíóúëäö")
  static let letters = vowels.union("pctqmnlrshvfywdbgx")

  /// The words to check, from a fixed seed.
  static func sample(overrides: [String: UInt8] = [:]) throws -> [String] {
    let generator = try Generator(source, overrides: overrides)
    var random = SplitMix64(seed: 1977)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  @Test func usesOnlyTheInventory() throws {
    for word in try Self.sample() {
      #expect(word.count > 1)
      #expect(word.allSatisfy(Self.letters.contains), "\(word)")
    }
  }

  @Test func endsInAVowelOrADental() throws {
    for word in try Self.sample() {
      let last = word.last ?? "?"
      #expect(Self.vowels.contains(last) || "nlrst".contains(last), "\(word)")
      #expect(last != "e", "\(word)")
    }
  }

  @Test func spelling() throws {
    for word in try Self.sample() {
      let characters = Array(word)
      for (i, c) in characters.enumerated() {
        switch c {
        case "q": #expect(characters.dropFirst(i + 1).first == "u", "\(word)")
        case "b": #expect(i > 0 && characters[i - 1] == "m", "\(word)")
        case "d": #expect(i > 0 && "nlr".contains(characters[i - 1]), "\(word)")
        case "g": #expect(i > 0 && characters[i - 1] == "n", "\(word)")
        default: break
        }
      }
    }
  }

  @Test func noLongVowelBeforeACluster() throws {
    let long = Set("áéíóú")
    for word in try Self.sample() {
      // qu is one consonant, x is two, and a consonant followed by y is one, palatalized.
      let characters = Array(word.replacing("qu", with: "q"))
      for i in characters.indices where long.contains(characters[i]) {
        let run = characters[(i + 1)...].prefix { !Self.vowels.contains($0) }
        let single = run.count <= 1 && run.first != "x" || run.count == 2 && run.last == "y"
        #expect(single, "\(word)")
      }
    }
  }

  @Test func plurals() throws {
    let plurals = try Self.sample(overrides: ["plurals": 1, "words": 0])
    for word in plurals {
      #expect(word.hasSuffix("r") || word.hasSuffix("i"), "\(word)")
    }
    #expect(plurals.contains { $0.hasSuffix("ar") })
    #expect(plurals.contains { $0.hasSuffix("ier") })
  }

  @Test func familiarShapes() throws {
    let words = try Self.sample()
    for part in ["ndil", "ion", "wë", "qu", "eä"] {
      #expect(words.contains { $0.contains(part) }, "\(part)")
    }
  }
}
