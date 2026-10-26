# Conlangr

Conlangr is a small domain-specific language for generating random words for constructed languages ("conlangs"), and a Swift package that parses, compiles, and runs it.

You describe a language's sound inventory and syllable structure as a set of named productions. Conlangr then generates as many plausible-looking words as you want:

```
; A small Elvish-sounding language
C   = *tttkkpmnnnllrrsvh
V   = (? 4 a 3 e 3 i 2 o 1 u 1 ai)
syl = (? 3 (+ &C &V) 1 (+ &C &V *nlrs))
_   = (+ (? 2 &V 3 _) &syl 2 &syl (? 8 _ 1 (+ *lnr ion) 1 ndil 1 wen)
        - *ii* *uu* > *k*=c)
```

```
rainai  ilono  tisicendil  esinarion  amoso  atine  ivecil  cavamandil
```

For fuller grammars, see [More examples](#more-examples).

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

A script is a list of definitions in any order. Most definitions assign a production to a name:

```
name = production
```

Two other kinds of definition name a number, `$name = 3` (see [Variables](#variables)), and a set of rewrites, `@name = (…)` (see [Rule sets](#rule-sets)).

The production named `_` is the main production, and it's where generation starts. Every script must have exactly one. The other productions are referred to by name with `&`. Whitespace, including newlines, only separates things, and a `;` starts a comment that runs to the end of the line.

### Productions

| Syntax | Name | Produces |
|---|---|---|
| `abc` | literal | the text `abc` |
| `_` | empty | the empty string |
| `&name` | reference | whatever the production `name` produces |
| `^name` | copy | exactly what an earlier `&name` in the same word produced |
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

### Copies: `^name`

A copy repeats exactly what an earlier `&name` produced, which is how to write reduplication:

```
_ = (+ &root ^root)                      ; wikiwiki
_ = (+ &syllable ^syllable &syllable)    ; pupule
_ = (+ &root (? 3 _ 1 (+ %- ^root)))     ; kur, and sometimes kur-kur
```

The `&name` must be an item of a concat that the copy comes later in, either directly or inside one of its later items, as in the third line. It must also be in the same definition. That way, it has always been produced by the time the copy needs it, and compiling reports a copy that has nothing to copy. If there are several, the copy is of the latest. It copies the whole item, so after `3 &syllable`, `^syllable` repeats every syllable it produced. It copies the item as it came out, after the item's own rewrites, and the concat's rewrites then apply to both.

A copy can have a weight or repeat count like any other item: `(+ &root 2 ^root)` says the root two or three times.

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

#### Classes

A **class** in braces matches any one of its alternatives, which are separated by whitespace. `*{a e}h₂*` matches *ah₂* or *eh₂*. When more than one alternative could match, the longest is tried first.

In a replacement, a class maps what the pattern's class matched to the alternative in the same position, so these two lines say the same thing:

```
> *{a e i}¹*={ā ē ī}
> *a¹*=ā *e¹*=ē *i¹*=ī
```

An empty class, `{}`, means "the same":

- In a replacement, `{}` copies whatever its class in the pattern matched: `*ɣ{i e}*=y{}` turns *ɣi* into *yi* and *ɣe* into *ye*.
- In a pattern, `{}` repeats whatever the class before it matched: `- *{a e i o u}{}{}*` rejects three of the same vowel in a row.

The classes in a replacement pair with those in the pattern in order, so there must be as many of them. If the pattern has only one class, though, every class in the replacement pairs with that one, so its match can be used more than once:

```
> *{l n r}·a*={}·{}a      ; lugal·a → lugal·la
```

A mapped alternative can be `_`, which deletes what it replaces: `*{⁰ ŋ}*={_ ng}`.

Since a class maps every match in a single pass, it can express a chain shift, where one sound becomes another that's itself changing. `*{k t}*={ʔ k}` turns *taku* into *kaʔu*. As two separate substitutions, `*k*=ʔ *t*=k` would only work in that order. In the other order, every *t* would become *k* and then *ʔ*.

#### Rule sets

A **rule set** gives a name to skips and substitutions, so that more than one concat can use them. Define it with `@` and put its blocks in parentheses:

```
@spelling = (> *ŋ*=ng *ʔ*=ʻ)
@final = (- *{a e i o u}{}{}* > *h=_)
```

Then write `@name` anywhere a skip or substitution can go, and it stands for the rule set's rewrites, in order:

```
ancestor = (+ &word @spelling)
descendant = (+ &word @soundChanges @spelling)
plural = (+ &word > *a*=e @spelling *x*=ks)   ; in a block, which carries on after it
```

A rule set can use other rule sets, but not itself, directly or through another rule set. Like productions, rule sets can be defined anywhere in the script, and each name can be defined only once. Their names are separate from productions' and variables', so `@word`, `&word` and `$word` can all exist.

The parentheses are required. Without them, a definition on the next line, such as `x = a`, would read as one more substitution.

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
| `duplicateProduction`, `duplicateVariable`, `duplicateRuleSet` | `x`, `$n` or `@r` defined twice |
| `undefinedProduction` | `&vowl` when there's no `vowl`, even on a branch that's rarely chosen |
| `undefinedVariable` | `$n` when there's no `$n = …` |
| `undefinedRuleSet` | `@r` when there's no `@r = (…)` |
| `nothingToCopy` | `(+ ^a &a)`, or a `^a` with no earlier `&a` in a concat around it |
| `ruleSetIncludesItself` | `@r = (> a=b @r)`, or two rule sets that use each other |
| `tooManyRewrites` | more than 1,024 skips and substitutions in one concat or rule set, counting those of the rule sets it uses |
| `unknownOverride` | an override for a variable the script doesn't declare |
| `numberTooLarge` | a weight, repeat count, or variable above 255 |
| `textTooLong` | a literal, pattern, or replacement longer than 64 characters |
| `zeroRepeatCount` | `(+ a 0 b)` |
| `noChoosableAlternative` | `(? 0 a 0 b)` |
| `emptyPattern` | `- *_*` |
| `emptyAlternative` | `- *{a _}*` |
| `nothingToRepeat` | `- *{}a*`, with no class before the `{}` |
| `classCountMismatch` | `> *{a b}{c d}*={}`, with two classes in the pattern and one in the replacement |
| `classSizeMismatch` | `> *{a b c}*={x y}` |
| `patternTooLong` | a pattern whose shortest match is longer than 64 characters, so it can never match |
| `replacementTooLong` | a replacement that can produce more than 64 characters |
| `neverFinishes` | `a = (+ x &a)`, which can only ever produce more of itself |

A syntax error is reported as `syntax`, with a message saying what was expected, and groups nested too deeply as `nestedTooDeeply`.

## Limits

Groups can be nested at most 12 deep within one definition (`Script.maximumNesting`). The parser is recursive, and this keeps it well clear of overflowing the stack. A reference doesn't count as nesting, so to build something deeper, give some of the inner groups their own names:

```
inner = (? a b)
_ = (+ x &inner y)      ; rather than (+ x (? a b) y), when the nesting gets deep
```

A concat or rule set can have at most 1,024 skips and substitutions (`Generator.maximumRewrites`), counting those of the rule sets it uses. Rule sets can use each other as deeply as you like, but since each use stands for all of a rule set's rewrites, rule sets that each use the one before twice would otherwise double with every one.

Some grammars can only be judged by running them, so `generate()` has two safeguards:

- **Length.** Everything that's generated, including each part of a word along the way, must be at most 64 characters (`Generator.maximumLength`). Otherwise, `generate()` throws `GenerationError.tooLong`. The same limit applies to the source: a literal, a pattern's shortest match, and a replacement's longest result must all fit, so none of them can be too long to use.
- **Steps.** Generating a word may take at most 65,535 steps (`Generator.maximumSteps`). Each reference, each select, and each attempt at a concat counts as a step, including attempts that a skip rejects. Otherwise, `generate()` throws `GenerationError.tooManySteps`. Usually this means a skip rejects every possible word, as in `(+ k *ai - ka ki)`, or a production refers to itself so often that it rarely finishes.

Generation doesn't recurse, so no grammar can overflow the stack while generating, however much its productions refer to each other.

## Writing grammars

### Idealize first, spell last

Write the grammar in an idealized form, with one symbol per sound, and turn it into the real spelling with substitutions at the very end, on the outermost concat. Any symbol will do, as long as the final substitutions replace it.

```
_ = (+ &word
  > *nr*=ðr                      ; sound changes see one symbol per sound
    *au=aw                       ; spelling conventions come after them
    *þ*=th *ð*=dh *χ*=ch)        ; and digraphs are spelled out last
```

Spelling breaks patterns. Once *ph* is written as two letters, `*np*` matches *n* followed by *ph*, and a test for the voiceless *hw* finds it in *thw*. With φ for *ph* and þ for *th* until the end, every rule matches what it means. Conventions such as writing a final *au* as *aw* also belong at the end, after the rules that might create or destroy an *au*. The Sindarin example works this way.

### Fill in a placeholder with a local rewrite

Rewrites apply only to the concat they're attached to, so wrapping a production in a concat gives it rewrites of its own. Combined with a placeholder, that lets one definition take several forms. The Proto-Indo-European example writes each root once, with `·` in place of its vowel, and fills in the vowel to suit each use:

```
accentedRoot = (? 2 (+ &root > *·*=é) 1 (+ &root > *·*=ó))
zeroRoot = (+ &root > *·r*=r̥ *·n*=n̥ *·*=_)
```

### Build agreement into the grammar

A rewrite can't depend on what else is in the word, so it can't enforce agreement between distant parts, such as vowel or consonant harmony. Instead, build each kind of word separately, from parts that agree. The Diné Bizaad example keeps two series of sibilants apart by having separate productions for words with front sibilants, words with back sibilants, and words with neither.

### Name things instead of nesting them

A reference doesn't count toward the nesting limit, and a name documents what a group is for. When a production gets hard to read, move its inner groups into productions of their own. Likewise, when two concats need the same rewrites, give the rewrites a name with a rule set rather than repeating them.

## More examples

Each of these test files holds a grammar for a language inspired by a real or invented one, with tests that check it follows that language's rules. They're written the way [Writing grammars](#writing-grammars) recommends, and each one's comments explain what it models and where that comes from.

| File | Inspired by | Shows |
|---|---|---|
| `QuenyaTests.swift` | Tolkien's Quenya | Diaeresis and c/qu/x spelled at the end; plurals in -r and -i by ordered substitutions |
| `SindarinTests.swift` | Tolkien's Sindarin | Plurals by vowel change in the last syllable and the rest, as rule sets; digraphs as single letters |
| `OldNorseTests.swift` | Old Norse (normalized Old Icelandic) | One letter for þ and ð; u-umlaut as a local rewrite; assimilation; compounds |
| `IndoEuropeanTests.swift` | Proto-Indo-European | Ablaut with a placeholder vowel; laryngeal coloring; root constraints; sound laws |
| `PolynesianTests.swift` | Proto-Polynesian and Hawaiian | Sound changes as one class, so a chain shift can't collapse, checked against real cognates; rule sets shared by two languages; full and partial reduplication |
| `SiniticTests.swift` | Mandarin in pinyin | Initials and finals that combine as in Mandarin; pinyin's spelling and tone marks |
| `DineBizaadTests.swift` | Diné Bizaad (Navajo) | Sibilant harmony built into the grammar; tone and nasality |
| `KlingonTests.swift` | Klingon | Case-sensitive spelling; verb and noun suffixes in ordered slots |
| `SumerianTests.swift` | Sumerian | Hyphenated cuneiform transliteration; vowel harmony in verbal prefixes; plurals by reduplication |

They're all in `Tests/ConlangrTests`.

## License

MIT. See [LICENSE](LICENSE).
