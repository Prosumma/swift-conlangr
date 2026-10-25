import Conlangr
import Testing

/// A language inspired by Old Norse, as Old Icelandic is conventionally written in the
/// normalized spelling of modern editions.
///
/// This isn't Old Norse, only a sketch of its patterns:
///
/// - þ and ð are one sound: þ at the start of a word or of a compound's second element, and ð
///   everywhere else.
/// - The ð of the weak past becomes d after l, n and m, and t after a voiceless consonant:
///   taldi, nefndi, kastti.
/// - The nominative -r assimilates to a preceding l or n after a long vowel or diphthong:
///   stól-r → stóll, stein-r → steinn.
/// - u-umlaut: a becomes ǫ before an ending with u: land, plural lǫnd, dative lǫndum.
/// - Breaking gives ja and jǫ, as in hjarta and bjǫrn.
/// - Three identical consonants in a row, as where a compound's parts meet, become two.
///
/// The grammar writes θ for þ and ð, ɑ for the diphthong au, ks for x, and · between the parts
/// of a compound, and fills in the spelling at the end.
struct OldNorseTests {
  static let source = """
    ; Inspired by Old Norse. The grammar writes θ for both þ and ð, ɑ for the
    ; diphthong au (so that u-umlaut, which turns a into ǫ, leaves it alone),
    ; ks for x, and · between the parts of a compound.

    $nouns = 6
    $compounds = 2
    $verbs = 2
    $umlaut = 2       ; how often a noun takes an ending with u, out of 14

    _ = (+ (? $nouns &noun $compounds &compound $verbs &verb)
      > *lθ*=ld *nθ*=nd *mθ*=md                   ; the past's ð is d after l, n and m,
        *sθ*=st *kθ*=kt *pθ*=pt *tθ*=tt *fθ*=ft    ; and t after a voiceless consonant
        *álr=áll *élr=éll *ílr=íll *ólr=óll *úlr=úll *ýlr=ýll *ælr=æll  ; a final -r assimilates
        *ánr=ánn *énr=énn *ínr=ínn *ónr=ónn *únr=únn *einr=einn *sr=s  ; after a long vowel
        θ*=þ *·θ*=·þ *θ*=ð                         ; þ starts a word or a compound's part
        *·*=_ *ɑ*=au *ks*=x
        *sss*=ss *lll*=ll *nnn*=nn *rrr*=rr *ttt*=tt *kkk*=kk *ggg*=gg)  ; no triple consonants

    ; Nouns: a stem and a case ending. With an ending in u, a becomes ǫ.
    noun = (?
      10 (+ &stem &ending)
      $umlaut (+ (+ &stem > *a*=ǫ) (? 3 um 2 ur 1 u))
      2 (+ &stem (? 3 i 2 a)))
    ending = (? 6 r 2 _ 1 s 1 ar 1 ir 1 a 1 inn)

    ; Compounds, such as Miðgarðr and Ásþórr: a stem, then a noun or a name
    ; element. The second part keeps its þ.
    compound = (+ &stem · (? 3 &noun 2 &element))
    element = (? 2 garθr 2 ulfr 2 steinn 1 geirr 1 bjǫrn 1 grímr 1 mundr
      1 varθr 1 leifr 1 θórr 1 θórir 1 ketill 1 heimr)

    ; Verbs: the infinitive, the present participle, and the weak past.
    verb = (+ &stem (? 4 a 2 aθi 2 θi 1 θa 1 andi))

    ; A stem is a syllable that ends in a consonant.
    stem = (+ &onset &nucleus &coda)
    onset = (? 5 _ 3 h 3 s 3 b 2 d 3 f 3 g 3 k 2 l 3 m 3 n 1 p 2 r 3 t 4 θ 3 v
      2 st 2 sk 1 sp 1 sn 1 sl 1 sv 2 br 1 bl 2 dr 2 fr 2 fl 2 gr 1 gl 2 hr
      1 hl 1 hn 2 hv 2 kr 1 kl 1 kn 1 kv 1 pr 1 tr 1 θr 1 str 1 skr)
    nucleus = (? 6 a 5 e 4 i 4 o 3 u 2 y 1 ø
      2 á 1 é 2 í 2 ó 1 ú 1 ý 1 æ 1 œ
      3 ei 1 ey 2 ɑ 1 ja 1 jǫ 1 jó 1 jú)
    coda = (? 4 r 3 l 3 n 3 θ 2 g 2 k 2 t 2 s 2 f 2 m 1 p
      2 nd 2 ng 2 nk 2 rn 2 rθ 2 rg 2 rk 2 rm 1 rf 1 rs 1 rt 1 ld 1 lf 1 lk
      1 lm 1 ls 1 lt 1 st 1 sk 1 ft 1 kt 1 gg 1 kk 1 ll 1 nn 1 tt 1 ss 1 ks)
    """

  static let vowels = Set("aáeéiíoóuúyýæøœǫ")
  static let letters = vowels.union("bdðfghjklmnprstvxþ")

  /// The words to check, from a fixed seed.
  static func sample(overrides: [String: UInt8] = [:]) throws -> [String] {
    let generator = try Generator(source, overrides: overrides)
    var random = SplitMix64(seed: 874)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  @Test func usesOnlyTheInventory() throws {
    for word in try Self.sample() {
      #expect(word.count > 1)
      #expect(word.allSatisfy(Self.letters.contains), "\(word)")
    }
  }

  @Test func thornAndEth() throws {
    for word in try Self.sample() {
      #expect(word.first != "ð", "\(word)")
      let characters = Array(word)
      for i in characters.indices.dropFirst() where characters[i] == "þ" {
        // Inside a word, þ only starts a compound's second part, after a consonant.
        #expect(!Self.vowels.contains(characters[i - 1]), "\(word)")
      }
    }
  }

  @Test func assimilation() throws {
    for word in try Self.sample() {
      for cluster in ["lð", "nð", "mð", "sð", "kð", "pð", "tð", "fð"] {
        #expect(!word.contains(cluster), "\(word)")
      }
      for ending in ["álr", "ólr", "ílr", "ánr", "ónr", "ínr", "einr", "sr"] {
        #expect(!word.hasSuffix(ending), "\(word)")
      }
      let characters = Array(word)
      for i in characters.indices.dropFirst(2) {
        #expect(
          !(characters[i] == characters[i - 1] && characters[i] == characters[i - 2]), "\(word)")
      }
    }
  }

  @Test func uUmlaut() throws {
    // Every noun ending in -um has had its a's turned into ǫ, except in au. A compound's first
    // part isn't affected, so leave compounds out.
    let words = try Self.sample(overrides: ["compounds": 0, "verbs": 0])
    for word in words where word.hasSuffix("um") {
      #expect(!word.replacing("au", with: "").contains("a"), "\(word)")
    }
    #expect(words.contains { $0.contains("ǫ") })
    #expect(words.contains { $0.contains("au") })
  }

  @Test func familiarShapes() throws {
    let words = try Self.sample()
    for ending in ["garðr", "inn", "aði", "ldi", "um"] {
      #expect(words.contains { $0.hasSuffix(ending) }, "-\(ending)")
    }
    #expect(words.contains { $0.hasPrefix("þ") })
    #expect(words.contains { $0.dropFirst().contains("þ") })
  }
}
