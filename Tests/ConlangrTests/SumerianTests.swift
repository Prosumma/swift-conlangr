import Conlangr
import Testing

/// A language inspired by Sumerian, written in the standard Assyriological transliteration.
///
/// This isn't Sumerian, only a sketch of its patterns and how they're written:
///
/// - Words are written as cuneiform signs joined by hyphens: lugal-e, mu-un-na-du₃. A subscript
///   number tells apart signs that sound alike, and ᵈ, the determinative for a god, starts a divine
///   name: ᵈen-lil₂.
/// - A noun is a root, then an optional plural (-e-ne), possessive (-ĝu₁₀, -zu, -a-ni, -bi) and
///   case (-e, -ra, -ta, -še₃, -da, and -a). After a consonant, the case -a is written by repeating
///   the consonant: lugal-la.
/// - A verb is an optional modal (ḫa-, nu-), a conjugation prefix (mu-, i₃-, ba-, bi₂-), an
///   optional dimensional prefix (na-, ši-, ta-, da-, ni-), the root, and a person suffix.
/// - Vowel harmony, as in Old Sumerian texts from Lagaš: i₃-, bi₂- and ni- become e-, be₂- and ne-
///   before a root whose vowel is a or e.
///
/// The grammar writes · between signs, I, J, B and N for the harmonizing prefixes (J is the -n-
/// after I), and ª for the case -a, and fills in the spelling at the end.
struct SumerianTests {
  static let source = """
    ; Inspired by Sumerian. Signs are separated by · until the end, when it
    ; becomes a hyphen. I, J, B and N stand for the prefixes that harmonize
    ; with the root's vowel, and ª for the case -a, which repeats a consonant.

    $nouns = 5
    $gods = 1
    $verbs = 4

    _ = (+ (? $nouns &noun $gods &god $verbs &verb)
      > *b·ª*=b·ba *d·ª*=d·da *g·ª*=g·ga *k·ª*=k·ka *l·ª*=l·la *m·ª*=m·ma   ; -a after a
        *n·ª*=n·na *r·ª*=r·ra *s·ª*=s·sa *š·ª*=š·ša *z·ª*=z·za *ĝ·ª*=ĝ·ĝa   ; consonant
        *ḫ·ª*=ḫ·ḫa *p·ª*=p·pa *t·ª*=t·ta *ª*=a
        *·*=%-)

    ; Nouns: a root, then plural, possessive and case.
    noun = (+ &nounRoot
      (? 8 _ 1 ·e·ne)
      (? 5 _ 1 ·ĝu₁₀ 1 ·zu 1 ·a·ni 1 ·bi)
      (? 3 _ 2 ·e 1 ·ra 1 ·ta 1 ·še₃ 1 ·da 2 ·ª))
    nounRoot = (? 3 &knownNoun 2 &sign 2 (+ &sign · &sign))
    knownNoun = (? 2 lugal 1 e₂ 1 dumu 1 nin 1 dub 1 kur 1 ki 1 ĝiš 1 uru 1 ensi₂
      1 sukkal 1 dam 1 ama 1 ša₃ 1 igi 1 šu 1 ka 1 mu 1 kug 1 gu₄ 1 udu 1 ezen
      1 e₂·gal 1 ab·ba 1 a·ša₃)

    ; A god's name: the determinative, a root, and perhaps another sign.
    god = (+ ᵈ &nounRoot (? 2 _ 1 (+ · &sign)))

    ; Verbs. The harmonizing prefixes take i before a root with i or u, and
    ; e before a root with a or e. J is the -n- after I: i₃-in- or e-en-.
    verb = (? (+ &chain &highRoot &ending > *I*=i₃ *J*=in *B*=bi₂ *N*=ni)
      (+ &chain &lowRoot &ending > *I*=e *J*=en *B*=be₂ *N*=ne))
    chain = (+
      (? 6 _ 1 ḫa· 1 nu·)
      (? 3 (+ mu· (? 3 _ 1 un·)) 3 (+ I· (? 3 _ 1 J·)) 2 (+ ba· (? 3 _ 1 an·)) 1 B·)
      (? 4 _ 1 na· 1 ši· 1 ta· 1 da· 1 N·))
    highRoot = (? du₃ dug₄ tuku ku₄ gi₄ gu₇ šum₂ zu tum₂ kur₉ us₂ gid₂ dib si tud
      ug₅ ḫul gul)
    lowRoot = (? ak ĝar sa₁₀ ra de₆ e₃ ĝen keš₂ me ba tak₄ šar₂ dab₅ kar naĝ ĝal₂)
    ending = (? 3 _ 1 ·en 1 ·e 1 ·eš)

    ; Signs: a vowel, with consonants before or after it, and sometimes an index.
    sign = (? 3 (+ &C &V &index) 2 (+ &C &V &C &index) 1 (+ &V &C &index))
    index = (? 8 _ 2 ₂ 2 ₃ 1 ₄ 1 ₅)
    C = (? 3 b 3 d 4 g 3 k 2 p 3 t 2 ĝ 4 m 4 n 4 l 3 r 3 s 3 š 2 z 2 ḫ)
    V = (? 4 a 3 e 3 i 3 u)
    """

  static let consonants = Set("bdgkptĝmnlrsšzḫ")
  static let vowels = Set("aeiu")
  static let subscripts = Set("₀₁₂₃₄₅₆₇₈₉")

  /// The words to check, from a fixed seed.
  static func sample(overrides: [String: UInt8] = [:]) throws -> [String] {
    let generator = try Generator(source, overrides: overrides)
    var random = SplitMix64(seed: 2600)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  /// Whether `segment` could be one sign: letters, at least one of them a vowel, perhaps followed by
  /// a subscript index. A logogram like lugal or sukkal is one sign, so a sign can be any length.
  static func isSign(_ segment: Substring) -> Bool {
    let letters = segment.prefix { !subscripts.contains($0) }
    let index = segment.dropFirst(letters.count)
    return letters.contains(where: vowels.contains)
      && letters.allSatisfy { vowels.contains($0) || consonants.contains($0) }
      && index.allSatisfy(subscripts.contains)
  }

  @Test func signs() throws {
    for word in try Self.sample() {
      let body = word.hasPrefix("ᵈ") ? word.dropFirst() : Substring(word)
      #expect(!body.contains("ᵈ"), "\(word)")
      let segments = body.split(separator: "-", omittingEmptySubsequences: false)
      #expect(segments.allSatisfy(Self.isSign), "\(word)")
    }
  }

  @Test func caseARepeatsAConsonant() throws {
    // The case -a after a consonant is written with that consonant, so a word never ends with the
    // bare sign a after a sign that ends in a consonant.
    for word in try Self.sample(overrides: ["verbs": 0]) where word.hasSuffix("a") {
      let segments = word.split(separator: "-")
      if segments.count > 1, let previous = segments.dropLast().last, segments.last == "a" {
        #expect(!Self.consonants.contains(previous.last!), "\(word)")
      }
    }
  }

  @Test func vowelHarmony() throws {
    let high: Set<Substring> = ["i₃", "bi₂", "ni"]
    let low: Set<Substring> = ["be₂", "ne"]
    for word in try Self.sample(overrides: ["nouns": 0, "gods": 0]) {
      let segments = word.split(separator: "-")
      let conjugation = segments.first { !["ḫa", "nu"].contains($0) }
      let isHigh = !high.isDisjoint(with: segments) || conjugation == "i₃"
      let isLow = !low.isDisjoint(with: segments) || conjugation == "e"
      #expect(!(isHigh && isLow), "\(word)")
    }
  }

  @Test func familiarShapes() throws {
    let words = try Self.sample()
    for part in ["lugal", "mu-un", "ᵈ", "₃", "ĝ", "š", "ḫ", "-la", "e₂"] {
      #expect(words.contains { $0.contains(part) }, "\(part)")
    }
  }
}
