import Conlangr
import Testing

struct WarningTests {
  @Test func cleanScriptHasNone() throws {
    #expect(try warnings("$n = 2\n_ = (+ $n &syllable > *a=á)\nsyllable = (? ka sa)") == [])
  }

  @Test(arguments: [
    QuenyaTests.source, SindarinTests.source, OldNorseTests.source, IndoEuropeanTests.source,
    PolynesianTests.source, SiniticTests.source, DineBizaadTests.source, KlingonTests.source,
    SumerianTests.source,
  ])
  func examplesHaveNone(source: String) throws {
    #expect(try warnings(source) == [])
  }

  @Test func areInSourceOrder() throws {
    #expect(
      try warnings("@x = (- q)\n_ = (+ a - *z*)\n$n = 1\nb = c") == [
        "1:1: Nothing uses the rule set \"@x\".",
        "1:9: Nothing in the script produces \"q\", so this can never match.",
        "2:13: Nothing in the script produces \"z\", so this can never match.",
        "3:1: Nothing uses the variable \"$n\".",
        "4:1: Nothing refers to the production \"b\".",
      ])
  }

  @Test func locationAndProblemArePublic() throws {
    let warning = try #require(try Generator("_ = a\nb = c").warnings.first)
    #expect(warning.problem == .unusedProduction("b"))
    #expect(warning.location.line == 2)
    #expect(warning.location.column == 1)
  }
}

struct UnusedTests {
  @Test func production() throws {
    #expect(try warnings("_ = a\nb = c") == ["2:1: Nothing refers to the production \"b\"."])
  }

  @Test func mainIsNeverUnused() throws {
    #expect(try warnings("_ = a") == [])
  }

  @Test func referenceToItselfDoesNotCount() throws {
    #expect(
      try warnings("_ = a\nb = (? c 1 (+ c &b))") == [
        "2:1: Nothing refers to the production \"b\"."
      ])
  }

  @Test func referenceFromAnUnusedProductionCounts() throws {
    // Each production may be a starting point, so only "b" is reported, not "c".
    #expect(
      try warnings("_ = a\nb = &c\nc = d") == ["2:1: Nothing refers to the production \"b\"."])
  }

  @Test func variable() throws {
    #expect(try warnings("$n = 2\n_ = a") == ["1:1: Nothing uses the variable \"$n\"."])
  }

  @Test func variableUsedAsAWeight() throws {
    #expect(try warnings("$n = 2\n_ = (? $n a b)") == [])
  }

  @Test func variableUsedInAnUnusedProduction() throws {
    #expect(
      try warnings("$n = 2\n_ = a\nb = (+ $n c)") == [
        "3:1: Nothing refers to the production \"b\"."
      ])
  }

  @Test func overrideDoesNotCountAsAUse() throws {
    let generator = try Generator("$n = 2\n_ = a", overrides: ["n": 3])
    #expect(generator.warnings.map(\.description) == ["1:1: Nothing uses the variable \"$n\"."])
  }

  @Test func ruleSet() throws {
    #expect(try warnings("@x = (> a=b)\n_ = a") == ["1:1: Nothing uses the rule set \"@x\"."])
  }

  @Test func ruleSetUsedByAnotherRuleSet() throws {
    #expect(
      try warnings("@x = (> a=b)\n@y = (@x)\n_ = a") == [
        "2:1: Nothing uses the rule set \"@y\"."
      ])
  }

  @Test func ruleSetUsedByAProduction() throws {
    #expect(try warnings("@x = (> a=b)\n_ = (+ a @x)") == [])
  }
}

struct CannotMatchTests {
  @Test func text() throws {
    #expect(
      try warnings("_ = (+ *sa > sh=š)") == [
        "1:14: Nothing in the script produces \"h\", so this can never match."
      ])
  }

  @Test func eachAlternativeOfAClass() throws {
    #expect(
      try warnings("_ = (+ *ab - *{a x b y})") == [
        "1:18: Nothing in the script produces \"x\", so this can never match.",
        "1:22: Nothing in the script produces \"y\", so this can never match.",
      ])
  }

  @Test func inARuleSet() throws {
    #expect(
      try warnings("@x = (- *q*)\n_ = (+ a @x)") == [
        "1:10: Nothing in the script produces \"q\", so this can never match."
      ])
  }

  @Test(arguments: [
    "_ = (+ *ab > *a=h - *h*)",  // a replacement
    "_ = (+ *ab > *{a b}={h c} - *h*)",  // a class in a replacement
    "_ = (+ *ab - *b{a b}{}*)",  // a repeat
    "_ = (+ a - _)",  // the empty word
    "_ = (+ a%- - *%-)",  // an escape
    "_ = (+ a - *h)\nb = h",  // an unused production
    "_ = (+ e\u{301} - *\u{E9})",  // a precomposed character matches a decomposed one
    "_ = (+ \u{1100} \u{1161} - *\u{AC00}*)",  // Hangul jamo join into a syllable
    "_ = (+ क् ष - *क्ष*)",  // a Devanagari conjunct forms across items
    "_ = (+ \u{1100} \u{1161} \u{11A8} - *\u{AC01}*)",  // two pieces join onto a jamo
  ])
  func notReported(source: String) throws {
    let warnings = try warnings(source).filter { !$0.contains("Nothing refers") }
    #expect(warnings == [])
  }
}

struct JoiningTests {
  @Test func precomposedPatternCannotMatchItsBaseLetter() throws {
    // "é" is produced, but "e" never is, and a letter can't be split from its accent.
    #expect(
      try warnings("_ = (+ \u{E9} - *e*)") == [
        "1:13: Nothing in the script produces \"e\", so this can never match."
      ])
  }

  @Test func joiningOnlyHappensAtTheStartOfAPiece() throws {
    // The accent follows "x" within the literal, so it can't join onto "a".
    #expect(
      try warnings("_ = (+ a x\u{301} - *\u{E1}*)") == [
        "1:15: Nothing in the script produces \"\u{E1}\", so this can never match."
      ])
  }
}
