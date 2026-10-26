/// Something in a script that's probably a mistake, but doesn't stop it compiling.
public struct Warning: Sendable, Hashable, CustomStringConvertible {
  public let problem: Problem
  public let location: SourceLocation

  /// The problem's message, preceded by its line and column, as in
  /// `3:1: Nothing refers to the production "vowel".`
  public var description: String {
    "\(location.line):\(location.column): \(problem)"
  }
}

extension Warning {
  public enum Problem: Sendable, Hashable, CustomStringConvertible {
    /// No other production refers to a production. The main production is never unused.
    case unusedProduction(String)
    /// No weight or repeat count uses a variable.
    case unusedVariable(String)
    /// No production or other rule set uses a rule set.
    case unusedRuleSet(String)
    /// Text in a pattern, or one alternative of a class in a pattern, needs a character that
    /// nothing in the script produces, so it can never match.
    case cannotMatch(Character)

    public var description: String {
      switch self {
      case .unusedProduction(let name):
        "Nothing refers to the production \"\(name)\"."
      case .unusedVariable(let name):
        "Nothing uses the variable \"$\(name)\"."
      case .unusedRuleSet(let name):
        "Nothing uses the rule set \"@\(name)\"."
      case .cannotMatch(let character):
        "Nothing in the script produces \"\(character)\", so this can never match."
      }
    }
  }
}

extension Compiler {
  /// Finds the warnings in a script that compiled, in source order.
  ///
  /// A production, variable or rule set is used if anything else refers to it, even something
  /// that's unused itself, which has its own warning. Every production may be a place to
  /// start generating, so being unreachable from `_` doesn't make one unused.
  ///
  /// A character can be produced if any literal, spread or replacement in the script has it,
  /// whether or not that part of the script is used, or if joining text can form it.
  func warnings(for definitions: [Definition]) -> [Warning] {
    var usage = Usage()
    for definition in definitions {
      switch definition {
      case .variable:
        break
      case .production(let name, let expression):
        usage.visit(expression.value, in: .production(name.value))
      case .ruleSet(let name, let steps):
        usage.visit(steps, in: .ruleSet(name.value))
      }
    }
    usage.addJoins()

    var warnings: [Warning] = []
    func warn(_ problem: Warning.Problem, at range: Range<String.Index>) {
      warnings.append(Warning(problem: problem, location: SourceLocation(range, in: source)))
    }
    for definition in definitions {
      switch definition {
      case .variable(let name, _) where !usage.variables.contains(name.value):
        warn(.unusedVariable(name.value), at: name.range)
      case .production(let name, _) where !usage.productions.contains(name.value):
        warn(.unusedProduction(name.value), at: name.range)
      case .ruleSet(let name, _) where !usage.ruleSets.contains(name.value):
        warn(.unusedRuleSet(name.value), at: name.range)
      default:
        break
      }
    }
    for pattern in usage.patterns {
      for part in pattern.parts {
        switch part.value {
        case .text(let text):
          if let character = usage.unproducible(in: text) {
            warn(.cannotMatch(character), at: part.range)
          }
        case .choice(let alternatives):
          for alternative in alternatives {
            if let character = usage.unproducible(in: alternative.value) {
              warn(.cannotMatch(character), at: alternative.range)
            }
          }
        case .same:
          break
        }
      }
    }
    return warnings.sorted { $0.location.range.lowerBound < $1.location.range.lowerBound }
  }
}

/// What a script uses, gathered from its syntax tree.
private struct Usage {
  /// The definition being visited, whose references to itself don't count.
  enum Owner {
    case production(String)
    case ruleSet(String)
  }

  /// The main production is always used.
  var productions: Set<String> = [""]
  var variables: Set<String> = []
  var ruleSets: Set<String> = []
  /// Every character that a literal, spread or replacement has, and after `addJoins()`, those
  /// that joining them can form.
  var alphabet: Set<Character> = []
  /// The first character of each piece of text that a literal, spread or replacement adds,
  /// which might join onto the character before it.
  var starts: Set<Character> = []
  var patterns: [PatternSyntax] = []

  /// The grammar limits nesting, so this recursion is bounded.
  mutating func visit(_ expression: Expression, in owner: Owner) {
    switch expression {
    case .literal(let text):
      produce(text)
    case .reference(let name):
      if case .production(name) = owner {
        break
      }
      productions.insert(name)
    case .copy:
      // A copy needs a reference before it, which counts.
      break
    case .spread(let elements):
      for element in elements {
        produce(element)
      }
    case .select(let items):
      visit(items, in: owner)
    case .sequence(let items, let steps):
      visit(items, in: owner)
      visit(steps, in: owner)
    }
  }

  mutating func visit(_ items: [Item], in owner: Owner) {
    for item in items {
      if case .variable(let name) = item.quantifier?.value {
        variables.insert(name)
      }
      visit(item.expression.value, in: owner)
    }
  }

  mutating func visit(_ steps: [Located<RewriteStep>], in owner: Owner) {
    for step in steps {
      switch step.value {
      case .reject(let pattern):
        patterns.append(pattern)
      case .substitute(let pattern, let parts):
        patterns.append(pattern)
        for part in parts {
          switch part.value {
          case .text(let text):
            produce(text)
          case .choice(let alternatives):
            for alternative in alternatives {
              produce(alternative.value)
            }
          case .same:
            // Copies what the pattern matched, which was already in the word.
            break
          }
        }
      case .ruleSet(let name):
        if case .ruleSet(name) = owner {
          break
        }
        ruleSets.insert(name)
      }
    }
  }

  mutating func produce(_ text: String) {
    alphabet.formUnion(text)
    if let first = text.first {
      starts.insert(first)
    }
  }

  /// Adds the characters that joining pieces of text can form. A character can grow when text
  /// is added after it, as "e" and a combining acute accent form "é", or two Hangul jamo form
  /// a syllable, so a pattern can match a character that nothing produces whole.
  ///
  /// Marks can keep joining a character forever, so this stops after a character has had
  /// three pieces joined onto it, which is more than real orthographies stack.
  mutating func addJoins() {
    var latest = alphabet
    for _ in 0..<3 where !latest.isEmpty {
      var formed: Set<Character> = []
      for character in latest {
        for start in starts {
          let joined = String(character) + String(start)
          if joined.count == 1, let formedCharacter = joined.first,
            !alphabet.contains(formedCharacter)
          {
            formed.insert(formedCharacter)
          }
        }
      }
      alphabet.formUnion(formed)
      latest = formed
    }
  }

  /// The first character of `text` that nothing in the script can produce, if any.
  func unproducible(in text: String) -> Character? {
    text.first { !alphabet.contains($0) }
  }
}
