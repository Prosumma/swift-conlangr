# CLAUDE.md

Conlangr is a Swift package that parses, compiles, and runs a small DSL for generating random conlang words. `README.md` is the user-facing language reference. Read it first for syntax and semantics, because this file only covers what matters when changing the code.

## Status

Conlangr 1.0.0 is released, so the public API follows semantic versioning: a breaking change to it, or to the language, needs a new major version. Release tags have no `v` prefix from 1.0.0 on, matching Parsimonious; the 0.9.x tags had one.

Conlangr depends on **Parsimonious 3.1.0 or later**:

- A combinator or parser that's useful outside Conlangr belongs in Parsimonious, with tests and a README entry. One that only Conlangr needs stays here. Conlangr's 1.0 work added `fail(_:)` and `location(of:in:)` to Parsimonious, which is why 3.1.0 is the minimum.
- To develop the two together, temporarily point `Package.swift` at the sibling checkout with `.package(path: "../parsimonious")`, and use `package: "parsimonious"` in the product dependency. Switch back to the GitHub URL and a released version before committing.
- The sibling checkout in `../parsimonious` may be ahead of the released version. Don't use anything from it that isn't in a tagged release.
- Parsimonious 3 needs Swift 6.4, so Conlangr does too.

## Commands

```sh
swift build
swift test
swift test -c release           # worth running too: stack and timing behaviour differ
swift format -i -r Sources Tests   # default configuration, as in Parsimonious
```

## Layout

| File | Contents |
|---|---|
| `Sources/Conlangr/Syntax.swift` | The syntax tree (`Definition`, `Expression`, `Item`, `Quantifier`, `RewriteStep`, `PatternSyntax`, `Part`) and `Located<Value>` |
| `Sources/Conlangr/Rewrite.swift` | Compiled rewrites: `Rewrite`, `Pattern` (with its matcher) and `Replacement` |
| `Sources/Conlangr/Grammar.swift` | The Parsimonious grammar, source text → `[Definition]` |
| `Sources/Conlangr/Script.swift` | Public `Script` (parse, `compile(overrides:)`) and the internal `Compiler` |
| `Sources/Conlangr/Generator.swift` | Public `Generator`, the compiled `Node` form, and the evaluator |
| `Sources/Conlangr/Errors.swift` | Public `ScriptError`, `Diagnostic`, `Diagnostic.Problem`, `SourceLocation`, `GenerationError` |
| `Sources/Conlangr/Warnings.swift` | Public `Warning` and `Warning.Problem`, and the pass that finds them |
| `Sources/Conlangr/Tokens.swift` | Public `Token` and `tokenize(_:)`, a separate lexer for syntax highlighting |

## Pipeline

`String` →`Script(_:)`→ `Script` →`compile(overrides:)`→ `Generator` →`generate()`→ `String`

- **Parsing** (`Grammar`) produces a syntax tree that records what was written: numbers stay as digit strings, names aren't resolved, and anything a diagnostic could point at is `Located`. A syntax error becomes a `ScriptError` with a single `.syntax` diagnostic. Before parsing, `Script.checkNesting` rejects groups nested too deeply, also with a single diagnostic (see "Stack safety").
- **Compiling** (`Compiler`) resolves variables and names, lowers the tree to `Node`s, and collects *every* problem as a `Diagnostic` before throwing. Lowering always returns a node, using a placeholder after an error, so it can keep going and find more. The termination check runs only when nothing else is wrong. Rule sets are compiled once each, before any production, including those nothing uses, so their problems are reported once. Their rewrites are spliced into each sequence that uses them, so `Node` has no notion of a rule set. Splicing copies, so `Generator.maximumRewrites` caps a sequence's or rule set's rewrites: rule sets that each use the one before twice would otherwise double with every level.
- **Warnings** come from a separate pass over the syntax tree, after compiling succeeds, and end up in `Generator.warnings`. They're never computed for a script that fails to compile, so they can't repeat or contradict a diagnostic. Since any production can be a starting point, "unused" means nothing else refers to it, not that `_` can't reach it.
- **Generating** (`Evaluation`) walks the `Node`s.

The public API never exposes Parsimonious types. Keep it that way, so that Parsimonious can change without breaking Conlangr's users.

## Invariants carried by types

The user prefers type-driven design (see `../../CLAUDE.md`). These invariants are established by construction, so the evaluator doesn't check them:

- **Everything is resolved.** Productions refer to each other by index into `Generator.rules`, so a dangling reference can't exist in a `Generator`. `Generator.init(rules:main:indices:warnings:)` is internal, and only `Compiler` calls it, after its checks pass. `Generator.starting(at:)` only ever picks an index from `indices`, and since every production can finish, any of them is a safe place to start.
- **A copy always has something to copy.** The compiler resolves `^name` lexically, to an earlier `&name` item of a sequence around it in the same definition, and makes a `Node.copy(sequences:item:)`. When it's reached, that item is finished, and the evaluator's stack holds exactly the sequences in between above the one it names, since only sequences push. The compiler marks copied items with `Repetition.isCopied`, and `SequenceState` keeps what only those produced, so grammars without copies pay almost nothing.
- **Every production can finish.** `Compiler.checkTermination` computes which productions can finish (a least fixpoint, starting from literals) and rejects the rest. It reports only the productions in a cycle, not the ones that depend on a cycle, because fixing the cycle fixes those too.
- **`Choice` always has something to choose.** Its failable initializer drops zero-weight alternatives and returns `nil` if none are left. Duplicate alternatives are kept, so they count twice. That's what makes `*ptkk` weight `k` double.
- **Rewrites are resolved.** The compiler pairs each class in a replacement with a class in the pattern, and checks that their alternatives line up, so `Replacement.Element.choice` always has one alternative for each of its pattern class's. A `{}` in a pattern becomes a `.repeated` element that refers to an earlier class. A pattern that can match anywhere can't match nothing, so scanning a word always makes progress.
- **A repeat count can't be zero.** `Repetition`'s failable initializer rejects a `maximum` below 1, as `Choice`'s does for an empty choice.

## Grammar conventions

- **Commit once a construct has started.** For example, `(`, `&`, `^`, `*`, `$`, `@`, `%`, `-`, and `>` each commit what follows them, and definitions use `commit1()`. Without that, Parsimonious backtracks and reports "No alternative matched." at the start of the line. If a new error test shows that message, there's a missing commit or `expecting`.
- **Name recognizable mistakes** with `peek()` followed by `fail(...).commit()`. `strayQuantifier` and `misplacedRewrite` work this way.
- **Messages** are full sentences ending in a period, with straight double quotes around source text, like Parsimonious's own messages (`Expected ")".`).
- The grammar is recursive through `Grammar.expression`, a closure-based `Parser`. All parsers must stay `static let`s, which Swift initializes lazily (see Parsimonious's README, "Recursion").
- **A rule set's steps need parentheses.** `@x = > a=b` followed by `y = c` on the next line would parse `y = c` as a substitution, since whitespace may surround the `=` in both. Keep any new definition kind that holds rewrites delimited.
- `Grammar.reserved` lists the characters that can't appear unescaped in text. Several are unused and set aside for future syntax. If you add syntax, take characters from that set, and update both the grammar and `Lexicon`.
- Whitespace is `Parsers.whitespace`, meaning every scalar is whitespace, and `Grammar.isSpace` matches it. A space followed by a combining mark counts as text.

## Stack safety

No input may crash the process, including on a secondary thread's 512 KB stack.

- **Parsing is recursive, so nesting is limited.** Each level of parentheses costs about 21 KB of stack in a debug build, because it passes through many Parsimonious closures. On a 512 KB thread (a secondary thread's default), 20 levels parsed and 24 crashed in debug, and 40 crashed in release. `Script.checkNesting` counts parentheses with `tokenize`, which doesn't recurse, and rejects anything over `Script.maximumNesting` (12) before the parser runs. References don't nest, so deep structure is still possible. The compiler's tree walks (`lower`, `canFinish`, `references`) are recursive too, but they stop at references, so the same limit bounds them. If you change the grammar's layering, re-measure: `maximumNestingParsesOnASmallStack` checks the margin.
- **Rule sets are compiled with an explicit stack.** A chain of rule sets, each using the next, is flat, so nesting doesn't limit it, only the length of the source. Compiled recursively, a chain of 400 overflowed a 512 KB stack in debug. `Compiler.compileRuleSets` keeps a stack of frames instead: a rule set that uses an uncompiled one waits there while that one is compiled, and one that's waiting is how a rule set that includes itself is caught. `longRuleSetChainCompilesOnASmallStack` checks it.
- `Evaluation.produce` is **iterative, not recursive**. A recursive version overflowed the stack on Swift Testing's threads in debug builds, even with a depth limit of 256. References and selects are tail calls. Only sequences push a `SequenceState`, and each push costs a step, so `Generator.maximumSteps` bounds the explicit stack. Don't reintroduce recursion.

## Generation

- `Pattern` matches a pattern that's only text with String's own methods, and skips positions that can't start a match before running its backtracking matcher. Without both, debug builds, and so the tests, ran 3 to 6 times slower. A `Word` converts the word to characters once, for all the rewrites that need them until one changes it.
- `Generator.maximumLength` (64) applies everywhere, inclusively: at compile time, to literals, to each part of a pattern or replacement, to a pattern's shortest match, and to a replacement's longest result (classes that pair with the same pattern class choose together, so they're added up per alternative); at run time, to every intermediate and final result.
- The randomness is a generic `RandomNumberGenerator`. Tests use the seeded `SplitMix64` in `Tests/ConlangrTests/Support.swift`, so they're deterministic.

## Tests

- Swift Testing (`import Testing`, `@Test`, `#expect`). The tests use only the public API: no `@testable`.
- Statistical tests sample 10,000 words with a fixed seed and check each frequency to within 5% with `near(_:_:)`. The fixed seed makes them deterministic, and the tolerance means changes to how random numbers are consumed don't break them.
- Error tests compare `Diagnostic.description` strings, so they cover the message, the line, and the column together. When you change a message, update `README.md` too if it quotes the message.
- To check a question about semantics, add a throwaway `@Test` that tallies samples, run it, and delete it.

## Example grammars

The language examples, one per file (`QuenyaTests.swift`, `SindarinTests.swift`, `OldNorseTests.swift`, `IndoEuropeanTests.swift`, `PolynesianTests.swift`, `SiniticTests.swift`, `DineBizaadTests.swift`, `KlingonTests.swift`, `SumerianTests.swift`), double as documentation of good grammar-writing. README "More examples" lists them, so add new ones there too. New ones should follow the same conventions:

- **Idealize first, spell last.** Write the grammar with one symbol per sound, and turn it into the real orthography with substitutions at the very end of the outermost concat. Digraphs written early make patterns misfire (`*np*` matching *n* + *ph*). See README "Writing grammars", which also covers placeholders filled by local rewrites and agreement built into the grammar.
- **Test the rules, not just the inventory.** Each example checks its language's rules over 2,000 words from a fixed seed. The inventory test also catches placeholders that leak into the output. A test of the output sees the spelled form, so it has to allow for digraphs itself.
- **Check more than one seed** before settling on one, and look at a sample of words, since a grammar can pass every test and still not look like the language.
- **Say what it's based on.** The doc comment names the sources and the rules modeled, and the grammar's own comments explain each part.

## Style

- 2-space indentation, as formatted by `swift format` with its default configuration.
- Closures given to Parsimonious must be `@Sendable`, which they are implicitly in a `static let`. Hand-written parsers must spell out `throws(ParseError<String>)`.
