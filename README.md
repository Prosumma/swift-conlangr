# Conlangr

Conlangr is a small domain-specific language for generating random words for constructed languages ("conlangs"), and a Swift package that parses and evaluates it.

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
.package(url: "https://github.com/Prosumma/swift-conlangr", branch: "main"),
```

Then add `.product(name: "Conlangr", package: "swift-conlangr")` to your target's dependencies. Conlangr requires Swift 6.2 and macOS 13, iOS 16, tvOS 16, or watchOS 9. Its only dependency is [Parsimonious](https://github.com/Prosumma/Parsimonious).

## Usage

```swift
import Conlangr

let source = """
C = *ptkmnʔh
V = (? 3 a 1 ā 3 i 1 ī 3 u 1 ū 3 e 1 ē 3 o 1 ō)
syl = (+ &C &V)
_ = (+ &syl 3 &syl)
"""

let script = try parse(source)            // String -> Script
let generator = try script.normalize()    // Script -> Generator
for _ in 0..<10 {
  print(try generator.eval())             // Generator -> a random word
}
```

There are three stages:

1. **`parse(_:)`** turns source text into a `Script`. It throws Parsimonious's `ParseError<String>` on a syntax error, and `ParseError.index` points at the failure.
2. **`Script.normalize(with:)`** resolves variables and weights and produces a `Generator`. You can pass variable overrides here (see [Variables](#variables)). It throws `ScriptError.noMain` if the script has no `_` production.
3. **`Generator.eval()`** produces one random word. Each call is independent. It throws an `EvaluationError` if a reference can't be resolved, a word gets too long, or evaluation runs away (see [Limits](#limits)).

There is also **`tokenize(_:)`**, which turns source text into an array of `Token`s, each with a `kind`, a `value`, and a `range` in the source. It's meant for syntax highlighting and is forgiving: it labels text it doesn't recognize as `.error` tokens instead of throwing.

## The language

A script is a list of assignments, one per production. Whitespace, including newlines, doesn't matter except as a separator, and a `;` starts a comment that runs to the end of the line.

```
name = production
```

The production named `_` is the main production, and it's where generation starts. Every script must have one. The other productions can appear in any order, and they're referred to by name with `&`. If a name is assigned twice, the last assignment wins.

### Productions

| Syntax | Name | Produces |
|---|---|---|
| `abc` | literal | the text `abc` |
| `_` | empty | the empty string |
| `&name` | reference | whatever the production `name` produces |
| `*abc` | spread | one character, chosen uniformly from `a`, `b`, `c` |
| `(? p1 p2 …)` | select | one of the alternatives, chosen at random (by weight) |
| `(+ p1 p2 …)` | concat | each item in order, joined together |

Selects and concats nest freely, and an item inside either one can be any production:

```
syl = (? (+ &c &vowel &c) 2 (+ &c &vowel))
```

### Literals and escaping

A literal is a run of non-whitespace characters that aren't reserved. These characters are reserved:

```
( ) { } [ ] + ? & - $ @ ! ^ * = ' " : ; # < > 0-9
```

Several of them (`{ } [ ] @ ! ^ ' " : # <`) aren't used yet and are set aside for the future. To use a reserved character, or `%` itself, in a literal, put `%` in front of it. For example, `%'` is an apostrophe, `%3` is the digit 3, and `%%` is a percent sign. **Digits must be escaped**, because bare digits are quantifiers.

On its own, `_` means the empty string. Inside a longer literal, as in `a_b`, it's an ordinary underscore. Literals are Unicode-aware, so `ð`, `ʔ`, `ǫ`, and `tlh` are all fine.

### Spreads

`*abc` is shorthand for a select over the single characters `a`, `b`, and `c`, all with equal weight. A `_` inside a spread contributes an empty alternative, so `*a_` produces `a` or nothing. `%` escapes work here too.

Duplicates collapse, so `*ptkk` has the same distribution as `*ptk`. To weight one option more heavily, use a select.

### Select: `(? …)`

A select chooses one of its alternatives. Each alternative can have a **weight** in front of it, an integer from 1 to 255, and the weight is 1 if you leave it out. An alternative's probability is its weight divided by the sum of all the weights:

```
vowel = (? 2 &v &diph)        ; &v two-thirds of the time, &diph one-third
V = (? 3 a 1 ā 3 i 1 ī)       ; short vowels three times as common as long ones
```

### Concat: `(+ …)`

A concat produces each of its items in order and joins the results. In a concat, the number in front of an item is a **repeat count**: `N item` produces `item` between 1 and N times, with each count equally likely. An item with no number appears exactly once.

```
_ = (+ &syl 4 &syl)           ; 2 to 5 syllables
```

There's no way to produce an item zero times directly. To make something optional, select between it and `_`: `(? &coda _)`.

### Rewrites: skips and substitutions

After its items, a concat can have any number of **rewrite blocks**, which post-process the word it just built. The blocks run in the order they're written.

**Skips** (`- pattern …`) reject the word. If it matches any of the patterns, the whole concat is thrown away and generated again from scratch:

```
_ = (+ &syl 4 &syl - *aa* *ii* *uu* *vf*)    ; no doubled vowels, no "vf"
```

**Substitutions** (`> pattern=replacement …`) rewrite the word. They run one at a time, in order, and each one sees the output of the one before:

```
_ = (+ &syl 3 &syl > *nb*=mb *np*=mp *h=_)   ; assimilate nasals; drop a final h
```

A replacement of `_` deletes the match. Patterns use `*` to say where the text may appear:

| Pattern | Matches when the word… | A substitution replaces… |
|---|---|---|
| `abc` | is exactly `abc` | the whole word |
| `abc*` | starts with `abc` | the prefix |
| `*abc` | ends with `abc` | the suffix |
| `*abc*` | contains `abc` anywhere | every occurrence |

Because the blocks run in order, a skip placed after a substitution sees the substituted word. Here every `a` becomes `z`, and then any word containing `z` is rejected:

```
_ = (+ *ab > *a*=z - *z*)     ; always produces "b"
```

Rewrites apply only to the concat they're attached to. If you want them to apply to an entire word, attach them to the outermost concat.

### Variables

Variables let you change weights and repeat counts without editing the productions. Declare them with `$` **before** any production assignments, and use them anywhere a number can go:

```
$syllables = 3
$longvowel = 1

V = (? 3 a $longvowel ā 3 i $longvowel ī)
_ = (+ &syl $syllables &syl)
```

Values must be integers from 0 to 255. The host program can override them when it normalizes the script:

```swift
let generator = try script.normalize(with: ["syllables": 5, "longvowel": 0])
```

A variable that's used but never declared or overridden is treated as 1.

## Limits

Conlangr guards against grammars that never finish or that grow too large:

- **String length.** A literal in the source can't be longer than 64 characters (longer ones are a parse error). A generated string must stay under 64 characters, or evaluation throws `EvaluationError.generatedStringTooLong`.
- **Evaluation budget.** Each reference, select, and concat attempt (retries included) counts against a budget of 65,535 per call to `eval()`. If that runs out, `eval()` throws `EvaluationError.evaluationCountExceeded`. Usually this means a skip rejects every possible word, as in `(+ k *ai - ka ki)`, or a reference cycle with no way out.
- **Missing references.** A reference to an undefined production is caught only when it's actually evaluated, and then `eval()` throws `EvaluationError.refNotFound`. A reference on a branch that's rarely chosen can go unnoticed for a long time.
- **Zero weights and counts.** A weight of 0 in a select disables that alternative. But a select whose weights are all 0, or a repeat count of 0 in a concat, currently crashes at runtime instead of throwing.

## More examples

The unit tests in `Tests/ConlangrTests/ConlangrTests.swift` include grammars inspired by Old Norse, Polynesian, Sinitic, Klingon, Sumerian, and Quenya. Here is the Klingon one:

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
