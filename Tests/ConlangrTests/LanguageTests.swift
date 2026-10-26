import Conlangr
import Testing

struct LiteralTests {
  @Test func literal() throws {
    #expect(try word("_ = hello") == "hello")
  }

  @Test func underscoreIsEmpty() throws {
    #expect(try word("_ = _") == "")
  }

  @Test func underscoreInsideTextIsAnUnderscore() throws {
    #expect(try word("_ = a_b") == "a_b")
  }

  @Test func escapes() throws {
    #expect(try word("_ = (+ %' %( %3 %% %_)") == "'(3%_")
  }

  @Test func unicode() throws {
    #expect(try word("_ = (+ ð ʔ ǫ e\u{301})") == "ðʔǫé")
  }

  @Test func whitespaceAndComments() throws {
    let source = """
      ; A comment on its own line.
      _ = (   +     ; A comment inside a group.
        a
          b   ; Another.
      )   ; And one at the end, with no newline after it.
      """
    #expect(try word(source) == "ab")
  }

  @Test func maximumLengthLiteral() throws {
    let text = String(repeating: "a", count: Generator.maximumLength)
    #expect(try word("_ = \(text)") == text)
    // The same text through a reference: the limits agree.
    #expect(try word("x = \(text)\n_ = &x") == text)
  }
}

struct ReferenceTests {
  @Test func reference() throws {
    #expect(try word("x = hello\n_ = &x") == "hello")
  }

  @Test func definitionOrderDoesNotMatter() throws {
    #expect(try word("_ = (+ &a &b)\nb = second\na = first") == "firstsecond")
  }

  @Test func escapedName() throws {
    #expect(try word("%3x = yes\n_ = &%3x") == "yes")
  }

  @Test func recursion() throws {
    // Each word is one or more a's.
    let words = try words("w = (? a (+ a &w))\n_ = &w")
    #expect(!words.isEmpty)
    #expect(words.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0 == "a" } })
  }

  @Test func mainCanReferToItself() throws {
    let words = try words("_ = (? 3 b (+ a &_))")
    #expect(words.contains("b"))
    #expect(words.contains("ab"))
  }
}

struct SpreadTests {
  @Test func eachCharacterIsEquallyLikely() throws {
    let tally = try tally("_ = *abc")
    #expect(Set(tally.keys) == ["a", "b", "c"])
    #expect(near(tally["a"], 1 / 3))
    #expect(near(tally["b"], 1 / 3))
    #expect(near(tally["c"], 1 / 3))
  }

  @Test func repeatedCharactersCountAgain() throws {
    // `*ptkk` means `(? p t k k)`, so k is twice as likely as p or t.
    let tally = try tally("_ = *ptkk")
    #expect(near(tally["p"], 1 / 4))
    #expect(near(tally["t"], 1 / 4))
    #expect(near(tally["k"], 2 / 4))
  }

  @Test func underscoreIsAnEmptyAlternative() throws {
    let tally = try tally("_ = *a_")
    #expect(near(tally["a"], 1 / 2))
    #expect(near(tally[""], 1 / 2))
  }

  @Test func escapes() throws {
    #expect(try words("_ = *%3%_%*") == ["3", "_", "*"])
  }

  @Test func charactersAreGraphemes() throws {
    #expect(try words("_ = *e\u{301}ǫ") == ["é", "ǫ"])
  }
}

struct SelectTests {
  @Test func unweighted() throws {
    let tally = try tally("_ = (? a b)")
    #expect(near(tally["a"], 1 / 2))
    #expect(near(tally["b"], 1 / 2))
  }

  @Test func weights() throws {
    let tally = try tally("_ = (? 3 a b 6 c)")
    #expect(near(tally["a"], 3 / 10))
    #expect(near(tally["b"], 1 / 10))
    #expect(near(tally["c"], 6 / 10))
  }

  @Test func repeatedAlternativesCountAgain() throws {
    let tally = try tally("_ = (? a a b)")
    #expect(near(tally["a"], 2 / 3))
    #expect(near(tally["b"], 1 / 3))
  }

  @Test func zeroWeightIsNeverChosen() throws {
    #expect(try words("_ = (? 0 a b)") == ["b"])
  }

  @Test func weightWithoutSpace() throws {
    #expect(try words("_ = (? 0a b)") == ["b"])
  }

  @Test func nested() throws {
    #expect(try words("_ = (? (+ a b) *cd)") == ["ab", "c", "d"])
  }

  @Test func maximumWeight() throws {
    let tally = try tally("_ = (? 255 a b)")
    #expect(near(tally["a"], 255 / 256))
  }
}

struct SelectRewriteTests {
  @Test func substitution() throws {
    #expect(try words("_ = (? ka ki > *i=e)") == ["ka", "ke"])
  }

  @Test func skipChoosesAgain() throws {
    // The rejected alternative's weight goes to the others, in proportion.
    let tally = try tally("_ = (? 2 a 1 b 3 c - c)")
    #expect(tally["c"] == nil)
    #expect(near(tally["a"], 2 / 3))
    #expect(near(tally["b"], 1 / 3))
  }

  @Test func ruleSet() throws {
    #expect(try words("@r = (> *i=e)\n_ = (? ki ku @r)") == ["ke", "ku"])
  }

  @Test func appliesOnlyToTheSelect() throws {
    #expect(try words("_ = (+ i (? a b > *a=i))") == ["ii", "ib"])
  }

  @Test func appliesToWhicheverAlternativeWasChosen() throws {
    #expect(try words("_ = (? (+ *pt a) (+ *pt e) > p*=b)") == ["ba", "ta", "be", "te"])
  }

  @Test func copyInsideSeesTheConcatAroundIt() throws {
    // The select becomes a sequence of its own, which a copy has to count past.
    #expect(try words("x = *pt\n_ = (+ &x (? ^x q - q))") == ["pp", "tt"])
    #expect(try words("x = *pt\n_ = (+ &x (? (+ ^x q) r > *q=s))") == ["pps", "tts", "pr", "tr"])
  }

  @Test func copyFromInsideTheSelect() throws {
    #expect(try words("x = *pt\n_ = (? (+ &x ^x) a > *a=e)") == ["pp", "tt", "e"])
  }
}

struct SequenceTests {
  @Test func concatenates() throws {
    #expect(try word("_ = (+ a b c)") == "abc")
  }

  @Test func repeatCountIsAMaximum() throws {
    let tally = try tally("_ = (+ a 3 b)")
    #expect(Set(tally.keys) == ["ab", "abb", "abbb"])
    #expect(near(tally["ab"], 1 / 3))
    #expect(near(tally["abb"], 1 / 3))
    #expect(near(tally["abbb"], 1 / 3))
  }

  @Test func eachRepetitionIsChosenSeparately() throws {
    #expect(try words("_ = (+ 2 *ab)") == ["a", "b", "aa", "ab", "ba", "bb"])
  }

  @Test func optionalItem() throws {
    #expect(try words("_ = (+ ta (? *nm _))") == ["ta", "tan", "tam"])
  }
}

struct RewriteTests {
  @Test(arguments: [
    ("aXa", "*a*=o", "oXo"),
    ("aXa", "a*=o", "oXa"),
    ("aXa", "*a=o", "aXo"),
    ("aXa", "aXa=yes", "yes"),
    ("aXa", "aX=no", "aXa"),
    ("aXa", "*X*=_", "aa"),
    ("aXa", "*b*=c", "aXa"),
  ])
  func substitution(word input: String, substitution: String, expected: String) throws {
    #expect(try word("_ = (+ \(input) > \(substitution))") == expected)
  }

  @Test func substitutionsRunInOrder() throws {
    #expect(try word("_ = (+ ab > *a*=b *b*=c)") == "cc")
    #expect(try word("_ = (+ ab > *b*=c *a*=b)") == "bc")
  }

  @Test func spacesAroundEquals() throws {
    #expect(try word("_ = (+ ab > *a* = x)") == "xb")
  }

  @Test(
    arguments: [
      ("*aa*", ["ab", "ba", "bb"]),
      ("a*", ["ba", "bb"]),
      ("*a", ["ab", "bb"]),
      ("ab", ["aa", "ba", "bb"]),
    ] as [(String, Set<String>)])
  func skip(pattern: String, expected: Set<String>) throws {
    #expect(try words("_ = (+ *ab *ab - \(pattern))") == expected)
  }

  @Test func severalSkips() throws {
    #expect(try words("_ = (+ *ab *ab - aa bb)") == ["ab", "ba"])
  }

  @Test func skipEmptyWord() throws {
    #expect(try words("_ = (+ *a_ - _)") == ["a"])
  }

  @Test func skipAfterSubstitutionSeesTheSubstitutedWord() throws {
    #expect(try words("_ = (+ *ab > *a*=z - *z*)") == ["b"])
  }

  @Test func substitutionAfterSkip() throws {
    #expect(try words("_ = (+ *ab - a > b=c)") == ["c"])
  }

  @Test func rewritesApplyOnlyToTheirOwnSequence() throws {
    // The inner sequence turns a into b, but the outer one adds another a afterward.
    #expect(try word("_ = (+ (+ a > a=b) a)") == "ba")
  }
}

struct ClassTests {
  @Test(arguments: [
    ("*{a e}*=o", "bab", "bob"),
    ("*{a e}*=o", "beb", "bob"),
    ("*{a e}*=o", "bib", "bib"),
    ("{a e}*=o", "abe", "obe"),
    ("*{a e}=o", "abe", "abo"),
    ("b{a e}b=yes", "beb", "yes"),
    ("b{a e}b=yes", "bebe", "bebe"),
  ])
  func classMatchesAnyAlternative(substitution: String, input: String, expected: String) throws {
    #expect(try word("_ = (+ \(input) > \(substitution))") == expected)
  }

  @Test func mapsByPosition() throws {
    #expect(try word("_ = (+ ba¹ke² > *{a e}{¹ ²}*={á é}{_ _})") == "báké")
  }

  @Test func copiesWhatItMatched() throws {
    #expect(try word("_ = (+ ɣiɣeɣa > *ɣ{i e}*=y{})") == "yiyeɣa")
  }

  @Test func everyClassPairsWithTheOnlyOne() throws {
    // With one class in the pattern, each class in the replacement pairs with it.
    #expect(try word("_ = (+ lugal·ª > *{l n}·ª*={}·{}a)") == "lugal·la")
    #expect(try word("_ = (+ ab > *{a b}*={b a}{})") == "baab")
  }

  @Test func repeatsWhatTheClassBeforeMatched() throws {
    #expect(
      try words("_ = (+ *ab *ab *ab - *{a b}{}{}*)") == ["aab", "aba", "abb", "baa", "bab", "bba"])
    #expect(try word("_ = (+ kalla > *{l n}{}*={}d)") == "kalda")
  }

  @Test func longestAlternativeFirst() throws {
    #expect(try word("_ = (+ tla > *{t tl}*=X)") == "Xa")
    // If the longest alternative doesn't lead to a match, a shorter one is tried.
    #expect(try word("_ = (+ tla > *{t tl}la*=X)") == "X")
  }

  @Test func matchesDoNotOverlap() throws {
    #expect(try word("_ = (+ aaa > *{a}{a}*=b)") == "ba")
  }

  @Test func alternativesAreGraphemes() throws {
    #expect(try word("_ = (+ ɣí > *ɣ{i í}*=y{})") == "yí")
  }

  @Test func emptyMappedAlternativeDeletes() throws {
    #expect(try word("_ = (+ abc > *{a b}*={_ x})") == "xc")
  }

  @Test func escapesInAClass() throws {
    #expect(try word("_ = (+ %(a > *{%( %)}a*=b)") == "b")
  }
}

struct CopyTests {
  @Test func copiesWhatAnEarlierItemProduced() throws {
    let tally = try tally("_ = (+ &syllable ^syllable)\nsyllable = (? ka pu li)")
    #expect(Set(tally.keys) == ["kaka", "pupu", "lili"])
  }

  @Test func copiesEveryRepeat() throws {
    // The copy is of the whole item, so a word of two or three syllables is copied entire.
    let words = try words("_ = (+ 3 &syllable %- ^syllable)\nsyllable = *ab")
    #expect(words.allSatisfy { word in word.split(separator: "-").count == 2 })
    #expect(
      words.allSatisfy { word in
        let halves = word.split(separator: "-")
        return halves[0] == halves[1]
      })
    #expect(words.contains { $0.count == 7 })
  }

  @Test func copiesTheLatestOfSeveral() throws {
    #expect(try word("_ = (+ &a &b &a ^a ^b)\na = *x\nb = *y") == "xyxxy")
    let words = try words("_ = (+ &a &a ^a)\na = *xy")
    #expect(words.allSatisfy { $0.dropFirst().first == $0.last })
  }

  @Test func copiesFromAConcatAroundIt() throws {
    // Optional reduplication: the copy is inside a select, inside a later item.
    let tally = try tally("_ = (+ &root (? 1 _ 1 (+ %- ^root)))\nroot = (? ka pu)")
    #expect(Set(tally.keys) == ["ka", "pu", "ka-ka", "pu-pu"])
    // Two concats out.
    #expect(try word("_ = (+ &a (+ b (+ c ^a)))\na = x") == "xbcx")
  }

  @Test func copiesTheItemAfterItsRewrites() throws {
    // The copy is of what the item produced, and the concat's own rewrites then apply to both.
    let source = """
      _ = (+ &root ^root > *a*=e)
      root = (+ ka > *k*=t)
      """
    #expect(try word(source) == "tete")
  }

  @Test func isRedoneWhenTheConcatIsRejected() throws {
    let words = try words("_ = (+ &a ^a - xx)\na = (? x y z)")
    #expect(words == ["yy", "zz"])
  }

  @Test func canBeRepeatedAndWeighted() throws {
    #expect(try word("_ = (+ &a 3 ^a)\na = x").allSatisfy { $0 == "x" })
    #expect(try words("_ = (+ &a (? 0 ^a 1 y))\na = x") == ["xy"])
  }
}

struct RuleSetTests {
  @Test func appliesItsRulesInOrder() throws {
    let source = """
      @spelling = (> *a*=b *b*=c)
      _ = (+ a @spelling)
      """
    #expect(try word(source) == "c")
  }

  @Test func canBeDefinedAfterItsUse() throws {
    #expect(try word("_ = (+ ŋa @spelling)\n@spelling = (> *ŋ*=ng)") == "nga")
  }

  @Test func skipsAndSubstitutionsTogether() throws {
    let source = """
      @rules = (- *q* > *ŋ*=ng)
      _ = (+ (? ŋa qa) @rules)
      """
    #expect(try words(source) == ["nga"])
  }

  @Test func mixesWithOtherSteps() throws {
    // A rule set can go inside a "-" or ">" block, which carries on after it.
    let source = """
      @double = (> *b*=bb)
      _ = (+ a > *a*=b @double *bb*=cb - *x* @double)
      """
    #expect(try word(source) == "cbb")
  }

  @Test func includesOtherRuleSets() throws {
    let source = """
      @first = (> *a*=b)
      @both = (@first > *b*=c)
      _ = (+ aa @both)
      """
    #expect(try word(source) == "cc")
  }

  @Test func reusable() throws {
    let source = """
      @plural = (> *{a o}={e i})
      _ = (? (+ kala @plural) (+ toro @plural))
      """
    #expect(try words(source) == ["kale", "tori"])
  }
}

struct VariableTests {
  @Test func weight() throws {
    let tally = try tally("$w = 3\n_ = (? $w a b)")
    #expect(near(tally["a"], 3 / 4))
  }

  @Test func repeatCount() throws {
    #expect(try words("$n = 2\n_ = (+ $n a)") == ["a", "aa"])
  }

  @Test func override() throws {
    #expect(try words("$n = 2\n_ = (+ $n a)", overrides: ["n": 3]) == ["a", "aa", "aaa"])
  }

  @Test func overrideToZeroDisablesAnAlternative() throws {
    #expect(try words("$w = 3\n_ = (? $w a b)", overrides: ["w": 0]) == ["b"])
  }

  @Test func declarationsCanComeAfterProductions() throws {
    #expect(try words("_ = (+ $n a)\n$n = 2") == ["a", "aa"])
  }

  @Test func namesCanStartWithAnUnderscore() throws {
    // Only "_" on its own means the empty string, so it's the only name that can't be used.
    let source = "$_n = 2\n$%_ = 1\n@_r = (> *a*=b)\n_ = (+ $_n a $%_ c @_r)"
    #expect(try words(source) == ["bc", "bbc"])
  }

  @Test func scriptListsItsVariables() throws {
    let script = try Script("$a = 1\n$b = 255\n$c = 256\n_ = x")
    #expect(script.variables == ["a": 1, "b": 255])
  }
}

struct RandomnessTests {
  @Test func sameSeedSameWords() throws {
    let generator = try Generator("_ = (+ *ptk *aeiou 3 (+ *ptk *aeiou))")
    var first = SplitMix64(seed: 42)
    var second = SplitMix64(seed: 42)
    let a = try (0..<20).map { _ in try generator.generate(using: &first) }
    let b = try (0..<20).map { _ in try generator.generate(using: &second) }
    #expect(a == b)
    #expect(Set(a).count > 1)
  }

  @Test func systemRandom() throws {
    let generator = try Generator("_ = *abc")
    #expect(["a", "b", "c"].contains(try generator.generate()))
  }
}

struct StartingTests {
  static let source = """
    _ = (+ &noun > p*=b)
    noun = (+ &root (? _ s))
    root = *pt
    verb = (+ &root e)
    """

  @Test func startsFromTheNamedProduction() throws {
    let generator = try #require(try Generator(Self.source).starting(at: "noun"))
    var random = SplitMix64(seed: 1)
    let words = Set(try (0..<200).map { _ in try generator.generate(using: &random) })
    // The main production's substitution doesn't apply.
    #expect(words == ["p", "t", "ps", "ts"])
  }

  @Test func canStartFromAProductionNothingRefersTo() throws {
    let generator = try #require(try Generator(Self.source).starting(at: "verb"))
    var random = SplitMix64(seed: 1)
    let words = Set(try (0..<200).map { _ in try generator.generate(using: &random) })
    #expect(words == ["pe", "te"])
  }

  @Test func underscoreIsTheMainProduction() throws {
    let generator = try Generator("_ = *abcdefgh")
    let main = try #require(generator.starting(at: "_"))
    var first = SplitMix64(seed: 7)
    var second = SplitMix64(seed: 7)
    let a = try (0..<20).map { _ in try generator.generate(using: &first) }
    let b = try (0..<20).map { _ in try main.generate(using: &second) }
    #expect(a == b)
  }

  @Test func startingAgainIsFromTheNewProduction() throws {
    let generator = try Generator(Self.source)
    let verb = try #require(generator.starting(at: "noun")?.starting(at: "verb"))
    #expect(try verb.generate().hasSuffix("e"))
  }

  @Test func unknownProductionIsNil() throws {
    let generator = try Generator(Self.source)
    #expect(generator.starting(at: "adjective") == nil)
    #expect(generator.starting(at: "&noun") == nil)
    // The main production's name is empty inside, but that isn't a name.
    #expect(generator.starting(at: "") == nil)
  }

  @Test func listsTheProductionsInOrder() throws {
    let generator = try Generator(Self.source)
    #expect(generator.productions == ["_", "noun", "root", "verb"])
    #expect(generator.starting(at: "verb")?.productions == generator.productions)
  }

  @Test func keepsTheWarnings() throws {
    let generator = try Generator(Self.source)
    #expect(
      generator.warnings.map(\.description) == ["4:1: Nothing refers to the production \"verb\"."])
    #expect(generator.starting(at: "verb")?.warnings == generator.warnings)
  }
}

struct CountTests {
  @Test func generatesTheCount() throws {
    let generator = try Generator("_ = *ab")
    var random = SplitMix64(seed: 1)
    let words = try generator.generate(count: 50, using: &random)
    #expect(words.count == 50)
    #expect(Set(words) == ["a", "b"])
  }

  @Test func sameWordsAsOneAtATime() throws {
    let generator = try Generator("_ = (+ *ptk *aeiou 3 (+ *ptk *aeiou))")
    var first = SplitMix64(seed: 3)
    var second = SplitMix64(seed: 3)
    let words = try generator.generate(count: 20, using: &first)
    #expect(words == (try (0..<20).map { _ in try generator.generate(using: &second) }))
  }

  @Test func distinctKeepsTheFirstOfEach() throws {
    let generator = try Generator("_ = (+ *ptk *aeiou)")
    var first = SplitMix64(seed: 5)
    var second = SplitMix64(seed: 5)
    let words = try generator.generate(count: 10, distinct: true, using: &first)
    var expected: [String] = []
    while expected.count < 10 {
      let word = try generator.generate(using: &second)
      if !expected.contains(word) {
        expected.append(word)
      }
    }
    #expect(words == expected)
  }

  @Test func distinctGivesUpWhenThereAreNoMore() throws {
    let generator = try Generator("_ = *abc")
    var random = SplitMix64(seed: 1)
    let words = try generator.generate(count: 10, distinct: true, using: &random)
    #expect(words.count == 3)
    #expect(Set(words) == ["a", "b", "c"])
  }

  @Test func zero() throws {
    #expect(try Generator("_ = a").generate(count: 0) == [])
    #expect(try Generator("_ = a").generate(count: 0, distinct: true) == [])
  }

  @Test func systemRandom() throws {
    #expect(try Generator("_ = a").generate(count: 3) == ["a", "a", "a"])
  }

  @Test func throwsWhatGeneratingThrows() throws {
    let generator = try Generator("_ = (+ k *ai - ka ki)")
    #expect(throws: GenerationError.tooManySteps) {
      try generator.generate(count: 2)
    }
  }
}
