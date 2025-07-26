import Parsimonious
import Testing
@testable import Conlangr

@Test func example() throws {
  let grammar = """
  ; Old Norse
  c = *ptkksnðrlmjgvhfb
  v = *aeiouyøæǫ
  diph = (? ei au ey øy)

  ; sometimes include diphthongs, sometimes not
  vowel = (? 2 &v &diph)

  ; simple syllable: CVC or CV
  syl = (? (+ &c &vowel &c) 2 (+ &c &vowel))

  _ = (+ &syl 4 &syl - *aa* *ii* *uu* *yy* *vv* *fv* *vf*) 
  """
  do {
    let output = try parse(grammar)
    let generator = try output.normalize()
    for _ in 0..<10 {
      try print("ON: \(generator.eval())")
    }
  } catch let e as ParseError<String> {
    let high = grammar.index(e.index, offsetBy: 5) 
    print(e)
    print(grammar[e.index..<high])
    throw e
  }
}

@Test func testPolynesian() throws {
  let grammar = """
  C = *ptkmnʔh          ; Simple Polynesian-style consonant inventory
  V = (? 3 a 1 ā 3 i 1 ī 3 u 1 ū 3 e 1 ē 3 o 1 ō) ; Five vowels with long/short distinction, long = 1/4
  syl = (+ &C &V)       ; CV syllables only (open)
  _ = (+ &syl 3 &syl)
  """
  do {
    let output = try parse(grammar, with: script)
    let generator = try output.normalize()
    for _ in 0..<10 {
      try print("POLYNESIAN: \(generator.eval())")
    }
  } catch let e as ParseError<String> {
    let high = grammar.index(e.index, offsetBy: 5) 
    print(e)
    print(grammar[e.index..<high])
    throw e
  }
}

@Test func testSinitic() throws {
  let grammar = """
  C = *ptkmnsʃxlrʔ         ; Initial consonants: wide range, including glottal
  F = *ptkŋnm              ; Final consonants: restricted, mostly voiceless stops + nasals
  S = (? &CV &CVC)         ; Each syllable is either CV or CVC
  _ = (+ &S &S - *tx*)            ; Exactly two syllables per word

  CV = (+ &C &V)           ; CV syllable
  CVC = (+ &C &V &F - *ʔ)  ; CVC syllable, final may not be glottal stop

  V = (? 
    3 a 1 á 
    3 e 1 é 
    3 i 1 í 
    3 u 1 ú 
    1 aa 1 áá 1 áa 1 aá)
  """
  do {
    let output = try parse(grammar, with: script)
    let generator = try output.normalize()
    for _ in 0..<10 {
      try print("SINITIC: \(generator.eval())")
    }
  } catch let e as ParseError<String> {
    let high = grammar.index(e.index, offsetBy: 5) 
    print(e)
    print(grammar[e.index..<high])
    throw e
  }
}

@Test func testKlingon() throws {
  let grammar = """
  ; Klingon
  C = (? b D g H j l m n p q Q r S t v w y %'   ; Klingon base consonants
    1 ch 1 gh 1 tlh 1 ng)                  ; Multigraphs with weight 1
  F = (? 
    3 b 3 D 3 g 3 H 3 j 3 l 3 m 3 n 3 p 3 q 3 Q 3 r 3 S 3 t 3 v 3 w 3 y
    1 ch 1 gh 1 tlh 1 ng)                  ; Same finals, weighted

  V = *aeIoU                               ; Klingon vowels: a e I o u

  S = (? 3 &CVC &CV)                         ; Favor closed syllables
  CV = (+ &C &V)
  CVC = (+ &C &V &F)

  _ = (+ &S 2 &S)
  """
  do {
    let output = try parse(grammar)
    let generator = try output.normalize()
    for _ in 0..<10 {
      try print("KLINGON: \(generator.eval())")
    }
  } catch let e as ParseError<String> {
    let high = grammar.index(e.index, offsetBy: 5) 
    print(e)
    print(grammar[e.index..<high])
    throw e
  }
}

@Test func testSumerian() throws {
  let grammar = """
  C = *bdgklmnprsʃt     ; Common Sumerian consonants (no q, x, z, etc.)
  V = *aeiu             ; Simple vowel system

  CV = (+ &C &V)
  VC = (+ &V &C)
  CVC = (+ &C &V &C)

  S = (? 4 &CV 2 &CVC 1 &V)   ; Favor open syllables, but allow CVC and occasional vowel-only
  _ = (+ &S 2 &S)
  """
  do {
    let output = try parse(grammar)
    let generator = try output.normalize()
    for _ in 0..<10 {
      try print("SUMERIAN: \(generator.eval())")
    }
  } catch let e as ParseError<String> {
    let high = grammar.index(e.index, offsetBy: 5) 
    print(e)
    print(grammar[e.index..<high])
    throw e
  }
}

@Test func testQuenya() throws {
  let grammar = """
  initialc = *ptkmnsrly
  medialc = (? mp nt nk ld rd ny ry ly nd mb)
  finalc  = *nrlmt
  vowel   = *aeiou
  middle  = (+ &vowel &medialc)
  final = (? 2 &vowel (+ &vowel &finalc))
  _       = (+ &initialc 2 &middle 1 &final - *yi*) ; Hello!
  """
  do {
    let output = try parse(grammar)
    let generator = try output.normalize()
    for _ in 0..<10 {
      try print("QUENYA: \(generator.eval())")
    }
  } catch let e as ParseError<String> {
    let high = grammar.index(e.index, offsetBy: 5) 
    print(e)
    print(grammar[e.index..<high])
    throw e
  }
}

@Test func testEvaluationCount() throws {
  let grammar = "_ = (+ k *ai - ka ki)"
  let script = try parse(grammar, with: script)
  let generator = try script.normalize()
  #expect(throws: EvaluationError.evaluationCountExceeded) {
    try generator.eval() 
  }
}