import Parsimonious

/// A parsed script, not yet compiled.
///
/// Parsing checks only the syntax. `compile(overrides:)` checks everything else, such as
/// whether every reference is defined, and produces a `Generator`.
public struct Script: Sendable {
  let source: String
  let definitions: [Definition]

  /// How deeply groups may be nested within one definition.
  ///
  /// The parser is recursive, so this keeps it from overflowing the stack. Twelve is about half
  /// the depth that overflowed a 512 KB stack, the size of a secondary thread's, in a debug
  /// build. Deeper structure is still possible: a reference doesn't nest, so give inner groups
  /// their own names.
  public static let maximumNesting = 12

  /// Parses `source`, throwing a `ScriptError` with a single diagnostic if it doesn't follow
  /// the grammar, or nests groups more than `maximumNesting` deep.
  public init(_ source: String) throws(ScriptError) {
    try Script.checkNesting(of: source)
    do {
      definitions = try parse(source, with: Grammar.script)
    } catch {
      let index = error.slice.endIndex
      let end = index < source.endIndex ? source.index(after: index) : index
      let location = SourceLocation(index..<end, in: source)
      let problem = Diagnostic.Problem.syntax(error.message ?? "Syntax error.")
      throw ScriptError(diagnostics: [Diagnostic(problem: problem, location: location)])
    }
    self.source = source
  }

  /// Throws if groups in `source` are nested too deeply to parse safely. This uses the
  /// tokenizer, which doesn't recurse.
  static func checkNesting(of source: String) throws(ScriptError) {
    var depth = 0
    for token in tokenize(source) where token.kind == .parens {
      if token.value == "(" {
        depth += 1
        if depth > maximumNesting {
          let location = SourceLocation(token.range, in: source)
          throw ScriptError(diagnostics: [Diagnostic(problem: .nestedTooDeeply, location: location)]
          )
        }
      } else {
        depth = max(depth - 1, 0)
      }
    }
  }

  /// The variables the script declares, with their values. A variable whose value is out of
  /// range is left out, since compiling would report it.
  public var variables: [String: UInt8] {
    var variables: [String: UInt8] = [:]
    for case .variable(let name, let value) in definitions {
      if variables[name.value] == nil, let value = UInt8(value.value) {
        variables[name.value] = value
      }
    }
    return variables
  }

  /// Checks the script and compiles it into a `Generator`.
  ///
  /// `overrides` replaces the values of variables the script declares. It's an error to
  /// override a variable the script doesn't declare; see `variables` for the ones it does.
  ///
  /// Throws a `ScriptError` listing every problem found, in source order.
  public func compile(overrides: [String: UInt8] = [:]) throws(ScriptError) -> Generator {
    var compiler = Compiler(source: source)
    return try compiler.compile(definitions, overrides: overrides)
  }
}

struct Compiler {
  let source: String
  var diagnostics: [Diagnostic] = []
  /// Every declared variable, including any whose value is invalid.
  var declared: Set<String> = []
  /// The value of each declared variable whose value is valid.
  var variables: [String: UInt8] = [:]
  var indices: [String: Int] = [:]

  init(source: String) {
    self.source = source
  }

  mutating func compile(_ definitions: [Definition], overrides: [String: UInt8])
    throws(ScriptError) -> Generator
  {
    var productions: [Located<Expression>] = []
    // Duplicates aren't used, but they're still checked, so every problem is reported at once.
    var duplicates: [Located<Expression>] = []
    for definition in definitions {
      switch definition {
      case .variable(let name, let value):
        let number = number(value)
        guard declared.insert(name.value).inserted else {
          report(.duplicateVariable(name.value), at: name.range)
          continue
        }
        variables[name.value] = number
      case .production(let name, let expression):
        guard indices[name.value] == nil else {
          report(.duplicateProduction(name.value), at: name.range)
          duplicates.append(expression)
          continue
        }
        indices[name.value] = productions.count
        productions.append(expression)
      }
    }
    for (name, value) in overrides.sorted(by: { $0.key < $1.key }) {
      if declared.contains(name) {
        variables[name] = value
      } else {
        report(.unknownOverride(name))
      }
    }
    let main = indices[""]
    if main == nil {
      report(.missingMain)
    }

    let rules = productions.map { lower($0) }
    for duplicate in duplicates {
      _ = lower(duplicate)
    }
    if diagnostics.isEmpty {
      checkTermination(of: rules, definitions: definitions)
    }

    guard diagnostics.isEmpty, let main else {
      throw ScriptError(diagnostics: diagnostics.sorted(by: Compiler.sourceOrder))
    }
    return Generator(rules: rules, main: main)
  }

  // MARK: Lowering

  /// Lowers an expression, reporting any problems. If there are problems, the result is
  /// only a placeholder, and `compile` throws instead of using it.
  mutating func lower(_ expression: Located<Expression>) -> Node {
    switch expression.value {
    case .literal(let text):
      checkLength(of: text, at: expression.range)
      return .literal(text)
    case .reference(let name):
      guard let index = indices[name] else {
        report(.undefinedProduction(name), at: expression.range)
        return .literal("")
      }
      return .rule(index)
    case .spread(let elements):
      let alternatives = elements.map { Choice.Alternative(weight: 1, node: .literal($0)) }
      // The grammar requires at least one element, so this always succeeds.
      return Choice(alternatives).map { .choice($0) } ?? .literal("")
    case .select(let items):
      let alternatives = items.map { item in
        Choice.Alternative(weight: Int(quantity(of: item) ?? 1), node: lower(item.expression))
      }
      guard let choice = Choice(alternatives) else {
        report(.noChoosableAlternative, at: expression.range)
        return .literal("")
      }
      return .choice(choice)
    case .sequence(let items, let steps):
      let repetitions = items.compactMap { item -> Repetition? in
        let count = quantity(of: item)
        let node = lower(item.expression)
        guard let count else {
          return nil
        }
        guard let repetition = Repetition(maximum: Int(count), node: node) else {
          let quantifier = item.quantifier
          let variable: String? =
            if case .variable(let name) = quantifier?.value { name } else { nil }
          report(.zeroRepeatCount(variable: variable), at: quantifier?.range)
          return nil
        }
        return repetition
      }
      for step in steps {
        switch step.value {
        case .reject(let pattern):
          check(pattern, at: step.range)
        case .substitute(let pattern, let replacement):
          check(pattern, at: step.range)
          checkLength(of: replacement, at: step.range)
        }
      }
      // An invalid item was dropped and reported. Don't build a sequence without it, since
      // the generator assumes a sequence has every item, and at least one.
      guard repetitions.count == items.count else {
        return .literal("")
      }
      return .sequence(repetitions, steps.map(\.value))
    }
  }

  /// The item's weight or repeat count, or `nil` if it's invalid, which has been reported.
  mutating func quantity(of item: Item) -> UInt8? {
    guard let quantifier = item.quantifier else {
      return 1
    }
    switch quantifier.value {
    case .number(let digits):
      return number(Located(digits, source[quantifier.range]))
    case .variable(let name):
      guard declared.contains(name) else {
        report(.undefinedVariable(name), at: quantifier.range)
        return nil
      }
      // `nil` if the declared value is invalid, which has been reported where it's declared.
      return variables[name]
    }
  }

  mutating func number(_ digits: Located<String>) -> UInt8? {
    guard let number = UInt8(digits.value) else {
      report(.numberTooLarge(digits.value), at: digits.range)
      return nil
    }
    return number
  }

  mutating func check(_ pattern: Pattern, at range: Range<String.Index>) {
    if pattern.text.isEmpty && pattern.position != .whole {
      report(.emptyPattern, at: range)
    }
    checkLength(of: pattern.text, at: range)
  }

  mutating func checkLength(of text: String, at range: Range<String.Index>) {
    if text.count > Generator.maximumLength {
      report(.textTooLong(text), at: range)
    }
  }

  // MARK: Termination

  /// Reports the productions that can't produce anything.
  ///
  /// A production can finish if it's a literal, a reference to a production that can finish,
  /// a select with an alternative that can finish, or a sequence whose items can all finish.
  /// Starting from the literals, this finds every production that can finish, and the rest
  /// can't. A production that can finish might still be unlikely to, if it refers to itself
  /// often enough, which `Generator.maximumSteps` guards against.
  ///
  /// Only the productions in a cycle are reported. The others can't finish only because they
  /// refer to one of those, and fixing the cycle fixes them.
  mutating func checkTermination(of rules: [Node], definitions: [Definition]) {
    var finishes = Array(repeating: false, count: rules.count)
    func canFinish(_ node: Node) -> Bool {
      switch node {
      case .literal: true
      case .rule(let index): finishes[index]
      case .choice(let choice): choice.alternatives.contains { canFinish($0.node) }
      case .sequence(let repetitions, _): repetitions.allSatisfy { canFinish($0.node) }
      }
    }
    var changed = true
    while changed {
      changed = false
      for (index, rule) in rules.enumerated() where !finishes[index] && canFinish(rule) {
        finishes[index] = true
        changed = true
      }
    }

    func references(_ node: Node) -> [Int] {
      switch node {
      case .literal: []
      case .rule(let index): finishes[index] ? [] : [index]
      case .choice(let choice): choice.alternatives.flatMap { references($0.node) }
      case .sequence(let repetitions, _): repetitions.flatMap { references($0.node) }
      }
    }
    func isInCycle(_ start: Int) -> Bool {
      var visited: Set<Int> = []
      var pending = references(rules[start])
      while let index = pending.popLast() {
        if index == start {
          return true
        }
        if visited.insert(index).inserted {
          pending += references(rules[index])
        }
      }
      return false
    }
    for case .production(let name, _) in definitions {
      // Duplicates were already reported, so only the first definition of a name has an index.
      if let index = indices[name.value], !finishes[index], isInCycle(index) {
        report(.neverFinishes(name.value), at: name.range)
      }
    }
  }

  // MARK: Diagnostics

  mutating func report(_ problem: Diagnostic.Problem, at range: Range<String.Index>? = nil) {
    let location = range.map { SourceLocation($0, in: source) }
    diagnostics.append(Diagnostic(problem: problem, location: location))
  }

  /// Located diagnostics in source order, then the rest in the order they were reported.
  static func sourceOrder(_ a: Diagnostic, _ b: Diagnostic) -> Bool {
    switch (a.location, b.location) {
    case (let a?, let b?): a.range.lowerBound < b.range.lowerBound
    case (.some, nil): true
    case (nil, _): false
    }
  }
}
