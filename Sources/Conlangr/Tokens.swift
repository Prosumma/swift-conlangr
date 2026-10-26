import Parsimonious

/// A lexical token, for syntax highlighting.
public struct Token: Sendable, Hashable {
  /// For a literal, the text it means, with escapes resolved, and `""` for `_`. For a
  /// comment, the text after the `;`. Otherwise, the source text.
  public let value: String
  public let kind: Kind
  /// Where the token is in the source.
  public let range: Range<String.Index>
}

extension Token {
  public enum Kind: Sendable, Hashable {
    /// Text, including names, patterns and replacements.
    case literal
    /// `(` or `)`.
    case parens
    /// `{` or `}`, around a class in a pattern or replacement.
    case braces
    /// `=`, `+`, `?`, `-`, `&`, `>`, `*`, `$` or `@`.
    case op
    /// A run of digits.
    case number
    case comment
    /// A single character that can't start any token, such as an unused reserved character
    /// or a `%` with nothing after it.
    case error
  }
}

/// Splits `source` into tokens, for syntax highlighting.
///
/// This only looks at one token at a time, so it accepts scripts that don't parse. Whatever
/// it doesn't recognize becomes an `.error` token, one character at a time, so it never fails.
public func tokenize(_ source: String) -> [Token] {
  // Can't fail: `Lexicon.error` matches any character that isn't whitespace.
  try! parse(source, with: Lexicon.tokens)
}

enum Lexicon {
  /// Unlike `Grammar.escape`, this doesn't commit, so a `%` without a character after it
  /// becomes an error token instead of failing.
  static let escape = char("%") *> Grammar.visible

  static let literal = (escape <|> Grammar.plain)+.captured().map { characters, slice in
    Token(value: slice == "_" ? "" : String(characters), kind: .literal, range: slice.range)
  }
  static let comment = (char(";") *> char(not: \.isNewline)*).captured().map { text, slice in
    Token(value: String(text), kind: .comment, range: slice.range)
  }
  static let parens = token(char(anyOf: "()"), .parens)
  static let braces = token(char(anyOf: "{}"), .braces)
  static let op = token(char(anyOf: "=+?-&>*$@"), .op)
  static let number = token(char(anyOf: "0123456789")+, .number)
  static let error = token(Grammar.visible, .error)

  static let whitespace = Parsers<String>.whitespace*
  static let tokens =
    whitespace
    *> ((literal <|> comment <|> parens <|> braces <|> op <|> number <|> error) <* whitespace)*
    <* Parsers<String>.end

  static func token<Output>(_ parser: SourceParser<Output>, _ kind: Token.Kind) -> SourceParser<
    Token
  > {
    parser.captured().map { _, slice in
      Token(value: String(slice), kind: kind, range: slice.range)
    }
  }
}

extension Substring {
  var range: Range<String.Index> {
    startIndex..<endIndex
  }
}
