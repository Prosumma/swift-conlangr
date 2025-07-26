import Parsimonious

public struct Token: Sendable, Equatable {
  public let value: String
  public let kind: Kind 
  public let range: Range<String.Index>
}

func toToken(_ kind: Token.Kind) -> @Sendable ((Range<String.Index>, String)) -> Token {
  { Token(value: $0.1, kind: kind, range: $0.0) }
}

public extension Token {
  enum Kind: Sendable, Equatable {
    case literal
    case parens
    case op // = + ? - & > * $
    case number 
    case comment
  }
}

let tokenLiteral = unescaped.withRange() >>> toToken(.literal)
let tokenParens: Parser<String, Token> = char(any: "()").withRange() >>> toToken(.parens)
let tokenOp: Parser<String, Token> = char(any: "=+?-&>*$").withRange() >>> toToken(.op)
let tokenNumber: Parser<String, Token> = char(any: "0123456789").withRange() >>> toToken(.number)
let tokenComment = comment.withRange() >>> toToken(.comment)
let token = whitespaced(tokenLiteral <|> tokenParens <|> tokenOp <|> tokenNumber <|> tokenComment)
