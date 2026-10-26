/// A compiled script, ready to generate words.
///
/// Make one with `Script.compile(overrides:)`, or `init(_:overrides:)` to parse and compile
/// in one step. Every reference in a `Generator` has been resolved and every production can
/// finish, so generation can only fail in the ways described by `GenerationError`.
public struct Generator: Sendable {
  /// The productions, which refer to each other by index.
  let rules: [Node]
  /// The index of the production to start from: `_`, unless `starting(at:)` chose another.
  var main: Int
  /// The index of each production, by name. The main production's name is empty.
  let indices: [String: Int]
  /// Each production's name as it's displayed, by index.
  let names: [String]
  /// The script, so that a trace can say where things are in it.
  let source: String
  /// Things in the script that are probably mistakes, but didn't stop it compiling, in source
  /// order.
  public let warnings: [Warning]

  /// The longest text that a literal, a pattern, a replacement, or anything generated may be.
  public static let maximumLength = 64
  /// The number of steps one word may take. Each reference, each select, and each attempt at
  /// a sequence (including attempts that a skip rejects) is a step.
  public static let maximumSteps = 65_535
  /// The number of skips and substitutions one group or rule set may have, counting those of
  /// the rule sets it uses. Without a limit, rule sets that each use the one before twice would
  /// double with every one.
  public static let maximumRewrites = 1_024
  /// The number of words in a row that `generate(count:distinct:)` may generate without finding
  /// a new one, when it's asked for distinct words, before it gives up.
  public static let maximumDuplicates = 1_000

  /// Parses and compiles `source`. See `Script.compile(overrides:)`.
  public init(_ source: String, overrides: [String: UInt8] = [:]) throws(ScriptError) {
    self = try Script(source).compile(overrides: overrides)
  }

  init(rules: [Node], main: Int, indices: [String: Int], source: String, warnings: [Warning]) {
    self.rules = rules
    self.main = main
    self.indices = indices
    names = indices.sorted { $0.value < $1.value }.map { display($0.key) }
    self.source = source
    self.warnings = warnings
  }

  /// The names of the productions, in the order they're defined, with `_` for the main one.
  public var productions: [String] {
    names
  }

  /// A generator that starts from the production named `name` instead of `_`, or `nil` if
  /// there's no such production. `_` names the main production, since no other can have that
  /// name. Every production can finish, so any of them can be a place to start.
  public func starting(at name: String) -> Generator? {
    // The main production's name is empty, but "" isn't a name that can be written.
    guard !name.isEmpty, let index = indices[name == "_" ? "" : name] else {
      return nil
    }
    var generator = self
    generator.main = index
    return generator
  }

  /// Generates a random word.
  public func generate() throws(GenerationError) -> String {
    var generator = SystemRandomNumberGenerator()
    return try generate(using: &generator)
  }

  /// Generates a random word using `generator` as the source of randomness. With a seeded
  /// generator, the same seed produces the same words.
  public func generate<R: RandomNumberGenerator>(using generator: inout R) throws(GenerationError)
    -> String
  {
    var evaluation = Evaluation(rules: rules, random: generator, observer: Unobserved())
    defer { generator = evaluation.random }
    return try evaluation.produce(main)
  }

  /// Generates a random word, and records how. See `trace(using:)`.
  public func trace() -> Trace {
    var generator = SystemRandomNumberGenerator()
    return trace(using: &generator)
  }

  /// Generates a random word using `generator` as the source of randomness, and records how.
  /// With the same seed, the word is the one that `generate(using:)` would produce.
  ///
  /// Generating can fail, which is often when a trace is most useful, so the trace has the
  /// error instead of throwing it, and what happened before.
  public func trace<R: RandomNumberGenerator>(using generator: inout R) -> Trace {
    let tracer = Tracer(source: source, names: names)
    var evaluation = Evaluation(rules: rules, random: generator, observer: tracer)
    defer { generator = evaluation.random }
    let result: Result<String, GenerationError>
    do {
      result = .success(try evaluation.produce(main))
    } catch {
      result = .failure(error)
    }
    return Trace(result: result, events: evaluation.observer.events)
  }

  /// Generates `count` random words. See `generate(count:distinct:using:)`.
  public func generate(count: Int, distinct: Bool = false) throws(GenerationError) -> [String] {
    var generator = SystemRandomNumberGenerator()
    return try generate(count: count, distinct: distinct, using: &generator)
  }

  /// Generates `count` random words, in the order they were generated, using `generator` as the
  /// source of randomness.
  ///
  /// If `distinct` is true, no word appears twice. A script may not be able to produce that
  /// many different words, or may produce some of them only rarely, so this gives up after
  /// `maximumDuplicates` words in a row that it had already generated, and returns fewer.
  ///
  /// `count` must not be negative. A negative count is a programming error, and stops the
  /// program, as it does for `Array(repeating:count:)`.
  public func generate<R: RandomNumberGenerator>(
    count: Int, distinct: Bool = false, using generator: inout R
  ) throws(GenerationError) -> [String] {
    precondition(count >= 0, "The count of words can't be negative.")
    var words: [String] = []
    var seen: Set<String> = []
    var duplicates = 0
    while words.count < count && duplicates < Generator.maximumDuplicates {
      let word = try generate(using: &generator)
      if !distinct || seen.insert(word).inserted {
        words.append(word)
        duplicates = 0
      } else {
        duplicates += 1
      }
    }
    return words
  }
}

indirect enum Node: Sendable {
  case literal(String)
  case rule(Int)
  /// What an item of a sequence around this node produced. `sequences` counts the sequences in
  /// between, which are the ones above it on the evaluator's stack, and `item` is the item's
  /// index. The compiler only makes one for an item that's finished by the time it's reached.
  case copy(sequences: Int, item: Int)
  case choice(Choice)
  /// A concat, or a select with rewrites, which becomes a concat with the select as its only
  /// item. `range` is the group in the source, for tracing.
  case sequence([Repetition], [Rewrite], range: Range<String.Index>)
}

/// A weighted choice with at least one alternative that can be chosen.
struct Choice: Sendable {
  struct Alternative: Sendable {
    let weight: Int
    let node: Node
  }

  /// Only the alternatives with a positive weight.
  let alternatives: [Alternative]
  let totalWeight: Int

  /// Fails if no alternative has a positive weight.
  init?(_ alternatives: [Alternative]) {
    self.alternatives = alternatives.filter { $0.weight > 0 }
    totalWeight = self.alternatives.reduce(0) { $0 + $1.weight }
    if totalWeight == 0 {
      return nil
    }
  }

  func choose(using generator: inout some RandomNumberGenerator) -> Node {
    var remaining = Int.random(in: 0..<totalWeight, using: &generator)
    for alternative in alternatives {
      if remaining < alternative.weight {
        return alternative.node
      }
      remaining -= alternative.weight
    }
    // Unreachable, since `remaining` started below the sum of the weights.
    return alternatives[alternatives.count - 1].node
  }
}

/// An item in a sequence, produced between 1 and `maximum` times.
struct Repetition: Sendable {
  /// At least 1.
  let maximum: Int
  let node: Node
  /// Whether a copy refers to this item, so that what it produces must be kept.
  var isCopied = false

  /// Fails if `maximum` is less than 1.
  init?(maximum: Int, node: Node) {
    guard maximum >= 1 else {
      return nil
    }
    self.maximum = maximum
    self.node = node
  }

  func count(using random: inout some RandomNumberGenerator) -> Int {
    Int.random(in: 1...maximum, using: &random)
  }
}

/// Generates one word.
///
/// This doesn't recurse, so no grammar can overflow the stack, however deeply it nests. A
/// reference or a select just moves on to the node it leads to, so only sequences need to
/// remember where they are, on `stack`. Each one pushed costs a step, so the step limit bounds
/// the stack too.
///
/// `observer` sees what happens to each sequence, for tracing. When generating without a trace,
/// it's `Unobserved`, whose methods do nothing.
struct Evaluation<R: RandomNumberGenerator, O: Observer> {
  let rules: [Node]
  var random: R
  var observer: O
  var steps = 0

  init(rules: [Node], random: R, observer: O) {
    self.rules = rules
    self.random = random
    self.observer = observer
  }

  /// Produces the production with index `start`.
  mutating func produce(_ start: Int) throws(GenerationError) -> String {
    var stack: [SequenceState] = []
    var node = rules[start]
    // The production that the node was reached through, until something produces text.
    var production: Int? = start
    while true {
      // Go down until something produces text.
      var text: String
      switch node {
      case .literal(let literal):
        text = literal
      case .copy(let sequences, let item):
        // The item is finished and marked as copied, so what it produced has been kept.
        text = stack[stack.count - 1 - sequences].produced[item]!
      case .rule(let index):
        try step()
        node = rules[index]
        production = index
        continue
      case .choice(let choice):
        try step()
        node = choice.choose(using: &random)
        continue
      case .sequence(let repetitions, let rewrites, let range):
        try step()
        observer.started(range, production: production, depth: stack.count)
        production = nil
        var state = SequenceState(repetitions: repetitions, rewrites: rewrites)
        node = state.start(using: &random)
        stack.append(state)
        continue
      }
      production = nil
      // Give the text to the innermost sequence. If it needs more, go down again. If it's
      // finished, its word is the text for the sequence around it.
      while var state = stack.popLast() {
        if let next = try state.append(text, using: &random) {
          node = next
          stack.append(state)
          break
        }
        if let word = try state.rewrite(observer: &observer, depth: stack.count) {
          observer.finished(word, depth: stack.count)
          text = word
        } else {
          try step()
          node = state.start(using: &random)
          stack.append(state)
          break
        }
      }
      if stack.isEmpty {
        return text
      }
    }
  }

  private mutating func step() throws(GenerationError) {
    steps += 1
    if steps > Generator.maximumSteps {
      throw .tooManySteps
    }
  }
}

/// How far a sequence has got.
struct SequenceState {
  let repetitions: [Repetition]
  let rewrites: [Rewrite]
  /// The index of the item being produced.
  var item = 0
  /// How many more times to produce it, including the one in progress.
  var remaining = 0
  var word = ""
  /// What each finished item that a copy refers to produced.
  var produced: [Int: String] = [:]
  /// What the current item has produced so far, if a copy refers to it.
  var current = ""

  init(repetitions: [Repetition], rewrites: [Rewrite]) {
    self.repetitions = repetitions
    self.rewrites = rewrites
  }

  /// Starts a new attempt and returns the first node to produce. The grammar requires at
  /// least one item.
  mutating func start(using random: inout some RandomNumberGenerator) -> Node {
    item = 0
    remaining = repetitions[0].count(using: &random)
    word = ""
    produced = [:]
    current = ""
    return repetitions[0].node
  }

  /// Adds what the current node produced, and returns the next node to produce, or `nil`
  /// if every item has been produced.
  mutating func append(_ text: String, using random: inout some RandomNumberGenerator)
    throws(GenerationError) -> Node?
  {
    word += text
    if repetitions[item].isCopied {
      current += text
    }
    try checkLength(of: word)
    remaining -= 1
    if remaining == 0 {
      if repetitions[item].isCopied {
        produced[item] = current
        current = ""
      }
      item += 1
      guard item < repetitions.count else {
        return nil
      }
      remaining = repetitions[item].count(using: &random)
    }
    return repetitions[item].node
  }

  /// Applies the skips and substitutions to the finished word. Returns the result, or `nil`
  /// if a skip rejected it.
  func rewrite(observer: inout some Observer, depth: Int) throws(GenerationError) -> String? {
    var word = Word(word)
    for rewrite in rewrites {
      switch rewrite.action {
      case .reject(let pattern):
        if pattern.matches(&word) {
          observer.rejected(word.text, by: rewrite.range, depth: depth)
          return nil
        }
      case .substitute(let pattern, let replacement):
        if let substituted = pattern.substitute(replacement, in: &word) {
          observer.substituted(word.text, with: substituted, by: rewrite.range, depth: depth)
          try checkLength(of: substituted)
          word = Word(substituted)
        }
      }
    }
    return word.text
  }

  private func checkLength(of text: String) throws(GenerationError) {
    if text.count > Generator.maximumLength {
      throw .tooLong(text)
    }
  }
}
