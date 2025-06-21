import Parsimonious
import Testing
@testable import Conlangr

@Test func example() async throws {
  let grammar = """
  ; Old Norse
  c = *ptkksnðrlmjgvhfb
  v = *aeiouyøæǫ
  diph = (? ei au ey øy)

  ; sometimes include diphthongs, sometimes not
  vowel = (? 2 &v &diph)

  ; simple syllable: CVC or CV
  syl = (? (+ &c &vowel &c) (+ &c &vowel))

  ; usually 1 or 2 syllables, controlled externally by syl_count
  _ = (+ &syl &syl 2 &syl - *aa* *ii* *uu* *yy*) 
  """
  do {
    let output = try parse(grammar, with: script)
    let generator = try output.normalize()
    for _ in 0..<100 {
      try print(generator.eval())
    }
  } catch let e as ParseError<String> {
    let high = grammar.index(e.index, offsetBy: 5) 
    print(e)
    print(grammar[e.index..<high])
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
