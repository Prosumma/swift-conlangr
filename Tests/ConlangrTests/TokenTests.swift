import Conlangr
import Testing

struct TokenTests {
  func kinds(_ source: String) -> [String] {
    tokenize(source).map { "\($0.kind):\($0.value)" }
  }

  @Test func everyKind() {
    #expect(
      kinds("$w = 12\n_ = (? $w a %( *bc &x - *q > a=_) ; hi\n [") == [
        "op:$", "literal:w", "op:=", "number:12",
        "literal:", "op:=", "parens:(", "op:?", "op:$", "literal:w", "literal:a", "literal:(",
        "op:*", "literal:bc", "op:&", "literal:x", "op:-", "op:*", "literal:q", "op:>",
        "literal:a", "op:=", "literal:", "parens:)", "comment: hi", "error:[",
      ])
  }

  @Test func copies() {
    #expect(
      kinds("_ = (+ &a ^a)") == [
        "literal:", "op:=", "parens:(", "op:+", "op:&", "literal:a", "op:^", "literal:a",
        "parens:)",
      ])
  }

  @Test func ruleSets() {
    #expect(
      kinds("@x = (> a=b)\n_ = (+ a @x)") == [
        "op:@", "literal:x", "op:=", "parens:(", "op:>", "literal:a", "op:=", "literal:b",
        "parens:)", "literal:", "op:=", "parens:(", "op:+", "literal:a", "op:@", "literal:x",
        "parens:)",
      ])
  }

  @Test func ranges() {
    let source = "x = %(ab ; c"
    let tokens = tokenize(source)
    #expect(tokens.map { String(source[$0.range]) } == ["x", "=", "%(ab", "; c"])
    #expect(tokens.map(\.value) == ["x", "=", "(ab", " c"])
  }

  @Test func errorsAreSingleCharacters() {
    #expect(kinds("a[]b") == ["literal:a", "error:[", "error:]", "literal:b"])
  }

  @Test func danglingPercent() {
    #expect(kinds("a% b%") == ["literal:a", "error:%", "literal:b", "error:%"])
  }

  @Test func braces() {
    #expect(
      kinds("*ɣ{i e}*=y{}") == [
        "op:*", "literal:ɣ", "braces:{", "literal:i", "literal:e", "braces:}", "op:*", "op:=",
        "literal:y", "braces:{", "braces:}",
      ])
  }

  @Test func neverFails() {
    #expect(tokenize("").isEmpty)
    #expect(tokenize("  \n\t ").isEmpty)
    #expect(kinds("!'\":#<[]") == "!'\":#<[]".map { "error:\($0)" })
  }

  @Test func acceptsScriptsThatDoNotParse() {
    #expect(kinds("_ = (? a") == ["literal:", "op:=", "parens:(", "op:?", "literal:a"])
  }
}
