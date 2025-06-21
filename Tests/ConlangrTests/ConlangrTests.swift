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
  syl = (? (+ &c &vowel &c) 2 (+ &c &vowel))

  _ = (+ &syl 4 &syl - *aa* *ii* *uu* *yy* *vv* *fv* *vf*) 
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
