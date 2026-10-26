import Parsimonious

/// A script that couldn't be parsed or compiled.
///
/// A syntax error, or groups nested too deeply, stops parsing, so it's always the only
/// diagnostic. Compilation reports
/// every problem it finds, in source order.
public struct ScriptError: Error, Sendable, Hashable, CustomStringConvertible {
  public let diagnostics: [Diagnostic]

  public var description: String {
    diagnostics.map(\.description).joined(separator: "\n")
  }
}

/// One problem with a script, and where it is.
public struct Diagnostic: Sendable, Hashable, CustomStringConvertible {
  public let problem: Problem
  /// `nil` for problems that aren't at any one place in the source, such as a missing
  /// main production.
  public let location: SourceLocation?

  /// The problem's message, preceded by its line and column if it has a location,
  /// as in `3:7: There is no production named "vowel".`
  public var description: String {
    guard let location else {
      return problem.description
    }
    return "\(location.line):\(location.column): \(problem)"
  }
}

public struct SourceLocation: Sendable, Hashable {
  /// The range in the source that the diagnostic is about. Empty for a syntax error at the
  /// end of the source.
  public let range: Range<String.Index>
  /// The 1-based line of the start of `range`.
  public let line: Int
  /// The 1-based column of the start of `range`, counted in characters.
  public let column: Int

  init(_ range: Range<String.Index>, in source: String) {
    self.range = range
    (line, column) = Parsimonious.location(of: range.lowerBound, in: source)
  }
}

extension Diagnostic {
  public enum Problem: Sendable, Hashable, CustomStringConvertible {
    /// The script doesn't follow the grammar. The message says what was expected.
    case syntax(String)
    /// Groups are nested more than `Script.maximumNesting` deep.
    case nestedTooDeeply
    /// There's no production named `_`.
    case missingMain
    /// A production is defined more than once.
    case duplicateProduction(String)
    /// A variable is declared more than once.
    case duplicateVariable(String)
    /// `&name` refers to a production that isn't defined.
    case undefinedProduction(String)
    /// `$name` refers to a variable that isn't declared.
    case undefinedVariable(String)
    /// `Script.compile(overrides:)` was given a variable that the script doesn't declare.
    case unknownOverride(String)
    /// A weight, repeat count or variable is larger than 255.
    case numberTooLarge(String)
    /// A literal, pattern or replacement is longer than `Generator.maximumLength`.
    case textTooLong(String)
    /// A repeat count is 0. The associated value is the variable it came from, if any.
    case zeroRepeatCount(variable: String?)
    /// Every alternative in a select has a weight of 0.
    case noChoosableAlternative
    /// A pattern such as `*_*` is anchored with `*` but has no text.
    case emptyPattern
    /// A class in a pattern, such as `{a _}`, has an empty alternative.
    case emptyAlternative
    /// A `{}` in a pattern has no class before it to repeat.
    case nothingToRepeat
    /// A replacement's classes don't pair with its pattern's: there must be as many, unless the
    /// pattern has exactly one.
    case classCountMismatch(pattern: Int, replacement: Int)
    /// A class in a replacement has a different number of alternatives from the pattern's class
    /// it pairs with.
    case classSizeMismatch(expected: Int, found: Int)
    /// Even the shortest text a pattern can match is longer than `Generator.maximumLength`, so it
    /// can never match.
    case patternTooLong
    /// A replacement can produce text longer than `Generator.maximumLength`.
    case replacementTooLong
    /// A production can't produce anything, because every way of producing it leads back
    /// to itself.
    case neverFinishes(String)

    public var description: String {
      switch self {
      case .syntax(let message):
        message
      case .nestedTooDeeply:
        "Groups can only be nested \(Script.maximumNesting) deep. Give some of the inner groups their own names, and refer to them with \"&\"."
      case .missingMain:
        "There is no main production. Define one named \"_\", as in \"_ = ...\"."
      case .duplicateProduction(let name):
        "The production \"\(display(name))\" is already defined."
      case .duplicateVariable(let name):
        "The variable \"$\(name)\" is already declared."
      case .undefinedProduction(let name):
        "There is no production named \"\(display(name))\"."
      case .undefinedVariable(let name):
        "There is no variable named \"$\(name)\"."
      case .unknownOverride(let name):
        "An override was given for \"$\(name)\", but the script doesn't declare it."
      case .numberTooLarge(let digits):
        "\(digits) is too large. Weights, repeat counts and variables go up to 255."
      case .textTooLong(let text):
        "\"\(text)\" is longer than \(Generator.maximumLength) characters."
      case .zeroRepeatCount(nil):
        "A repeat count must be at least 1. To make an item optional, select between it and \"_\"."
      case .zeroRepeatCount(let variable?):
        "\"$\(variable)\" is 0, but a repeat count must be at least 1. To make an item optional, select between it and \"_\"."
      case .noChoosableAlternative:
        "Every alternative has a weight of 0, so there's nothing to choose."
      case .emptyPattern:
        "A pattern anchored with \"*\" must have some text."
      case .emptyAlternative:
        "A class in a pattern can't have an empty alternative."
      case .nothingToRepeat:
        "There's no class before this \"{}\" for it to repeat."
      case .classCountMismatch(pattern: 0, let replacement):
        "The replacement has \(counting(replacement, "class", "classes")), but the pattern has none to pair with."
      case .classCountMismatch(let pattern, let replacement):
        "The replacement has \(counting(replacement, "class", "classes")), but the pattern has \(pattern). Use as many as the pattern, or give the pattern just one."
      case .classSizeMismatch(let expected, let found):
        "This class has \(counting(found, "alternative", "alternatives")), but the class it pairs with in the pattern has \(expected)."
      case .patternTooLong:
        "This pattern can never match: even its shortest match is longer than \(Generator.maximumLength) characters."
      case .replacementTooLong:
        "This replacement can be longer than \(Generator.maximumLength) characters."
      case .neverFinishes(let name):
        "The production \"\(display(name))\" can never finish: every way of producing it leads back to itself."
      }
    }
  }
}

/// `count` followed by `singular` or `plural` to agree with it, as in "1 class" or "2 classes".
private func counting(_ count: Int, _ singular: String, _ plural: String) -> String {
  "\(count) \(count == 1 ? singular : plural)"
}

/// A failure while generating a word.
///
/// A compiled script can still fail at random, depending on which choices are made, so these
/// errors are possible however carefully a script is written. They usually point to a
/// production that refers to itself too often, or a skip that rejects too much.
public enum GenerationError: Error, Sendable, Hashable, CustomStringConvertible {
  /// Something produced text longer than `Generator.maximumLength`. The associated value is
  /// the text.
  case tooLong(String)
  /// Generation took more than `Generator.maximumSteps` steps. Usually a skip is rejecting
  /// every word, or nearly every word, or a production refers to itself so often that it
  /// rarely finishes.
  case tooManySteps

  public var description: String {
    switch self {
    case .tooLong(let text):
      "\"\(text)\" is longer than \(Generator.maximumLength) characters."
    case .tooManySteps:
      "Generation took more than \(Generator.maximumSteps) steps. Is a skip rejecting every word?"
    }
  }
}
