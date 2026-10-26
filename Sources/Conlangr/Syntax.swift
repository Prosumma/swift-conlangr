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
  case ruleSet(name: Located<String>, steps: [Located<RewriteStep>])
}

indirect enum Expression: Sendable {
  case literal(String)
  case reference(String)
  /// `^name`: a copy of what an earlier `&name` produced.
  case copy(String)
  /// `*abc`. Each element is a single character, or the empty string for `_`.
  case spread([String])
  case select([Item], [Located<RewriteStep>])
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

/// The steps of a group's or rule set's skips and substitutions, flattened in source order.
/// `- a b > c=d` is the same as `- a - b > c=d`.
enum RewriteStep: Sendable {
  case reject(PatternSyntax)
  case substitute(PatternSyntax, with: [Located<Part>])
  /// `@name`: the steps of a rule set.
  case ruleSet(String)
}

/// A pattern as written: where it must match, and its parts.
struct PatternSyntax: Sendable {
  let position: Pattern.Position
  let parts: [Located<Part>]
}

/// A piece of a pattern or a replacement.
enum Part: Sendable {
  case text(String)
  /// `{a b c}`: one of several alternatives.
  case choice([Located<String>])
  /// `{}`: in a pattern, the same text as the class before it matched. In a replacement, the text
  /// that its class in the pattern matched.
  case same
}

/// How a production's name appears in messages. The main production's name is empty,
/// because `_` means the empty string.
func display(_ name: String) -> String {
  name.isEmpty ? "_" : name
}
