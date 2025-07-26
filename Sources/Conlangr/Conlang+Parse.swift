import Parsimonious

enum Quantifier: Sendable {
  case numeric(UInt8)
  case variable(String)
}

enum ParseProduction: Sendable {
  case literal(String)
  case ref(String)
  case spread([String])
  case select([(Quantifier, ParseProduction)])
  case concat([(Quantifier, ParseProduction)], [Rewrite])
}

struct Script: Sendable {
  let variables: [String: UInt8]
  let productions: [String: ParseProduction]
}

enum ScriptError: Error {
  case invalidNumericQuantifier(String)
  case stringTooLong(String)
  case danglingEscapeCharacter 
  case noMain
}

let comment: Parser<String, String> = char(";") *> char(not(\Character.isNewline))* <* (void(.newline) <|> eof())

func wspd<Output>(_ parser: Parser<String, Output>) -> Parser<String, Output> {
  delimit(parser, by: (.whitespace <|> comment)*)
}

let reserved = "({[+?&-$@!^*='\":;#0123456789<>]})"

@Sendable
func is_reserved(_ c: Character) -> Bool {
  reserved.contains(c)
}

let escapechar: Parser<String, String> = char("%") + char(not(^\Character.isWhitespace))
let unescapechar: Parser<String, String> = char(not(^\Character.isWhitespace || is_reserved))
let escaped = (escapechar <|> unescapechar)+.joined()

/**
 Unescapes an escaped string by resolving `%`-escapes.

 This happily accepts characters that are invalid in an
 escaped string, such as reserved characters and whitespace.
 This is because the `escaped` parser handles that aspect
 of things before the string ever gets to `unescape`.

 See the `unescaped` parser, which is what you want to use
 for ordinary strings most of the time.
 */
@Sendable
func unescape(_ input: String) throws -> String {
  if input == "_" {
    return ""
  } else {
    var output = ""
    var escaping = false
    for c in input {
      if !escaping && c == "%" {
        escaping = true
      } else {
        escaping = false
        output.append(c)
      }
    }
    if escaping {
      throw ScriptError.danglingEscapeCharacter
    }
    if output.count > Production.maximumStringLength {
      throw ScriptError.stringTooLong(output)
    }
    return output
  }
}

let unescaped = escaped >>> unescape

@Sendable
func spread(_ input: String) -> [String] {
  var output: [String] = []
  var escaping = false
  for c in input {
    if !escaping && c == "%" {
      escaping = true
    } else if !escaping && c == "_" {
      output.append("")
    } else {
      escaping = false
      output.append("\(c)")
    }
  }
  return output
}

@Sendable
func assign<N, V>(_ name: Parser<String, N>, to value: Parser<String, V>) -> Parser<String, (N, V)> {
  tuple(name <* wspd(char("=")), value)
}

@Sendable
func toDictionary<Key, Value>(_ input: [(Key, Value)]) -> [Key: Value] {
  var dictionary: [Key: Value] = [:]
  for (key, value) in input {
    dictionary[key] = value
  }
  return dictionary
}

let numeric: Parser<String, UInt8> = char(any: "0123456789")* >>> { @Sendable input in
  guard let quantifier = UInt8(input) else {
    throw ScriptError.invalidNumericQuantifier(input)
  }
  return quantifier 
}
let numericQuantifier = numeric >>> { Quantifier.numeric($0) }
let variable = wspd(char("$")) *> unescaped
let variableQuantifier = variable >>> { Quantifier.variable($0) }
let quantifier = numericQuantifier <|> variableQuantifier

let matchMode: Parser<String, Bool> = (char("*") <|> just("")) >>> { input in
  input == "*"
}
let wildcard: Parser<String, (MatchMode, String)> = tuple(matchMode, unescaped, matchMode) >>> { @Sendable leftMode, input, rightMode in
  let mode: MatchMode = switch (leftMode, rightMode) {
  case (true, true): .all
  case (true, false): .atEnd
  case (false, true): .atStart
  case (false, false): .exact
  }
  return (mode, input)
}
let skip = wildcard >>> { Skip.init(mode: $0.0, model: $0.1) }
let substitution=assign(wildcard, to: unescaped) >>> { input in
  Substitution(mode: input.0.0, from: input.0.1, to: input.1)
}
let skips = wspd(char("-")) *> wspd(skip)* >>> { Set.init($0) } >>> { Rewrite.skips($0) }
let substitutions = wspd(char(">")) *> wspd(substitution)* >>> { Rewrite.substitutions($0) }
let rewrites = (skips <|> substitutions)*

let literal = unescaped >>> { ParseProduction.literal($0) }
let ref = wspd(char("&")) *> unescaped >>> { ParseProduction.ref($0) }
let spreadSelect = wspd(char("*")) *> escaped >>> spread >>> { ParseProduction.spread($0) }
let production: Parser<String, ParseProduction> = literal <|> ref <|> spreadSelect <|> select <|> concat
let unquantifiedProduction = production >>> { (Quantifier.numeric(1), $0) }
let quantifiedProduction = tuple(wspd(quantifier), production) <|> unquantifiedProduction
let select = parenthesized(wspd(char("?")) *> wspd(quantifiedProduction)+) >>> { ParseProduction.select($0) }
let concat = parenthesized(wspd(char("+")) *> tuple(wspd(quantifiedProduction)+, rewrites)) >>> { ParseProduction.concat($0.0, $0.1) }

let variableAssignments = wspd(assign(variable, to: numeric))* >>> toDictionary
let productionAssignments = wspd(assign(unescaped, to: production))+ >>> toDictionary
let script = wspd(tuple(wspd(variableAssignments), wspd(productionAssignments))) >>> { Script.init(variables: $0.0, productions: $0.1) } <* eof()
