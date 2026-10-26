import Conlangr
import Foundation
import Testing

struct SyntaxErrorTests {
  @Test(arguments: [
    // Definitions
    (")", "1:1: Expected a definition, such as \"name = ...\" or \"$name = 1\"."),
    ("x", "1:2: Expected \"=\" after \"x\"."),
    ("x = a b\ny = c", "2:1: Expected \"=\" after \"b\"."),
    ("%3x a", "1:5: Expected \"=\" after \"%3x\"."),
    ("_ =", "1:4: Expected a production after \"=\"."),
    ("_ = )", "1:5: Expected a production after \"=\"."),
    ("_ = 3 a", "1:5: A weight or repeat count can only appear inside (? ...) or (+ ...)."),
    ("_ = $n a", "1:5: A weight or repeat count can only appear inside (? ...) or (+ ...)."),
    ("$ = 1", "1:2: Expected a variable name after \"$\"."),
    ("$n 1", "1:4: Expected \"=\"."),
    ("$n = x", "1:6: Expected a number after \"=\"."),
    ("$_ = 1", "1:2: \"_\" can't be the name of a variable, since it means the empty string."),
    (
      "_ = (+ $_ a)", "1:9: \"_\" can't be the name of a variable, since it means the empty string."
    ),
    ("_ = $_ a", "1:6: \"_\" can't be the name of a variable, since it means the empty string."),
    (
      "@_ = (> a=b)", "1:2: \"_\" can't be the name of a rule set, since it means the empty string."
    ),
    (
      "_ = (+ a @_)",
      "1:11: \"_\" can't be the name of a rule set, since it means the empty string."
    ),
    (
      "_ = (+ a > b=c @_)",
      "1:17: \"_\" can't be the name of a rule set, since it means the empty string."
    ),
    // Text
    ("_ = a%", "1:7: Expected a character after \"%\". Write \"%%\" for a percent sign."),
    ("_ = a% b", "1:7: Expected a character after \"%\". Write \"%%\" for a percent sign."),
    ("_ = &", "1:6: Expected a production name after \"&\"."),
    ("_ = & x", "1:6: Expected a production name after \"&\"."),
    ("_ = *", "1:6: Expected characters after \"*\"."),
    ("_ = a{", "1:6: Expected a definition, such as \"name = ...\" or \"$name = 1\"."),
    // Groups
    ("_ = (", "1:6: Expected \"?\" or \"+\" after \"(\"."),
    ("_ = (a)", "1:6: Expected \"?\" or \"+\" after \"(\"."),
    ("_ = (?)", "1:7: Expected a production."),
    ("_ = (? a", "1:9: Expected \")\"."),
    ("_ = (? a\n  b", "2:4: Expected \")\"."),
    ("_ = (? a = b)", "1:10: Expected \")\"."),
    ("_ = (? 3)", "1:9: Expected a production after the quantifier."),
    ("_ = (? a - )", "1:12: Expected a pattern after \"-\"."),
    ("_ = (? a > b=c d)", "1:17: Expected \"=\"."),
    ("_ = (? a - b c", "1:15: Expected \")\"."),
    ("_ = (+ a @)", "1:11: Expected a rule set name after \"@\"."),
    ("_ = (+ a ^)", "1:11: Expected a production name after \"^\"."),
    ("_ = (+ a - *a*@x)", "1:15: Patterns must be separated by whitespace."),
    ("_ = (+ a - @x*a*)", "1:14: Patterns must be separated by whitespace."),
    ("_ = (+ a - @x{a b})", "1:14: Patterns must be separated by whitespace."),
    ("_ = (+ a > a=b @x*b*=c)", "1:18: Patterns must be separated by whitespace."),
    ("_ = (+ a @x*b*)", "1:12: Patterns must be separated by whitespace."),
    ("@x = (@y*a*)\n_ = a", "1:9: Patterns must be separated by whitespace."),
    ("@x (> a=b)", "1:4: Expected \"=\" after the rule set's name."),
    ("@x = > a=b", "1:6: Expected \"(\" after \"=\". A rule set's steps go in parentheses."),
    ("@x = ()", "1:7: Expected skips (-), substitutions (>) or rule sets (@) after \"(\"."),
    ("@x = (> a=b", "1:12: Expected \")\"."),
    ("@x = (> a=b &y)", "1:13: Expected \")\"."),
    ("_ = (+ a (? b c)", "1:17: Expected \")\"."),
    ("_ = (+ a (? b c", "1:16: Expected \")\"."),
    // Rewrites
    ("_ = (+ a -)", "1:11: Expected a pattern after \"-\"."),
    ("_ = (+ a - *)", "1:13: Expected pattern text."),
    ("_ = (+ a >)", "1:11: Expected a substitution after \">\"."),
    ("_ = (+ a > a)", "1:13: Expected \"=\"."),
    (
      "_ = (+ a > a=)", "1:14: Expected a replacement after \"=\". Write \"_\" to delete the match."
    ),
    ("_ = (+ a - b &c)", "1:14: Expected \")\"."),
    ("_ = (+ a - *{a b*)", "1:17: Expected \"}\"."),
    ("_ = (+ a - *{a {b}}*)", "1:16: Expected \"}\"."),
    ("_ = (+ *ab *ab - *a*b)", "1:21: Patterns must be separated by whitespace."),
    ("_ = (+ a > a=b*c=d)", "1:15: Patterns must be separated by whitespace."),
    ("_ = (+ ab - *a*{b c})", "1:16: Patterns must be separated by whitespace."),
  ])
  func syntaxError(source: String, message: String) {
    let diagnostics = diagnostics(source)
    #expect(diagnostics.map(\.description) == [message])
    #expect(diagnostics.allSatisfy { if case .syntax = $0.problem { true } else { false } })
  }

  @Test func maximumNesting() throws {
    let depth = Script.maximumNesting
    let nested = String(repeating: "(+ ", count: depth) + "a" + String(repeating: ")", count: depth)
    #expect(try word("_ = \(nested)") == "a")
    let tooDeep = "_ = (+ \(nested))"
    let column = 5 + 3 * depth
    #expect(
      messages(tooDeep) == [
        "1:\(column): Groups can only be nested 12 deep. Give some of the inner groups their own names, and refer to them with \"&\"."
      ])
  }

  @Test func nestingIsCountedPerDefinition() throws {
    let depth = Script.maximumNesting
    let nested = String(repeating: "(+ ", count: depth) + "a" + String(repeating: ")", count: depth)
    #expect(try word("x = \(nested)\n_ = \(nested)") == "a")
  }

  @Test func referencesDoNotNest() throws {
    // A chain of references far deeper than groups may nest.
    let chain = (0..<50).map { "p\(letters($0)) = (+ &p\(letters($0 + 1)))" }
    let source = (["_ = &pa"] + chain + ["p\(letters(50)) = end"]).joined(separator: "\n")
    #expect(try word(source) == "end")
  }

  @Test func absurdNestingIsRejectedWithoutOverflowingTheStack() async throws {
    let depth = 10_000
    let source =
      "_ = " + String(repeating: "(+ ", count: depth) + "a" + String(repeating: ")", count: depth)
    let problems = await withCheckedContinuation { continuation in
      let thread = Thread {
        continuation.resume(returning: diagnostics(source).map(\.problem))
      }
      thread.stackSize = 256 * 1024
      thread.start()
    }
    #expect(problems == [.nestedTooDeeply])
  }

  @Test func maximumNestingParsesOnASmallStack() async throws {
    // A 512 KB stack is what secondary threads get. Parsing is recursive, so this is the
    // margin `Script.maximumNesting` is meant to leave.
    let depth = Script.maximumNesting
    let source =
      "_ = " + String(repeating: "(+ ", count: depth) + "a" + String(repeating: ")", count: depth)
    let problems = await withCheckedContinuation { continuation in
      let thread = Thread {
        continuation.resume(returning: diagnostics(source).map(\.problem))
      }
      thread.stackSize = 512 * 1024
      thread.start()
    }
    #expect(problems == [])
  }

  @Test func longRuleSetChainCompilesOnASmallStack() async throws {
    // A chain is flat, so it isn't limited by nesting, only by the length of the script.
    let length = 2_000
    let chain = (0..<length).map { "@\(letters($0)) = (@\(letters($0 + 1)))" }
    let source =
      (chain + ["@\(letters(length)) = (> *a*=b)", "_ = (+ a @\(letters(0)))"]).joined(
        separator: "\n")
    let problems = await withCheckedContinuation { continuation in
      let thread = Thread {
        continuation.resume(returning: diagnostics(source).map(\.problem))
      }
      thread.stackSize = 512 * 1024
      thread.start()
    }
    #expect(problems == [])
  }

  @Test func locationRange() throws {
    let source = "_ = (? a = b)"
    let location = try #require(diagnostics(source).first?.location)
    #expect(source[location.range] == "=")
  }

  @Test func locationRangeAtEnd() throws {
    let source = "_ = (? a"
    let location = try #require(diagnostics(source).first?.location)
    #expect(location.range == source.endIndex..<source.endIndex)
  }
}

struct CompileErrorTests {
  @Test func emptyScript() {
    #expect(
      messages("") == [
        "There is no main production. Define one named \"_\", as in \"_ = ...\"."
      ])
    #expect(
      messages("; Nothing but a comment.") == [
        "There is no main production. Define one named \"_\", as in \"_ = ...\"."
      ])
  }

  @Test func missingMain() {
    #expect(
      messages("x = a") == [
        "There is no main production. Define one named \"_\", as in \"_ = ...\"."
      ])
  }

  @Test func undefinedProduction() {
    #expect(messages("_ = (+ &a &b)\na = x") == ["1:11: There is no production named \"b\"."])
  }

  @Test func undefinedProductionOnARarelyChosenBranch() {
    #expect(messages("_ = (? 255 a 1 &typo)") == ["1:16: There is no production named \"typo\"."])
  }

  @Test func undefinedVariable() {
    #expect(messages("_ = (? $w a b)") == ["1:8: There is no variable named \"$w\"."])
  }

  @Test func unknownOverride() {
    #expect(
      messages("$w = 1\n_ = (? $w a b)", overrides: ["v": 2]) == [
        "An override was given for \"$v\", but the script doesn't declare it."
      ])
  }

  @Test func nothingToCopy() {
    let message =
      "There's no \"&a\" earlier in this concat, or in a concat around it, for \"^a\" to copy."
    // Not yet produced, not an item of a concat, and not in this definition.
    #expect(messages("_ = (+ ^a &a)\na = x") == ["1:8: \(message)"])
    #expect(messages("_ = (+ (? &a x) ^a)\na = x") == ["1:17: \(message)"])
    #expect(messages("_ = (? &a ^a)\na = x") == ["1:11: \(message)"])
    #expect(messages("_ = (+ &a &b)\na = x\nb = ^a") == ["3:5: \(message)"])
    #expect(messages("_ = (+ &a (+ x) ^a)\na = x") == [])
  }

  @Test func undefinedRuleSet() {
    #expect(messages("_ = (+ a @spelling)") == ["1:10: There is no rule set named \"@spelling\"."])
  }

  @Test func duplicateRuleSet() {
    // The duplicate is still checked.
    #expect(
      messages("@x = (> a=b)\n_ = (+ a @x)\n@x = (> *_*=c)") == [
        "3:1: The rule set \"@x\" is already defined.",
        "3:9: A pattern anchored with \"*\" must have some text.",
      ])
  }

  @Test func ruleSetIncludesItself() {
    #expect(
      messages("@x = (> a=b @x)\n_ = a") == [
        "1:13: The rule set \"@x\" can't include itself, directly or through another rule set."
      ])
    #expect(
      messages("@x = (@y)\n@y = (@x)\n_ = (+ a @x)") == [
        "2:7: The rule set \"@x\" can't include itself, directly or through another rule set."
      ])
  }

  @Test func tooManyRewrites() {
    // Each rule set uses the one before twice, so the last would have 2^40 substitutions.
    let doubling = (1...40).map { "@\(letters($0)) = (@\(letters($0 - 1)) @\(letters($0 - 1)))" }
    let source = (["@a = (> *a*=b)"] + doubling + ["_ = (+ a @\(letters(40)))"]).joined(
      separator: "\n")
    // Only the rule set that first goes over is reported, at the step that takes it over.
    #expect(
      messages(source) == [
        "12:10: This makes more than 1024 skips and substitutions in one place, counting those of the rule sets used."
      ])
    let inline = "_ = (+ a > " + String(repeating: "*a*=a ", count: 1_025) + ")"
    #expect(
      messages(inline) == [
        "1:\(12 + 6 * 1_024): This makes more than 1024 skips and substitutions in one place, counting those of the rule sets used."
      ])
    let atTheLimit = "_ = (+ a > " + String(repeating: "*a*=a ", count: 1_024) + ")"
    #expect(messages(atTheLimit) == [])
  }

  @Test func problemsInARuleSetAreReportedOnce() {
    #expect(
      messages("@x = (- *_*)\n_ = (? (+ a @x) (+ b @x))") == [
        "1:9: A pattern anchored with \"*\" must have some text."
      ])
  }

  @Test func unusedRuleSetIsChecked() {
    #expect(
      messages("@x = (- *_* @y)\n_ = a") == [
        "1:9: A pattern anchored with \"*\" must have some text.",
        "1:13: There is no rule set named \"@y\".",
      ])
  }

  @Test func duplicateProduction() {
    #expect(messages("x = a\n_ = &x\nx = b") == ["3:1: The production \"x\" is already defined."])
  }

  @Test func duplicateMain() {
    #expect(messages("_ = a\n_ = b") == ["2:1: The production \"_\" is already defined."])
  }

  @Test func underscoreName() {
    #expect(
      messages("%_ = x\n_ = (+ &%_ y)") == [
        "1:1: A production can't be named \"%_\", since \"_\" names the main production."
      ])
  }

  @Test func duplicateProductionIsStillChecked() {
    #expect(
      messages("_ = a\n_ = &nope") == [
        "2:1: The production \"_\" is already defined.",
        "2:5: There is no production named \"nope\".",
      ])
  }

  @Test func duplicateVariableIsStillChecked() {
    #expect(
      messages("$n = 1\n$n = 999\n_ = a") == [
        "2:1: The variable \"$n\" is already declared.",
        "2:6: 999 is too large. Weights, repeat counts and variables go up to 255.",
      ])
  }

  @Test func invalidVariableIsStillDeclared() {
    // Only the value is reported, not every use of the variable.
    #expect(
      messages("$n = 300\n_ = (? $n a b)") == [
        "1:6: 300 is too large. Weights, repeat counts and variables go up to 255."
      ])
  }

  @Test func duplicateVariable() {
    #expect(messages("$n = 1\n$n = 2\n_ = a") == ["2:1: The variable \"$n\" is already declared."])
  }

  @Test func numberTooLarge() {
    #expect(
      messages("_ = (? 256 a b)") == [
        "1:8: 256 is too large. Weights, repeat counts and variables go up to 255."
      ])
    #expect(
      messages("$n = 1000\n_ = a") == [
        "1:6: 1000 is too large. Weights, repeat counts and variables go up to 255."
      ])
  }

  @Test func textTooLong() {
    let text = String(repeating: "a", count: Generator.maximumLength + 1)
    #expect(messages("_ = \(text)") == ["1:5: \"\(text)\" is longer than 64 characters."])
    #expect(
      messages("_ = (+ a > a=\(text))") == ["1:14: \"\(text)\" is longer than 64 characters."])
  }

  @Test func zeroRepeatCount() {
    #expect(
      messages("_ = (+ a 0 b)") == [
        "1:10: A repeat count must be at least 1. To make an item optional, select between it and \"_\"."
      ])
  }

  @Test func zeroRepeatCountFromAVariable() {
    #expect(
      messages("$n = 2\n_ = (+ a $n b)", overrides: ["n": 0]) == [
        "2:10: \"$n\" is 0, but a repeat count must be at least 1. To make an item optional, select between it and \"_\"."
      ])
  }

  @Test func noChoosableAlternative() {
    #expect(
      messages("_ = (+ x (? 0 a 0 b))") == [
        "1:10: Every alternative has a weight of 0, so there's nothing to choose."
      ])
  }

  @Test func noChoosableAlternativeFromAVariable() {
    #expect(
      messages("$w = 1\n_ = (? $w a)", overrides: ["w": 0]) == [
        "2:5: Every alternative has a weight of 0, so there's nothing to choose."
      ])
  }

  @Test(arguments: ["*_*", "_*", "*_"])
  func emptyPattern(pattern: String) {
    #expect(
      messages("_ = (+ a - \(pattern))") == [
        "1:12: A pattern anchored with \"*\" must have some text."
      ])
  }

  @Test func emptyAlternative() {
    #expect(
      messages("_ = (+ a - *{a _}*)") == [
        "1:16: A class in a pattern can't have an empty alternative."
      ])
  }

  @Test func nothingToRepeat() {
    #expect(
      messages("_ = (+ a - *{}a*)") == [
        "1:13: There's no class before this \"{}\" for it to repeat."
      ])
  }

  @Test func classCountMismatch() {
    #expect(
      messages("_ = (+ a > *a*={})") == [
        "1:16: The replacement has 1 class, but the pattern has none to pair with."
      ])
    #expect(
      messages("_ = (+ a > *a*={}{})") == [
        "1:16: The replacement has 2 classes, but the pattern has none to pair with."
      ])
    #expect(
      messages("_ = (+ a > *{a b}{c d}*={})") == [
        "1:25: The replacement has 1 class, but the pattern has 2. Use as many as the pattern, or give the pattern just one."
      ])
  }

  @Test func classSizeMismatch() {
    #expect(
      messages("_ = (+ a > *{a b c}*={x y})") == [
        "1:22: This class has 2 alternatives, but the class it pairs with in the pattern has 3."
      ])
    #expect(
      messages("_ = (+ a > *{a b}*={x})") == [
        "1:20: This class has 1 alternative, but the class it pairs with in the pattern has 2."
      ])
  }

  @Test func patternTooLong() {
    // Each part fits, but together they're too long for any word to match.
    let half = String(repeating: "a", count: 40)
    #expect(
      messages("_ = (+ a - *\(half){\(half) \(half)b}*)") == [
        "1:12: This pattern can never match: even its shortest match is longer than 64 characters."
      ])
    #expect(messages("_ = (+ a - *{\(half) b}{}*)") == [])
  }

  @Test func replacementTooLong() {
    let half = String(repeating: "a", count: 40)
    #expect(
      messages("_ = (+ a > *{a b}*=\(half){\(half) b})") == [
        "1:20: This replacement can be longer than 64 characters."
      ])
    // A copy is as long as what its class matched.
    #expect(
      messages("_ = (+ a > *{a \(half)}*={}{})") == [
        "1:\(half.count + 19): This replacement can be longer than 64 characters."
      ])
    // Classes that pair with the same class choose together, so these are never longer than 41.
    #expect(messages("_ = (+ a > *{a b}*={x \(half)}{\(half) y})") == [])
  }

  @Test func reportsTheReplacementEvenIfThePatternIsWrong() {
    let text = String(repeating: "a", count: Generator.maximumLength + 1)
    #expect(
      messages("_ = (+ a > *_*=\(text) *{a}*={b c})") == [
        "1:12: A pattern anchored with \"*\" must have some text.",
        "1:16: \"\(text)\" is longer than 64 characters.",
        "1:\(text.count + 23): This class has 2 alternatives, but the class it pairs with in the pattern has 1.",
      ])
  }

  @Test func classOnlyPatternIsNotEmpty() {
    #expect(messages("_ = (+ a - *{a b}*)") == [])
  }

  @Test func neverFinishes() {
    // `_` can't finish either, but fixing `a` would fix it, so only `a` is reported.
    #expect(
      messages("_ = (+ x &a)\na = (+ y &a)") == [
        "2:1: The production \"a\" can never finish: every way of producing it leads back to itself."
      ])
  }

  @Test func mutualRecursionNeverFinishes() {
    // `_` can't finish either, but only because of the cycle, so it isn't reported.
    #expect(
      messages("_ = (? &a &b)\na = &b\nb = (+ x &a)") == [
        "2:1: The production \"a\" can never finish: every way of producing it leads back to itself.",
        "3:1: The production \"b\" can never finish: every way of producing it leads back to itself.",
      ])
  }

  @Test func recursionWithAWayOutFinishes() {
    #expect(messages("_ = (? x (+ y &_))") == [])
  }

  @Test func aZeroWeightWayOutDoesNotCount() {
    #expect(
      messages("_ = (? 0 x (+ y &_))") == [
        "1:1: The production \"_\" can never finish: every way of producing it leads back to itself."
      ])
  }

  @Test func everyProblemIsReportedInSourceOrder() {
    let source = """
      _ = (+ &c (? 300 a) (? $v b))
      x = (+ a 0 b)
      x = y
      """
    #expect(
      messages(source) == [
        "1:8: There is no production named \"c\".",
        "1:14: 300 is too large. Weights, repeat counts and variables go up to 255.",
        "1:24: There is no variable named \"$v\".",
        "2:10: A repeat count must be at least 1. To make an item optional, select between it and \"_\".",
        "3:1: The production \"x\" is already defined.",
      ])
  }

  @Test func errorDescriptionListsEveryDiagnostic() {
    #expect(throws: ScriptError.self) { try Generator("_ = (+ &a &b)") }
    do {
      _ = try Generator("_ = (+ &a &b)")
    } catch {
      #expect(
        error.description == """
          1:8: There is no production named "a".
          1:11: There is no production named "b".
          """)
    }
  }
}

struct GenerationErrorTests {
  @Test func tooManySteps() throws {
    let generator = try Generator("_ = (+ k *ai - ka ki)")
    #expect(throws: GenerationError.tooManySteps) {
      try generator.generate()
    }
  }

  @Test func tooLong() throws {
    let text = String(repeating: "a", count: Generator.maximumLength)
    let generator = try Generator("_ = (+ \(text) b)")
    #expect(throws: GenerationError.tooLong(text + "b")) {
      try generator.generate()
    }
  }

  @Test func tooLongAfterSubstitution() throws {
    let text = String(repeating: "a", count: Generator.maximumLength)
    let generator = try Generator("_ = (+ b > b=\(text.dropLast())b *b=bb)")
    #expect(throws: GenerationError.tooLong(text.dropLast() + "bb")) {
      try generator.generate()
    }
  }

  @Test func shrinkingBackUnderTheLimitIsTooLate() throws {
    // Every intermediate result must fit, not only the final word.
    let text = String(repeating: "a", count: Generator.maximumLength)
    let generator = try Generator("_ = (+ \(text) b > *b=_)")
    #expect(throws: GenerationError.tooLong(text + "b")) {
      try generator.generate()
    }
  }

  @Test func deepRecursionDoesNotOverflowTheStack() async throws {
    // Each `&_` usually leads to two more, so this nests until it runs out of steps. Secondary
    // threads get much smaller stacks than the main thread, and it must still throw rather
    // than crash.
    let generator = try Generator("_ = (? 1 _ 255 (+ &_ &_))")
    let results = await withCheckedContinuation { continuation in
      let thread = Thread {
        var random = SplitMix64(seed: 1)
        let results = (0..<5).map { _ in
          Result { () throws(GenerationError) in try generator.generate(using: &random) }
        }
        continuation.resume(returning: results)
      }
      thread.stackSize = 256 * 1024
      thread.start()
    }
    for result in results {
      #expect(throws: GenerationError.tooManySteps) { try result.get() }
    }
  }

  @Test func deepRecursionThatFinishes() throws {
    // About 100 levels deep on average, producing nothing at each one.
    let generator = try Generator("_ = (? 1 _ 99 (+ _ &_))")
    var random = SplitMix64(seed: 1)
    for _ in 0..<100 {
      #expect(try generator.generate(using: &random) == "")
    }
  }
}

/// Names made of letters, since digits are reserved: 0 → "a", 26 → "ba".
func letters(_ n: Int) -> String {
  let letter = String(UnicodeScalar(UInt8(97 + n % 26)))
  return n < 26 ? letter : letters(n / 26) + letter
}
