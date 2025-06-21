import Parsimonious
import Testing
@testable import Conlangr

@Test func example() async throws {
  let grammar = """
  
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
