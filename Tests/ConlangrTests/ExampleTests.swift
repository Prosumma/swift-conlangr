import Conlangr
import Testing

/// Grammars for a few natural and invented languages. Each must compile, and every word it
/// generates must use only the language's letters.
struct ExampleTests {
  struct Example: Sendable, CustomTestStringConvertible {
    let name: String
    let source: String
    /// Every character a word may contain.
    let letters: Set<Character>

    var testDescription: String { name }
  }

  static let examples = [
    Example(
      name: "Old Norse",
      source: """
        ; Old Norse
        c = *ptkksnðrlmjgvhfb
        v = *aeiouyøæǫ
        diph = (? ei au ey øy)

        ; sometimes include diphthongs, sometimes not
        vowel = (? 2 &v &diph)

        ; simple syllable: CVC or CV
        syl = (? (+ &c &vowel &c) 2 (+ &c &vowel))

        _ = (+ &syl 4 &syl - *aa* *ii* *uu* *yy* *vv* *fv* *vf*)
        """,
      letters: Set("ptksnðrlmjgvhfbaeiouyøæǫ")
    ),
    Example(
      name: "Polynesian",
      source: """
        C = *ptkmnʔh          ; Simple Polynesian-style consonant inventory
        V = (? 3 a 1 ā 3 i 1 ī 3 u 1 ū 3 e 1 ē 3 o 1 ō) ; Five vowels, long = 1/4
        syl = (+ &C &V)       ; CV syllables only (open)
        _ = (+ &syl 3 &syl)
        """,
      letters: Set("ptkmnʔhaāiīuūeēoō")
    ),
    Example(
      name: "Sinitic",
      source: """
        C = *ptkmnsʃxlrʔ         ; Initial consonants: wide range, including glottal
        F = *ptkŋnm              ; Final consonants: mostly voiceless stops + nasals
        S = (? &CV &CVC)         ; Each syllable is either CV or CVC
        _ = (+ &S &S - *tx*)     ; Exactly two syllables per word

        CV = (+ &C &V)           ; CV syllable
        CVC = (+ &C &V &F)       ; CVC syllable

        V = (?
          3 a 1 á
          3 e 1 é
          3 i 1 í
          3 u 1 ú
          1 aa 1 áá 1 áa 1 aá)
        """,
      letters: Set("ptkmnsʃxlrʔŋaáeéiíuú")
    ),
    Example(
      name: "Klingon",
      source: """
        ; Klingon
        C = (? b D g H j l m n p q Q r S t v w y %'   ; Klingon base consonants
          1 ch 1 gh 1 tlh 1 ng)                    ; Multigraphs with weight 1
        F = (?
          3 b 3 D 3 g 3 H 3 j 3 l 3 m 3 n 3 p 3 q 3 Q 3 r 3 S 3 t 3 v 3 w 3 y
          1 ch 1 gh 1 tlh 1 ng)                    ; Same finals, weighted

        V = *aeIoU                                 ; Klingon vowels: a e I o u

        S = (? 3 &CVC &CV)                         ; Favor closed syllables
        CV = (+ &C &V)
        CVC = (+ &C &V &F)

        _ = (+ &S 2 &S)
        """,
      letters: Set("bDgHjlmnpqQrStvwy'chaeIoU")
    ),
    Example(
      name: "Sumerian",
      source: """
        C = *bdgklmnprsʃt     ; Common Sumerian consonants
        V = *aeiu             ; Simple vowel system

        CV = (+ &C &V)
        VC = (+ &V &C)
        CVC = (+ &C &V &C)

        S = (? 4 &CV 2 &CVC 1 &V)   ; Favor open syllables
        _ = (+ &S 2 &S)
        """,
      letters: Set("bdgklmnprsʃtaeiu")
    ),
    Example(
      name: "Quenya",
      source: """
        initialc = *ptkmnsrly
        medialc = (? mp nt nk ld rd ny ry ly nd mb)
        finalc  = *nrlmt
        vowel   = *aeiou
        middle  = (+ &vowel &medialc)
        final = (? 2 &vowel (+ &vowel &finalc))
        _       = (+ &initialc 2 &middle 1 &final - *yi*) ; Hello!
        """,
      letters: Set("ptkmnsrlydbaeiou")
    ),
  ]

  @Test(arguments: examples)
  func example(_ example: Example) throws {
    let generator = try Generator(example.source)
    var random = SplitMix64(seed: 7)
    for _ in 0..<1_000 {
      let word = try generator.generate(using: &random)
      #expect(!word.isEmpty)
      #expect(word.allSatisfy(example.letters.contains), "\(word)")
    }
  }
}
