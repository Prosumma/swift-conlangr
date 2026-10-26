import Parsimonious

typealias SourceParser<Output> = Parser<String, Output>

/// The Conlangr grammar.
///
/// Every construct commits once its first character has matched, so a syntax error is
/// reported where it happened, not as a failed alternative back at the start of the line.
/// The grammar is recursive through `expression`, so these must stay `static let`s.
enum Grammar {
  /// Characters that can't appear in text without a `%` in front of them. Some aren't used
  /// yet and are set aside for the future: `[ ] ! ' " : # <`.
  static let reserved = Set("(){}[]+?&-$@!^*='\":;#0123456789<>")

  /// Whether `c` is entirely whitespace. Matches `Parsers.whitespace`, so a space followed by
  /// a combining mark is text, not whitespace.
  static func isSpace(_ c: Character) -> Bool {
    c.unicodeScalars.allSatisfy(\.properties.isWhitespace)
  }

  // MARK: Whitespace and comments

  static let comment = (char(";") *> char(not: \.isNewline)*).map { _ in () }
  static let gap = (Parsers<String>.whitespace.map { _ in () } <|> comment)*.map { _ in () }

  // MARK: Text

  static let plain: SourceParser<Character> = satisfy { c in
    !isSpace(c) && c != "%" && !reserved.contains(c)
  }
  static let visible: SourceParser<Character> = satisfy { c in !isSpace(c) }
  static let escape =
    char("%")
    *> visible.expecting("Expected a character after \"%\". Write \"%%\" for a percent sign.")
    .commit()

  /// A literal, a name, a pattern or a replacement. `_` on its own is the empty string.
  static let text = (escape <|> plain)+.captured().map { characters, slice in
    Located(slice == "_" ? "" : String(characters), slice)
  }

  // MARK: Quantifiers

  static let digits = char(anyOf: "0123456789")+.toString()
  static let variableName =
    char("$") *> text.expecting("Expected a variable name after \"$\".").commit()
  static let quantifier =
    (digits.map { Quantifier.number($0) } <|> variableName.map { Quantifier.variable($0.value) })
    .captured()
    .map { Located($0, $1) }

  // MARK: Productions

  static let literal = text.map { Expression.literal($0.value) }
  static let reference =
    (char("&") *> text.expecting("Expected a production name after \"&\".").commit())
    .map { Expression.reference($0.value) }
  static let copy =
    (char("^") *> text.expecting("Expected a production name after \"^\".").commit())
    .map { Expression.copy($0.value) }
  static let spreadElement =
    escape.map { String($0) } <|> plain.map { $0 == "_" ? "" : String($0) }
  static let spread =
    (char("*") *> spreadElement+.expecting("Expected characters after \"*\".").commit())
    .map { Expression.spread($0) }

  static let item =
    tuple(
      quantifier <* gap,
      expression.expecting("Expected a production after the quantifier.").commit()
    ).map { Item(quantifier: $0, expression: $1) }
    <|> expression.map { Item(quantifier: nil, expression: $0) }
  static let items = (item.expecting("Expected a production.") <* gap)+

  static let close = char(")")
  static let misplacedRewrite: SourceParser<Character> =
    char(anyOf: "->@").peek()
    *> fail("Skips (-), substitutions (>) and rule sets (@) can only appear in (+ ...).")
    .commit()
  static let select =
    (char("?") *> gap *> items.map { Expression.select($0) }
    <* (close <|> misplacedRewrite).expecting("Expected \")\"."))
    .commit1()

  /// `{a b c}`, a class, or `{}`, which repeats or copies another class.
  static let choice =
    (char("{") *> gap *> (text <* gap)* <* char("}").expecting("Expected \"}\"."))
    .map { $0.isEmpty ? Part.same : Part.choice($0) }
    .commit1()
  /// Text and classes, with nothing between them.
  static let parts = (text.map { Part.text($0.value) } <|> choice).captured().map {
    Located($0, $1)
  }+
  static let pattern =
    tuple(char("*").optional(), parts.expecting("Expected pattern text."), char("*").optional())
    .map { leading, parts, trailing in
      let position: Pattern.Position =
        switch (leading.isEmpty, trailing.isEmpty) {
        case (true, true): .whole
        case (true, false): .prefix
        case (false, true): .suffix
        case (false, false): .anywhere
        }
      return PatternSyntax(position: position, parts: parts)
    }
    .commit1()
  /// Requires whitespace after a pattern or replacement, so that `*a*b` and `*a*{b c}` are
  /// errors rather than two patterns.
  static let separated =
    (char("*") <|> char("%") <|> char("{") <|> char("@") <|> plain).not()
    .expecting("Patterns must be separated by whitespace.")
    .commit()
  static let ruleSetName =
    char("@") *> text.expecting("Expected a rule set name after \"@\".").commit()
  /// `@name`, which can appear anywhere a skip or substitution can.
  static let ruleSet =
    ruleSetName.captured().map { Located(RewriteStep.ruleSet($0.value), $1) } <* separated
  static let rejection =
    pattern.captured().map { Located(RewriteStep.reject($0), $1) } <* separated <|> ruleSet
  static let rejections =
    char("-") *> gap
    *> (rejection <* gap)+.expecting("Expected a pattern after \"-\".").commit()
  static let substitution =
    tuple(
      pattern <* gap <* char("=") <* gap,
      parts.expecting("Expected a replacement after \"=\". Write \"_\" to delete the match.")
        <* separated
    )
    .captured()
    .map { parts, slice in
      Located(RewriteStep.substitute(parts.0, with: parts.1), slice)
    }
    .commit1()
  static let substitutions =
    char(">") *> gap
    *> ((substitution <|> ruleSet) <* gap)+.expecting("Expected a substitution after \">\".")
    .commit()
  static let steps = rejections <|> substitutions <|> (ruleSet <* gap).map { [$0] }
  static let rewrites = flatten(steps*)
  static let sequence =
    (char("+") *> gap *> tuple(items, rewrites).map { Expression.sequence($0, $1) } <* close)
    .commit1()

  static let group =
    (char("(") *> gap *> (select <|> sequence).expecting("Expected \"?\" or \"+\" after \"(\"."))
    .commit1()

  static let located = (literal <|> reference <|> copy <|> spread <|> group).captured().map {
    Located($0, $1)
  }
  static let expression: SourceParser<Located<Expression>> = Parser {
    input throws(ParseError<String>) in
    try located.parse(input)
  }

  // MARK: Definitions

  static let variableDefinition =
    tuple(
      variableName.captured().map { Located($0.value, $1) } <* gap <* char("=") <* gap,
      digits.captured().map { Located($0, $1) }.expecting("Expected a number after \"=\".")
    )
    .map { Definition.variable(name: $0, value: $1) }
    .commit1()

  /// A quantifier only means something inside `(? ...)` or `(+ ...)`.
  static let strayQuantifier: SourceParser<Located<Expression>> =
    quantifier.peek()
    *> fail("A weight or repeat count can only appear inside (? ...) or (+ ...).").commit()
  static let productionDefinition = text.captured().flatMap { name, written in
    (gap
      *> char("=").expecting("Expected \"=\" after \"\(written)\".")
      *> gap
      *> (expression <|> strayQuantifier).expecting("Expected a production after \"=\"."))
      .map { Definition.production(name: name, expression: $0) }
  }
  .commit1()

  /// `@name = (...)`. A rule set's steps need parentheses around them, since without them,
  /// a definition on the next line would read as more substitutions.
  static let ruleSetDefinition =
    tuple(
      ruleSetName.captured().map { Located($0.value, $1) } <* gap
        <* char("=").expecting("Expected \"=\" after the rule set's name.") <* gap,
      (char("(") *> gap
        *> flatten(steps+).expecting(
          "Expected skips (-), substitutions (>) or rule sets (@) after \"(\".")
        <* close.expecting("Expected \")\"."))
        .expecting("Expected \"(\" after \"=\". A rule set's steps go in parentheses.")
    )
    .map { Definition.ruleSet(name: $0, steps: $1) }
    .commit1()

  static let definition = variableDefinition <|> ruleSetDefinition <|> productionDefinition
  static let script =
    gap *> (definition <* gap)*
    <* Parsers<String>.end.expecting(
      "Expected a definition, such as \"name = ...\" or \"$name = 1\".")
}
