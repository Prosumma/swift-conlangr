/// How a word was generated, to show why a script produces what it does. Make one with
/// `Generator.trace(using:)`.
///
/// The events follow each group, meaning each concat and each select with rewrites, as it starts,
/// as its skips and substitutions apply, and as it finishes. Literals, references and plain
/// selects only show up in what the groups around them produce.
public struct Trace: Sendable, Hashable {
  /// The word, or why generating it failed.
  public let result: Result<String, GenerationError>
  /// What happened, in order, up to the word or the failure.
  public let events: [Event]
}

extension Trace {
  public struct Event: Sendable, Hashable {
    /// How many groups the event's group is inside. A group's events, and the groups inside it,
    /// come between its `started` and its `finished`.
    public let depth: Int
    public let kind: Kind
  }

  public enum Kind: Sendable, Hashable {
    /// A group started. `production` is the production it was reached through, if any: the one
    /// it's the body of, or the one whose select chose it.
    case started(production: String?, location: SourceLocation)
    /// A skip rejected the group's word, so the group starts again from its first item.
    case rejected(word: String, location: SourceLocation)
    /// A substitution changed the group's word.
    case substituted(from: String, to: String, location: SourceLocation)
    /// The group finished, with its skips and substitutions applied.
    case finished(word: String)
  }
}

/// What tracing needs to know while generating.
protocol Observer {
  mutating func started(_ range: Range<String.Index>, production: Int?, depth: Int)
  mutating func rejected(_ word: String, by range: Range<String.Index>, depth: Int)
  mutating func substituted(
    _ word: String, with substituted: String, by range: Range<String.Index>, depth: Int)
  mutating func finished(_ word: String, depth: Int)
}

/// Sees nothing, for generating without a trace. Once `Evaluation` is specialized for it, it
/// costs nothing.
struct Unobserved: Observer {
  func started(_ range: Range<String.Index>, production: Int?, depth: Int) {}
  func rejected(_ word: String, by range: Range<String.Index>, depth: Int) {}
  func substituted(
    _ word: String, with substituted: String, by range: Range<String.Index>, depth: Int
  ) {}
  func finished(_ word: String, depth: Int) {}
}

/// Records what happens, for `Generator.trace(using:)`.
struct Tracer: Observer {
  let source: String
  let names: [String]
  var events: [Trace.Event] = []
  /// Finding a line and column means scanning the source, and the same groups and rewrites come
  /// up again and again, so their locations are kept.
  var locations: [Range<String.Index>: SourceLocation] = [:]

  init(source: String, names: [String]) {
    self.source = source
    self.names = names
  }

  mutating func started(_ range: Range<String.Index>, production: Int?, depth: Int) {
    let name = production.map { names[$0] }
    record(.started(production: name, location: location(of: range)), depth: depth)
  }

  mutating func rejected(_ word: String, by range: Range<String.Index>, depth: Int) {
    record(.rejected(word: word, location: location(of: range)), depth: depth)
  }

  mutating func substituted(
    _ word: String, with substituted: String, by range: Range<String.Index>, depth: Int
  ) {
    record(.substituted(from: word, to: substituted, location: location(of: range)), depth: depth)
  }

  mutating func finished(_ word: String, depth: Int) {
    record(.finished(word: word), depth: depth)
  }

  private mutating func record(_ kind: Trace.Kind, depth: Int) {
    events.append(Trace.Event(depth: depth, kind: kind))
  }

  private mutating func location(of range: Range<String.Index>) -> SourceLocation {
    if let location = locations[range] {
      return location
    }
    let location = SourceLocation(range, in: source)
    locations[range] = location
    return location
  }
}
