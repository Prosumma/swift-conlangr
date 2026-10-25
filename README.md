# Conlangr

Conlangr is a small domain-specific language for generating random words for constructed languages ("conlangs"), and a Swift package that parses, compiles, and runs it.

You describe a language's sound inventory and syllable structure as a set of named productions. Conlangr then generates as many plausible-looking words as you want:

```
; Quenya-ish
initialc = *ptkmnsrly
medialc  = (? mp nt nk ld rd ny ry ly nd mb)
finalc   = *nrlmt
vowel    = *aeiou
middle   = (+ &vowel &medialc)
final    = (? 2 &vowel (+ &vowel &finalc))
_        = (+ &initialc 2 &middle &final - *yi*)
```

```
merderde  neldan  kuryaryal  linde  pulyen  sumpumbo  rinkentir  piryante
```

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/Prosumma/swift-conlangr", from: "1.0.0"),
```

Then add `.product(name: "Conlangr", package: "swift-conlangr")` to your target's dependencies. Conlangr requires Swift 6.4 and macOS 13, iOS 16, tvOS 16, or watchOS 9. Its only dependency is [Parsimonious](https://github.com/Prosumma/Parsimonious).

## Usage

```swift
import Conlangr

let source = """
C = *ptkmnʔh
V = (? 3 a 1 ā 3 i 1 ī 3 u 1 ū 3 e 1 ē 3 o 1 ō)
syl = (+ &C &V)
_ = (+ &syl 3 &syl)
"""

let generator = try Generator(source)   // Parse and compile
for _ in 0..<10 {
  print(try generator.generate())        // A random word
}
```

`Generator(_:overrides:)` does two things, which you can also do separately:

1. **`Script(_:)`** parses the source. If it doesn't follow the grammar, this throws a `ScriptError`.
2. **`Script.compile(overrides:)`** checks the script and turns it into a `Generator`. You can override the script's variables here (see [Variables](#variables)). It throws a `ScriptError` that lists every problem it finds: an undefined reference, a production that can never finish, and so on.

Then **`Generator.generate()`** produces one random word. A `Generator` is a `Sendable` value, and each call is independent. To make the output reproducible, pass your own seeded generator to `generate(using:)`.

There's also **`tokenize(_:)`**, which splits source text into `Token`s for syntax highlighting. Each token has a `kind`, a `value`, and a `range` in the source. It never fails: anything it doesn't recognize becomes an `.error` token.

### Errors

A `ScriptError` has a list of `diagnostics`. Each `Diagnostic` has a `problem`, which says what's wrong, and a `location`, which gives the line, column, and source range. Its `description` puts them together:

```
1:8: There is no production named "vowl".
3:1: The production "syl" is already defined.
```

A syntax error stops parsing, so it's always the only diagnostic. So is nesting groups too deeply (see [Limits](#limits)), which is checked before parsing. Compilation reports everything it finds, in source order. The `Diagnostic.Problem` cases are listed in [Checks](#checks).

`generate()` throws a `GenerationError` when a word gets too long or takes too many steps (see [Limits](#limits)).

## The language

A script is a list of definitions in any order. A definition assigns a production to a name:

```
name = production
```

The production named `_` is the main production, and it's where generation starts. Every script must have exactly one. The other productions are referred to by name with `&`. Whitespace, including newlines, only separates things, and a `;` starts a comment that runs to the end of the line.

### Productions

| Syntax | Name | Produces |
|---|---|---|
| `abc` | literal | the text `abc` |
| `_` | empty | the empty string |
| `&name` | reference | whatever the production `name` produces |
| `*abc` | spread | one of the characters `a`, `b`, or `c`, chosen at random |
| `(? p1 p2 …)` | select | one of the alternatives, chosen at random (by weight) |
| `(+ p1 p2 …)` | concat | each item in order, joined together |

Selects and concats nest freely, and an item inside either one can be any production:

```
syl = (? (+ &c &vowel &c) 2 (+ &c &vowel))
```

### Literals and escaping

A literal is a run of characters that aren't whitespace and aren't reserved. These characters are reserved:

```
( ) { } [ ] + ? & - $ @ ! ^ * = ' " : ; # < > 0-9
```

Several of them (`{ } [ ] @ ! ^ ' " : # <`) aren't used yet and are set aside for the future. To use a reserved character in a literal, or `%` itself, put `%` in front of it. For example, `%'` is an apostrophe, `%3` is the digit 3, and `%%` is a percent sign. **Digits must be escaped**, because bare digits are weights and repeat counts.

On its own, `_` means the empty string. Inside a longer literal, as in `a_b`, it's an ordinary underscore, and `%_` is always an underscore. Literals are Unicode-aware, so `ð`, `ʔ`, `ǫ`, and `tlh` are all fine.

The sigils `&`, `$`, and `*` must be directly in front of what they apply to: `&name`, not `& name`.

### Spreads

`*abc` is shorthand for `(? a b c)`, a select over the single characters `a`, `b`, and `c`. A repeated character counts each time it appears, so in `*ptkk`, `k` is twice as likely as `p` or `t`. A `_` inside a spread is an empty alternative, so `*a_` produces `a` or nothing. `%` escapes work here too.

### Select: `(? …)`

A select chooses one of its alternatives. Each alternative can have a **weight** in front of it, an integer from 0 to 255. If you leave the weight out, it's 1. An alternative's probability is its weight divided by the sum of all the weights:

```
vowel = (? 2 &v &diph)        ; &v two-thirds of the time, &diph one-third
V = (? 3 a 1 ā 3 i 1 ī)       ; short vowels three times as common as long ones
```

An alternative with weight 0 is never chosen, which is useful with [variables](#variables). At least one alternative must have a weight above 0. As with spreads, an alternative that appears twice is counted twice.

### Concat: `(+ …)`

A concat produces each of its items in order and joins the results. In a concat, the number in front of an item is a **repeat count**: `N item` produces `item` between 1 and N times, with each count equally likely. Each repetition is chosen separately, so `(+ 3 *ptk)` can produce `ptk`. An item with no number appears exactly once.

```
_ = (+ &syl 4 &syl)           ; 2 to 5 syllables
```

A repeat count must be at least 1. To make something optional, select between it and `_`: `(? &coda _)`.

### Rewrites: skips and substitutions

After its items, a concat can have any number of **rewrite blocks**, which post-process the word it just built. The blocks run in the order they're written.

**Skips** (`- pattern …`) reject the word. If it matches any of the patterns, the whole concat is thrown away and generated again from scratch:

```
_ = (+ &syl 4 &syl - *aa* *ii* *uu* *vf*)    ; no doubled vowels, no "vf"
```

**Substitutions** (`> pattern=replacement …`) rewrite the word. They run one at a time, in order, and each one sees the output of the one before:

```
_ = (+ &syl 3 &syl > *nb*=mb *np*=mp *h=_)   ; assimilate nasals, drop a final h
```

A replacement of `_` deletes the match. Patterns use `*` to say where the text may appear:

| Pattern | Matches when the word… | A substitution replaces… |
|---|---|---|
| `abc` | is exactly `abc` | the whole word |
| `abc*` | starts with `abc` | the prefix |
| `*abc` | ends with `abc` | the suffix |
| `*abc*` | contains `abc` anywhere | every occurrence |

The pattern `_` matches the empty word, so `- _` rejects a concat that produced nothing. A pattern with a `*` must have some text. Patterns must be separated by whitespace: `- *a*b` is an error, not the two patterns `*a*` and `b`.

Because the blocks run in order, a skip placed after a substitution sees the substituted word. Here every `a` becomes `z`, and then any word containing `z` is rejected:

```
_ = (+ *ab > *a*=z - *z*)     ; always produces "b"
```

Rewrites apply only to the concat they're attached to. To apply them to an entire word, attach them to the outermost concat.

### Variables

Variables let you change weights and repeat counts without editing the productions. Declare a variable with `$`, and use it anywhere a number can go:

```
$syllables = 3
$longvowel = 1

V = (? 3 a $longvowel ā 3 i $longvowel ī)
_ = (+ &syl $syllables &syl)
```

Values are integers from 0 to 255. Declarations can go anywhere in the script, but each variable can be declared only once, and using one that isn't declared is an error. The host program can override the values when it compiles the script:

```swift
let script = try Script(source)
print(script.variables)    // ["syllables": 3, "longvowel": 1]
let generator = try script.compile(overrides: ["syllables": 5, "longvowel": 0])
```

Overriding a variable the script doesn't declare is an error. Setting one to 0 is fine wherever it's used as a weight, but not where it's used as a repeat count.

## Checks

Compiling catches these problems before any word is generated, each reported as a `Diagnostic.Problem`:

| Problem | Example |
|---|---|
| `missingMain` | no `_ = …` |
| `duplicateProduction`, `duplicateVariable` | `x` or `$n` defined twice |
| `undefinedProduction` | `&vowl` when there's no `vowl`, even on a branch that's rarely chosen |
| `undefinedVariable` | `$n` when there's no `$n = …` |
| `unknownOverride` | an override for a variable the script doesn't declare |
| `numberTooLarge` | a weight, repeat count, or variable above 255 |
| `textTooLong` | a literal, pattern, or replacement longer than 64 characters |
| `zeroRepeatCount` | `(+ a 0 b)` |
| `noChoosableAlternative` | `(? 0 a 0 b)` |
| `emptyPattern` | `- *_*` |
| `neverFinishes` | `a = (+ x &a)`, which can only ever produce more of itself |

A syntax error is reported as `syntax`, with a message saying what was expected, and groups nested too deeply as `nestedTooDeeply`.

## Limits

Groups can be nested at most 12 deep within one definition (`Script.maximumNesting`). The parser is recursive, and this keeps it well clear of overflowing the stack. A reference doesn't count as nesting, so to build something deeper, give some of the inner groups their own names:

```
inner = (? a b)
_ = (+ x &inner y)      ; rather than (+ x (? a b) y), when the nesting gets deep
```

Some grammars can only be judged by running them, so `generate()` has two safeguards:

- **Length.** Everything that's generated, including each part of a word along the way, must be at most 64 characters (`Generator.maximumLength`). Otherwise, `generate()` throws `GenerationError.tooLong`. The same limit applies to literals in the source, so a literal can never be too long to use.
- **Steps.** Generating a word may take at most 65,535 steps (`Generator.maximumSteps`). Each reference, each select, and each attempt at a concat counts as a step, including attempts that a skip rejects. Otherwise, `generate()` throws `GenerationError.tooManySteps`. Usually this means a skip rejects every possible word, as in `(+ k *ai - ka ki)`, or a production refers to itself so often that it rarely finishes.

Generation doesn't recurse, so no grammar can overflow the stack while generating, however much its productions refer to each other.

## More examples

The unit tests in `Tests/ConlangrTests/ExampleTests.swift` include grammars inspired by Old Norse, Polynesian, Sinitic, Klingon, Sumerian, and Quenya. Two fuller ones use variables, skips, and substitutions: `Tests/ConlangrTests/DineBizaadTests.swift`, inspired by Diné Bizaad (Navajo), builds sibilant harmony into the grammar, and `Tests/ConlangrTests/IndoEuropeanTests.swift`, inspired by Proto-Indo-European, models ablaut, laryngeal coloring, and root constraints. Here is the Klingon one:

```
C = (? b D g H j l m n p q Q r S t v w y %'   ; base consonants
    1 ch 1 gh 1 tlh 1 ng)                    ; multigraphs
F = (? 3 b 3 D 3 g 3 H 3 j 3 l 3 m 3 n 3 p 3 q 3 Q 3 r 3 S 3 t 3 v 3 w 3 y
    1 ch 1 gh 1 tlh 1 ng)
V = *aeIoU

S = (? 3 &CVC &CV)              ; favor closed syllables
CV = (+ &C &V)
CVC = (+ &C &V &F)

_ = (+ &S 2 &S)
```

## License

MIT. See [LICENSE](LICENSE).
