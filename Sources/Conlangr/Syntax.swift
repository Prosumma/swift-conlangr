/// The syntax tree that `Grammar` produces and `Compiler` consumes.
///
/// It records what was written, not what it means: numbers are kept as digits, and names
/// aren't resolved. Everything a diagnostic might point at carries its source range.

struct Located<Value: Sendable>: Sendable {
  let value: Value
  let range: Range<String.Index>

  init(_ value: Value, _ range: Range<String.Index>) {
    self.value = value
    self.range = range
  }

  init(_ value: Value, _ slice: Substring) {
    self.init(value, slice.range)
  }
}

enum Definition: Sendable {
  case variable(name: Located<String>, value: Located<String>)
  case production(name: Located<String>, expression: Located<Expression>)
}

indirect enum Expression: Sendable {
  case literal(String)
  case reference(String)
  /// `*abc`. Each element is a single character, or the empty string for `_`.
  case spread([String])
  case select([Item])
  case sequence([Item], [Located<RewriteStep>])
}

struct Item: Sendable {
  let quantifier: Located<Quantifier>?
  let expression: Located<Expression>
}

enum Quantifier: Sendable {
  /// The digits as written. They may be out of range, which the compiler reports.
  case number(String)
  case variable(String)
}

/// The steps of a sequence's skips and substitutions, flattened in source order.
/// `- a b > c=d` is the same as `- a - b > c=d`.
enum RewriteStep: Sendable {
  case reject(Pattern)
  case substitute(Pattern, with: String)
}

struct Pattern: Sendable, Hashable {
  enum Position: Sendable, Hashable {
    /// `abc`: the whole word.
    case whole
    /// `abc*`
    case prefix
    /// `*abc`
    case suffix
    /// `*abc*`
    case anywhere
  }

  let position: Position
  let text: String

  func matches(_ word: String) -> Bool {
    switch position {
    case .whole: word == text
    case .prefix: word.hasPrefix(text)
    case .suffix: word.hasSuffix(text)
    case .anywhere: word.contains(text)
    }
  }

  /// The word with the match replaced, or `nil` if the pattern doesn't match.
  func substitute(_ replacement: String, in word: String) -> String? {
    guard matches(word) else {
      return nil
    }
    return switch position {
    case .whole: replacement
    case .prefix: replacement + word.dropFirst(text.count)
    case .suffix: word.dropLast(text.count) + replacement
    case .anywhere: word.replacing(text, with: replacement)
    }
  }
}

/// How a production's name appears in messages. The main production's name is empty,
/// because `_` means the empty string.
func display(_ name: String) -> String {
  name.isEmpty ? "_" : name
}
