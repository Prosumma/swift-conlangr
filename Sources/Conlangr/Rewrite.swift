/// A compiled skip or substitution.
enum Rewrite: Sendable {
  case reject(Pattern)
  case substitute(Pattern, Replacement)
}

/// A compiled pattern.
///
/// Its elements are text, classes, and repeats of an earlier class. A class tries its longest
/// alternatives first, and matching backtracks, so `{t tl}l` matches both "tl" and "tll".
struct Pattern: Sendable {
  enum Position: Sendable, Hashable {
    /// `abc`: the whole word.
    case whole
    /// `abc*`
    case prefix
    /// `*abc`
    case suffix
    /// `*abc*`
    case anywhere
  }

  enum Element: Sendable {
    case text([Character])
    /// The class with this index in `classes`.
    case choice(Int)
    /// The same text that the class with this index matched.
    case repeated(Int)
  }

  /// The alternatives of one class, and the order to try them in: longest first.
  struct Class: Sendable {
    let alternatives: [[Character]]
    let order: [Int]

    init(_ alternatives: [String]) {
      let alternatives = alternatives.map(Array.init)
      self.alternatives = alternatives
      order = alternatives.indices.sorted { alternatives[$0].count > alternatives[$1].count }
    }
  }

  /// Where a pattern matched, and which alternative of each class it matched.
  struct Match {
    let range: Range<Int>
    let choices: [Int]
  }

  let position: Position
  let elements: [Element]
  let classes: [Class]
  /// If the pattern is only text, the text, which String's own methods can match faster.
  private let plain: String?
  /// The characters a match can start with.
  private let starts: Set<Character>

  init(position: Position, elements: [Element], classes: [Class]) {
    self.position = position
    self.elements = elements
    self.classes = classes
    switch elements.first {
    case .text(let text) where elements.count == 1:
      plain = String(text)
      starts = []
    case .text(let text):
      plain = nil
      starts = Set(text.prefix(1))
    case .choice(let index):
      plain = nil
      starts = Set(classes[index].alternatives.compactMap(\.first))
    case .repeated, nil:
      // A pattern can't start with a repeat, and an empty one only matches the empty word.
      plain = elements.isEmpty ? "" : nil
      starts = []
    }
  }

  func matches(_ word: inout Word) -> Bool {
    if let plain {
      let text = word.text
      return switch position {
      case .whole: text == plain
      case .prefix: text.hasPrefix(plain)
      case .suffix: text.hasSuffix(plain)
      case .anywhere: text.contains(plain)
      }
    }
    return firstMatch(in: word.characters) != nil
  }

  /// The word with every match replaced, or `nil` if the pattern doesn't match.
  ///
  /// Anywhere in the word, matches are found from left to right and don't overlap.
  func substitute(_ replacement: Replacement, in word: inout Word) -> String? {
    if let plain {
      guard matches(&word) else {
        return nil
      }
      // With no classes, the replacement is always the same text.
      let text = replacement.text(for: [])
      let word = word.text
      return switch position {
      case .whole: text
      case .prefix: text + word.dropFirst(plain.count)
      case .suffix: word.dropLast(plain.count) + text
      case .anywhere: word.replacing(plain, with: text)
      }
    }
    let characters = word.characters
    guard position == .anywhere else {
      guard let match = firstMatch(in: characters) else {
        return nil
      }
      return String(characters[..<match.range.lowerBound]) + replacement.text(for: match.choices)
        + String(characters[match.range.upperBound...])
    }
    var result = ""
    var matched = false
    var i = 0
    while i < characters.count {
      // The compiler ensures a pattern that can match anywhere can't match nothing.
      if starts.contains(characters[i]), let match = match(characters, from: i, to: nil) {
        result += replacement.text(for: match.choices)
        i = match.range.upperBound
        matched = true
      } else {
        result.append(characters[i])
        i += 1
      }
    }
    return matched ? result : nil
  }

  private func firstMatch(in characters: [Character]) -> Match? {
    switch position {
    case .whole: match(characters, from: 0, to: characters.count)
    case .prefix: match(characters, from: 0, to: nil)
    case .suffix:
      characters.indices.lazy.filter { starts.contains(characters[$0]) }
        .compactMap { match(characters, from: $0, to: characters.count) }.first
    case .anywhere:
      characters.indices.lazy.filter { starts.contains(characters[$0]) }
        .compactMap { match(characters, from: $0, to: nil) }.first
    }
  }

  /// Matches the elements starting at `start`, ending at `end` if it's given.
  private func match(_ characters: [Character], from start: Int, to end: Int?) -> Match? {
    var choices = Array(repeating: 0, count: classes.count)
    guard let upper = match(characters, element: 0, at: start, to: end, choices: &choices) else {
      return nil
    }
    return Match(range: start..<upper, choices: choices)
  }

  private func match(
    _ characters: [Character], element: Int, at position: Int, to end: Int?, choices: inout [Int]
  ) -> Int? {
    guard element < elements.count else {
      return end == nil || end == position ? position : nil
    }
    func next(_ text: [Character]) -> Int? {
      guard characters[position...].starts(with: text) else {
        return nil
      }
      return match(
        characters, element: element + 1, at: position + text.count, to: end, choices: &choices)
    }
    switch elements[element] {
    case .text(let text):
      return next(text)
    case .choice(let index):
      for alternative in classes[index].order {
        choices[index] = alternative
        if let upper = next(classes[index].alternatives[alternative]) {
          return upper
        }
      }
      return nil
    case .repeated(let index):
      return next(classes[index].alternatives[choices[index]])
    }
  }
}

/// A word being rewritten. Its characters are worked out once, for all the patterns that need them.
struct Word {
  let text: String
  private var cached: [Character]?

  init(_ text: String) {
    self.text = text
  }

  var characters: [Character] {
    mutating get {
      if let cached {
        return cached
      }
      let characters = Array(text)
      cached = characters
      return characters
    }
  }
}

/// A compiled replacement: text, and classes that each map the alternative matched by a class in
/// the pattern to their own alternative in the same position.
struct Replacement: Sendable {
  enum Element: Sendable {
    case text(String)
    /// Maps the alternative matched by the pattern's class with this index. There's one
    /// alternative here for each of that class's.
    case choice(Int, [String])
  }

  let elements: [Element]

  /// The length of the longest text the replacement can produce. The classes that pair with the
  /// same class in the pattern choose together.
  var longest: Int {
    var text = 0
    // For each class in the pattern, the length of what the replacement's classes produce for
    // each of its alternatives.
    var paired: [Int: [Int]] = [:]
    for element in elements {
      switch element {
      case .text(let string):
        text += string.count
      case .choice(let index, let alternatives):
        let lengths = alternatives.map(\.count)
        paired[index] = paired[index].map { zip($0, lengths).map(+) } ?? lengths
      }
    }
    return text + paired.values.map { $0.max() ?? 0 }.reduce(0, +)
  }

  func text(for choices: [Int]) -> String {
    elements.map { element in
      switch element {
      case .text(let text): text
      case .choice(let index, let alternatives): alternatives[choices[index]]
      }
    }.joined()
  }
}
