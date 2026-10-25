# CLAUDE.md

Conlangr is a Swift package that parses and evaluates a small DSL for generating random conlang words. `README.md` is the user-facing language reference. Read it first for syntax and semantics, because this file only covers what matters when changing the code.

## Commands

```sh
swift build
swift test                      # Swift Testing; the example tests print sample words
swift test --filter testQuenya
```

The tests mostly print output instead of asserting it, because generation is random. `testEvaluationCount` is the only test with a real expectation. To check a semantic question empirically, add a throwaway `@Test` that samples `generator.eval()` a few thousand times and tallies the results, then delete it.

## Layout

| File | Contents |
|---|---|
| `Sources/Conlangr/Conlang+Parse.swift` | Parsimonious grammar, `ParseProduction`, `Quantifier`, `Script`, `ScriptError`, `parse(_:)` |
| `Sources/Conlangr/Conlangr+Normalize.swift` | `ParseProduction` → `Production`; `Script.normalize(with:)` → `Generator` |
| `Sources/Conlangr/Conlangr.swift` | Public evaluated model: `Production`, `QuantifiedProduction`, `Rewrite`, `Skip`, `Substitution`, `MatchMode`, `Generator` |
| `Sources/Conlangr/Conlangr+Eval.swift` | `EvaluationContext`, `EvaluationError`, the `eval` methods |
| `Sources/Conlangr/Conlang+Token.swift` | `Token`, `tokenize(_:)` for syntax highlighting |

The file prefixes are inconsistent (`Conlang+` and `Conlangr+`). Match whichever prefix the neighboring file uses, and don't rename files without being asked.

## Pipeline and types

`String` →`parse`→ `Script` →`normalize(with:)`→ `Generator` →`eval()`→ `String`

- **`ParseProduction` (internal)** is the raw parse tree. Its quantifiers can still be `Quantifier.variable(name)`, and spreads (`*abc`) are still their own case.
- **`Production` (public)** is the normalized form. All quantifiers are resolved to `UInt8`, and a spread becomes a weight-1 select. An undefined variable resolves to 1, silently.
- **Select representation.** `.select([UInt8], [UInt8: Set<Production>])` encodes weighted choice. The array holds each weight `w` repeated `w` times for every alternative at that weight. Evaluation picks a weight uniformly from the array, then picks uniformly from that weight's set. Because the alternatives are in a `Set`, duplicates collapse: `*ptkk` behaves like `*ptk`, and `(? a a b)` gives a and b 50% each. This is current behavior, not necessarily intended.
- **The main production is named `""`.** In source it's written `_`, because `unescape("_")` returns `""`. `normalize` throws `ScriptError.noMain` if it's missing. `Generator`'s initializer is internal, so every `Generator` is guaranteed a main production, which is why `Generator.eval` can force-unwrap `productions[""]!`. Keep it that way.
- **Quantifier meaning depends on context.** In a select, the number is a weight. In a concat, it's a maximum repeat count, sampled uniformly from `1...n`.

The user prefers type-driven design (see `../../CLAUDE.md`): put invariants into types where Swift allows it, and make invalid states unrepresentable.

## Parser notes (Parsimonious 2.x)

- The package pins **Parsimonious 2.6.x**. The sibling checkout `../parsimonious` is **Parsimonious 3**, a Swift 6 rewrite with a different API (typed throws, method-style combinators). The user plans to upgrade to 3 eventually, but until that is the task, don't use the v3 APIs or copy examples from that checkout.
- The parsers are global `let`s that refer to each other recursively (`production` ↔ `select`/`concat` ↔ `quantifiedProduction`). Keep that mutual recursion working through any port.
- `wspd(_:)` wraps a parser with optional whitespace or `;` comments on both sides, and that's how whitespace-insensitivity works throughout. A comment ends at a newline or at EOF.
- `reserved` lists the characters that can't appear unescaped in a literal. Digits are on that list, which is what makes quantifiers unambiguous. Several reserved characters (`{}[]@!^'":#<`) aren't used yet. If you add syntax, take characters from that set, and update both `reserved` and the tokenizer's `tokenOp`.
- Errors thrown inside a `>>>` transform, such as `ScriptError.stringTooLong` or `ScriptError.invalidNumericQuantifier`, **surface to callers as a `ParseError<String>` nomatch**, not as the `ScriptError`. `ScriptError.danglingEscapeCharacter` is unreachable in practice, because `escapechar` requires a character after `%`. The only `ScriptError` callers actually see is `.noMain`.
- Variable assignments (`$x = n`) must all come before production assignments, and at least one production is required. A duplicate production name means the last one wins (`toDictionary`).
- A production on the right side of an assignment can't be quantified (`_ = 3 a` is a parse error). Quantifiers appear only inside `(? …)` and `(+ …)`.

## Evaluation notes

- `EvaluationContext` counts evaluations: every `.ref`, every `.select`, and every concat attempt, including retries after a skip. It throws `evaluationCountExceeded` at `UInt16.max`. Each call to `Generator.eval()` gets a fresh context.
- Rewrite blocks in a concat run in source order. A matching skip `continue`s the `RETRY` loop, which regenerates the whole concat. Substitutions run sequentially, each on the output of the one before.
- `refNotFound` is detected lazily, when the reference is evaluated. Nothing validates references at normalize time.
- **The length limits disagree by one.** `Production.maximumStringLength` is 64, and the parser and the `.literal` eval check use `> 64`. But `assertLength` uses `count < 64`, so any string that passes through `assertLength` (refs, selects, concats) must be 63 characters or fewer. A 64-character literal works as the main production directly but fails behind a `&ref`.
- **There are known crashes:** a concat quantity of 0 (`UInt8.random(in: 1...0)`) and a select whose weights are all 0 (`randomElement()!` on an empty array). Both trap instead of throwing.

## Tokenizer

`tokenize` is a lexical pass for editors. It doesn't validate. Its token kinds are literal, parens, op (`=+?-&>*$`), number (**one token per digit**), comment, and error (any other run of non-whitespace, for example unused reserved characters). A literal token's `value` is the *unescaped* text (`_` → `""`, `%(` → `(`), and its `range` covers the source text.

## Style

- 2-space indentation, matching the existing files.
- Closures passed to Parsimonious combinators are often marked `@Sendable` to satisfy Swift 6 strict concurrency. Follow suit.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. They `@testable import Conlangr` so they can call internal parsers directly, as in `parse(grammar, with: script)`.
