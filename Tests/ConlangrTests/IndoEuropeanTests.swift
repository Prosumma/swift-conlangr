import Conlangr
import Testing

/// A language inspired by Proto-Indo-European, in the standard laryngealist reconstruction
/// (Ringe, Fortson, Beekes), with Kümmel's uvular values for the laryngeals in mind.
///
/// This isn't PIE, only a sketch of its patterns:
///
/// - Three series of stops (voiceless, plain voiced, voiced aspirated) at five places, with
///   palatovelars (ḱ) and labiovelars (kʷ). Plain *b is very rare.
/// - Three laryngeals, h₁ h₂ h₃. h₂ colors a neighboring e to a, and h₃ colors it to o.
/// - Roots are CeC, with an optional s- before a voiceless stop and resonants beside the
///   vowel. A root can't have two plain voiced stops (no *ded-), and can't mix voiceless and
///   voiced aspirated stops (no *tedʰ-). No root starts with a vowel: what looks like one
///   starts with a laryngeal, as in h₁es- "be".
/// - Ablaut: a root's vowel is e or o in the full grade, ē or ō in the lengthened grade, or
///   nothing in the zero grade, where a neighboring resonant becomes syllabic (r̥ l̥ m̥ n̥ i u).
///   The zero grade goes with an unaccented root, as in *ḱlutós "heard" beside *ḱléwos "fame".
/// - Each word has one accent, on the root, a suffix, or the ending.
/// - Sound laws at the end of the word: Szemerényi's law (-ter-s → -tḗr), syllabic -m̥ after a
///   consonant (*ph₂térm̥), s → z before a voiced stop, and t inserted between dentals
///   (*wid-tó- → *witstó-).
struct IndoEuropeanTests {
  static let source = """
    ; Inspired by Proto-Indo-European. Each root is built with · in place of
    ; its vowel, which ablaut fills in. Sound laws apply to the whole word.

    $zeroGrade = 5    ; how often an unaccented root is zero grade, out of 6

    _ = (+ (? 3 &thematicNoun 2 &athematicNoun 3 &verb)
      > *h₂{e é}*=h₂{a á} *{e é}h₂*={a á}h₂      ; h₂ colors e to a,
        *h₃{e é}*=h₃{o ó} *{e é}h₃*={o ó}h₃      ; and h₃ colors it to o
        *s{d g ǵ b}*=z{}                         ; s is voiced before a voiced stop
        *{t d}t*=tst                             ; t is inserted between dentals
        *{e é o ó}{r n}s={ē ḗ ō ṓ}{}             ; Szemerényi's law: a final -Rs
        *{o ó}ss={ō ṓ}s                          ; or -ss loses its s and lengthens the vowel
        *{r n s h₂}m={}m̥)                        ; final -m after a consonant is syllabic

    ; Thematic nouns and adjectives: a root, perhaps a suffix, and a thematic
    ; ending, accented on the root (*dómos) or on the ending (*ḱlutós).
    thematicNoun = (?
      3 (+ &accentedRoot (? 3 _ 1 &stemSuffix) &nounEnding)
      3 (+ &plainRoot (? 1 _ 2 &stemSuffix) &accentedNounEnding))
    stemSuffix = (? 3 t 2 r 2 n 1 m 1 l 2 y 1 w 1 tr 1 sḱ)
    nounEnding = (? 5 os 3 om 1 osyo 1 oh₁ 1 ōs 1 oys 2 eh₂ 1 ih₂)
    accentedNounEnding = (? 5 ós 3 óm 1 ósyo 1 óh₁ 1 ṓs 1 óys 2 éh₂ 1 íh₂)

    ; Athematic nouns, with suffixes such as -ter- (agent), -men- (result) and
    ; -ti- (action): *ph₂tḗr "father", *gʷm̥tís "a going", *h₁nómn̥ "name".
    athematicNoun = (?
      3 (+ &accentedRoot &suffix &ending)
      2 (+ &plainRoot &accentedSuffix (? 4 s 2 m 1 _))
      1 (+ &plainRoot &zeroSuffix &accentedEnding)
      1 (+ &accentedRoot mn̥))
    suffix = (? 3 ter 2 tor 2 men 1 mon 2 ti 1 tu 1 wos 1 en 1 er 1 h₂)
    accentedSuffix = (? 3 tér 2 tór 2 mén 1 món 2 tí 1 tú 1 wós 1 én 1 ér)
    zeroSuffix = (? 3 tr 2 mn 2 t 1 tw 1 n)
    ending = (? 4 s 3 m 1 i 1 es 1 h₁ 1 _)
    accentedEnding = (? 4 és 2 éy 1 éh₁ 1 ós 1 ém)

    ; Verbs: thematic presents (*bʰéreti), presents in -yé- and -sḱé- with a
    ; zero-grade root (*gʷm̥sḱéti), athematic presents (*h₁ésti, plural
    ; *h₁sénti), and causatives in -éye- with an o-grade root (*bʰoréyeti).
    verb = (?
      4 (+ &accentedRoot &thematicEnding)
      2 (+ &plainRoot (? 3 y 2 sḱ) &accentedThematicEnding)
      2 (+ &accentedRoot &athematicEnding)
      1 (+ &plainRoot &accentedAthematicEnding)
      1 (+ &oRoot éy &thematicEnding))
    thematicEnding = (? 3 eti 2 esi 2 oh₂ 2 onti 1 omos 1 ete 1 etor 1 ontor)
    accentedThematicEnding = (? 3 éti 2 ési 2 óh₂ 2 ónti 1 ómos 1 éte)
    athematicEnding = (? 4 ti 3 si 3 mi 1 toy)
    accentedAthematicEnding = (? 4 énti 2 més 2 té)

    ; Ablaut fills in the root's vowel. Accented, it's e or o, rarely ē or ō.
    ; Unaccented, it's usually the zero grade: a resonant beside the gap
    ; becomes syllabic (the one after it first), or a laryngeal closes it
    ; (*peh₂- → *ph₂-). Between two stops, the root keeps its e.
    accentedRoot = (?
      6 (+ &root > *·*=é) 3 (+ &root > *·*=ó) 1 (+ &root > *·*=ḗ) 1 (+ &root > *·*=ṓ))
    oRoot = (+ &root > *·*=o)
    plainRoot = (? $zeroGrade &zeroRoot 1 (+ &root > *·*=e))
    zeroRoot = (+ &root
      > *·{r l m n y w}*={r̥ l̥ m̥ n̥ i u} *{r l m n y w}·*={r̥ l̥ m̥ n̥ i u}
        *{h₁ h₂ h₃}·*={} *·{h₁ h₂ h₃}*={}
        *·*=e)

    ; Roots: every combination of stops except two plain voiced ones (*ded-),
    ; or a voiceless one with a voiced aspirate (*tedʰ-, *dʰet-). Nor does a
    ; root have the same laryngeal on both sides of its vowel.
    root = (?
      3 (+ &onsetT · &codaT) 2 (+ &onsetT · &codaD) 2 (+ &onsetD · &codaT)
      1 (+ &onsetDh · &codaD) 1 (+ &onsetD · &codaDh) 1 (+ &onsetDh · &codaDh)
      4 (+ &onsetT · &codaN) 3 (+ &onsetD · &codaN) 3 (+ &onsetDh · &codaN)
      3 (+ &onsetN · &codaT) 2 (+ &onsetN · &codaD) 2 (+ &onsetN · &codaDh)
      3 (+ &onsetN · &codaN - *{h₁ h₂ h₃}·{}*))

    ; Onsets and codas, by the kind of stop they contain. Only a voiceless stop
    ; can take s- in front (s-mobile: *speḱ-, *steh₂-).
    onsetT = (? 6 &T 2 (+ s &T) 2 (+ &T &glide) 1 (+ s &T &glide))
    onsetD = (? 6 &D 2 (+ &D &glide))
    onsetDh = (? 6 &Dh 2 (+ &Dh &glide))
    onsetN = (? 4 &H 3 &R 1 s 2 (+ &H &R) 1 (+ s &R))
    codaT = (? 5 &T 2 (+ &R &T))
    codaD = (? 5 &D 2 (+ &R &D))
    codaDh = (? 5 &Dh 2 (+ &R &Dh))
    codaN = (? 3 &R 3 &H 2 s 1 (+ &R &H))

    T = (? 5 t 4 k 3 p 3 ḱ 3 kʷ)
    D = (? 10 d 6 g 6 ǵ 4 gʷ 1 b)
    Dh = (? 5 dʰ 4 bʰ 3 gʰ 3 ǵʰ 3 gʷʰ)
    H = (? 2 h₁ 3 h₂ 1 h₃)
    R = (? 4 r 3 l 3 m 4 n 3 y 4 w)
    glide = (? 3 r 2 l 2 w 1 y 1 n)
    """

  static let accented = Set("éóáíúḗṓ")
  static let vowels = accented.union("eoaiuēō")
  static let letters = vowels.union("ptkbdgḱǵʰʷszh₁₂₃rlmnywr̥l̥m̥n̥")

  /// The words to check, from a fixed seed.
  static func sample() throws -> [String] {
    let generator = try Generator(source)
    var random = SplitMix64(seed: 1786)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  @Test func usesOnlyTheInventory() throws {
    // This also checks that ablaut filled in every root's vowel, since · isn't a letter.
    for word in try Self.sample() {
      #expect(word.allSatisfy(Self.letters.contains), "\(word)")
    }
  }

  @Test func oneAccentPerWord() throws {
    for word in try Self.sample() {
      #expect(word.filter(Self.accented.contains).count == 1, "\(word)")
    }
  }

  @Test func noRootStartsWithAFullVowel() throws {
    // A zero-grade root can start with a syllabic resonant, as in *us- beside *wes-.
    for word in try Self.sample() {
      #expect(!"eoaéóáēōḗṓ".contains(word.first ?? "e"), "\(word)")
    }
  }

  @Test func laryngealsColorTheirNeighbors() throws {
    for word in try Self.sample() {
      for uncolored in ["h₂e", "eh₂", "h₂é", "éh₂", "h₃e", "eh₃", "h₃é", "éh₃"] {
        #expect(!word.contains(uncolored), "\(word)")
      }
    }
  }

  @Test func soundLaws() throws {
    for word in try Self.sample() {
      for cluster in ["sd", "sg", "sǵ", "sb", "tt", "dt"] {
        #expect(!word.contains(cluster), "\(word)")
      }
      for ending in [
        "ers", "érs", "ors", "órs", "ens", "éns", "ons", "óns", "oss", "óss", "rm", "nm", "sm",
        "h₂m",
      ] {
        #expect(!word.hasSuffix(ending), "\(word)")
      }
    }
  }

  @Test func ablautProducesEveryGrade() throws {
    let words = try Self.sample()
    let syllabic = Set("r̥l̥m̥n̥")
    #expect(words.contains { $0.contains(where: syllabic.contains) })
    #expect(words.contains { $0.contains("ḗ") || $0.contains("ṓ") })
    #expect(words.contains { $0.contains("ó") })
  }

  @Test func classicShapes() throws {
    // The generator can produce some textbook forms, which shows the parts fit together.
    let words = Set(try Self.sample())
    #expect(words.contains { $0.hasSuffix("tḗr") })
    #expect(words.contains { $0.hasSuffix("éti") })
    #expect(words.contains { $0.hasSuffix("mn̥") })
    #expect(words.contains { $0.contains("h₂a") || $0.contains("ah₂") })
  }
}
