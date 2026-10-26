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
  static let source = """
    ; Inspired by Sindarin. A word is a monosyllable, a longer word, or a
    ; plural, whose vowels change.
    ;
    ; Each digraph is a single letter until the end, so that every rule sees
    ; one letter per sound: þ is th, ð is dh, χ is ch, φ is ph, ł is lh, ř is
    ; rh, and ƕ is hw. Then n before φ can't be mistaken for np.

    $monosyllables = 2
    $words = 6
    $plurals = 2

    _ = (+ (? $monosyllables &monosyllable $words &word $plurals &plural)
      > *nr*=ðr *n{l m}*={}{} *n{b p}*=m{b m} *mp*=mm *dl*=ll  ; assimilation
        *au=aw *v=f                       ; final au is written aw, final v is f
        *{þ ð χ φ ł ř ƕ}*={th dh ch ph lh rh hw})  ; spell the digraphs

    ; Monosyllables. A long vowel here takes a circumflex.
    monosyllable = (?
      4 (+ &onset &short &coda)
      2 (+ &onset &circumflex &single)
      1 (+ &onset &diphthong (? 2 _ 1 &single)))

    ; Longer words: syllables, then an ending. The ending is a final syllable,
    ; which seldom ends in a vowel, a suffix like -ion or -iel, or an element
    ; like -dor or -wen. A long vowel or diphthong comes before at most one
    ; consonant, and ai only in the last syllable.
    word = (+ &onset &inner (? 4 _ 1 (+ &medial &inner)) &ending)
    ending = (?
      6 (+ &medial &short &coda)
      1 (+ &medial &long &single)
      1 (+ &medial &diphthong (? 1 _ 2 &single))
      1 (+ &medial (? 3 a 2 e 1 i))
      2 (+ &medial &suffix)
      2 (+ &join &element))
    suffix = (? 3 ion 2 ien 2 iel 2 or 2 on 1 eþ 1 aþ 1 ir 1 el 1 il 1 in 1 uin)
    element = (? 3 dor 2 dir 2 wen 1 las 1 ras 1 born 1 rond 1 þil 1 duin 1 nor)

    ; Plurals. The last syllable's vowel changes one way, and the rest another.
    ; Long vowels don't change, so Dúnadan becomes Dúnedain.
    plural = (?
      1 (+ &onset &short &coda > *{a o e u}*={ai y i y})
      3 (+ (+ &onset &pluralVowel (? 3 _ 1 (+ &medial &pluralVowel)) > *{a o u}*={e e y})
        (+ &medial &short &coda > *{a o e u}*={ai y i y})))
    pluralVowel = (? 12 &short 2 &long 1 ai)

    ; Consonants: at the start of a word, between vowels, at the end, and
    ; where an element like -dor joins. Only an onset has ł, ř or ƕ.
    onset = (? 6 _ 2 b 3 c 3 d 3 g 1 p 3 t 2 f 2 h 3 m 3 n 3 l 2 r 3 s 2 þ
      1 gl 1 gr 1 br 1 dr 1 cr 1 cl 1 fl 1 þr 2 gw 1 ł 1 ř 1 ƕ)
    medial = (? 3 d 2 g 2 b 3 l 3 r 3 n 2 m 2 s 3 þ 2 ð 2 χ 1 v 1 φ
      3 nd 2 ng 2 nn 2 ll 2 ss 1 mm 2 dr 1 gl 1 gr 1 br 1 þr 1 rn 1 rþ 1 lþ
      1 rχ 1 lχ 1 mb 1 lw 1 rw 1 nw)
    single = (? 4 n 4 r 3 l 2 s 3 þ 1 ð 2 χ 1 v 1 d 1 g)
    coda = (? 12 &single 2 nd 1 nt 1 ng 1 nn 1 ll 1 ss 1 rn 1 rχ 1 lχ 1 lφ
      1 rþ 1 st)
    join = (? 4 n 4 r 3 l 1 s 1 þ)

    ; Vowels.
    inner = (? 14 &short 2 &long 1 ei 1 ae 1 au)
    short = (? 6 a 5 e 5 i 5 o 1 u 1 y)
    long = (? 3 á 2 é 2 í 3 ó 2 ú 1 ý)
    circumflex = (? 3 â 2 ê 3 î 2 ô 3 û 1 ŷ)
    diphthong = (? 2 ai 1 ei 1 ui 2 ae 1 oe 2 au)
    """

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
