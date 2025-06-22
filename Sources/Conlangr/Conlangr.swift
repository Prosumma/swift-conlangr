public enum Production: Hashable, Sendable {
  static let maximumStringLength = 64

  case literal(String)
  case ref(String)
  case select([UInt8], [UInt8: Set<Production>])
  case concat([QuantifiedProduction], [Rewrite])  
}

public struct QuantifiedProduction: Hashable, Sendable {
  public let quantity: UInt8
  public let production: Production
}

public enum MatchMode: Hashable, Sendable {
  case exact, all, atStart, atEnd 
}

public struct Substitution: Hashable, Sendable {
  public let mode: MatchMode
  public let from: String
  public let to: String

  public func substitute(in input: String) -> String? {
    var result = input
    switch mode {
    case .exact where from == input:
      result = to 
    case .all where input.contains(from):
      result.replace(from, with: to)
    case .atStart where input.hasPrefix(from):
      result.removeFirst(from.count)
      result = to + result
    case .atEnd where input.hasSuffix(from):
      result.removeLast(from.count)
      result += to 
    default: // Note this special case
      return nil 
    }
    return result
  }
}

public struct Skip: Hashable, Sendable {
  public let mode: MatchMode
  public let model: String
  
  @Sendable
  public init(mode: MatchMode, model: String) {
    self.mode = mode
    self.model = model
  }

  public func shouldSkip(_ input: String) -> Bool {
    switch mode {
    case .exact: model == input
    case .all: input.contains(model)
    case .atStart: input.hasPrefix(model)
    case .atEnd: input.hasSuffix(model)
    }
  }
}

public enum Rewrite: Hashable, Sendable {
  case skips(Set<Skip>)
  case substitutions([Substitution])
}

public struct Generator {
  let productions: [String: Production]
}
