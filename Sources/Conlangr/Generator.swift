/// A compiled script, ready to generate words.
///
/// Make one with `Script.compile(overrides:)`, or `init(_:overrides:)` to parse and compile
/// in one step. Every reference in a `Generator` has been resolved and every production can
/// finish, so generation can only fail in the ways described by `GenerationError`.
public struct Generator: Sendable {
  /// The productions, which refer to each other by index.
  let rules: [Node]
  /// The index of `_`.
  let main: Int

  /// The longest text that a literal, a pattern, a replacement, or anything generated may be.
  public static let maximumLength = 64
  /// The number of steps one word may take. Each reference, each select, and each attempt at
  /// a sequence (including attempts that a skip rejects) is a step.
  public static let maximumSteps = 65_535
  /// The number of skips and substitutions one sequence may have, counting those of the rule
  /// sets it uses. Without a limit, rule sets that each use the one before twice would double
  /// with every one.
  public static let maximumRewrites = 1_024

  /// Parses and compiles `source`. See `Script.compile(overrides:)`.
  public init(_ source: String, overrides: [String: UInt8] = [:]) throws(ScriptError) {
    self = try Script(source).compile(overrides: overrides)
  }

  init(rules: [Node], main: Int) {
    self.rules = rules
    self.main = main
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
    var evaluation = Evaluation(rules: rules, random: generator)
    defer { generator = evaluation.random }
    return try evaluation.produce(rules[main])
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
  case sequence([Repetition], [Rewrite])
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
struct Evaluation<R: RandomNumberGenerator> {
  let rules: [Node]
  var random: R
  var steps = 0

  init(rules: [Node], random: R) {
    self.rules = rules
    self.random = random
  }

  mutating func produce(_ root: Node) throws(GenerationError) -> String {
    var stack: [SequenceState] = []
    var node = root
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
        continue
      case .choice(let choice):
        try step()
        node = choice.choose(using: &random)
        continue
      case .sequence(let repetitions, let rewrites):
        try step()
        var state = SequenceState(repetitions: repetitions, rewrites: rewrites)
        node = state.start(using: &random)
        stack.append(state)
        continue
      }
      // Give the text to the innermost sequence. If it needs more, go down again. If it's
      // finished, its word is the text for the sequence around it.
      while var state = stack.popLast() {
        if let next = try state.append(text, using: &random) {
          node = next
          stack.append(state)
          break
        }
        if let word = try state.rewrite() {
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
  func rewrite() throws(GenerationError) -> String? {
    var word = Word(word)
    for rewrite in rewrites {
      switch rewrite {
      case .reject(let pattern):
        if pattern.matches(&word) {
          return nil
        }
      case .substitute(let pattern, let replacement):
        if let substituted = pattern.substitute(replacement, in: &word) {
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
