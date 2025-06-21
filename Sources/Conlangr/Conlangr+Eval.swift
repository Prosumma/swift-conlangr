public enum EvaluationError: Error, Equatable {
  case evaluationCountExceeded
  case refNotFound(String)
  case generatedStringTooLong(String)
}

public final class EvaluationContext {
  public private(set) var evaluationCount: UInt16 = 0
  public let productions: [String: Production]

  public init(productions: [String: Production]) {
    self.productions = productions
  }

  public func eval() throws {
    evaluationCount += 1
    if evaluationCount == UInt16.max {
      throw EvaluationError.evaluationCountExceeded
    }
  }
}

public extension QuantifiedProduction {
  func eval(with context: EvaluationContext) throws -> String {
    var produced = ""
    let r = UInt8.random(in: 1...quantity)
    for _ in 0..<r {
      produced += try production.eval(with: context)
    }
    return produced
  }
}

public extension Production {
  func eval(with context: EvaluationContext) throws -> String {
    switch self {
    case let .literal(literal):
      if literal.count > Production.maximumStringLength {
        throw EvaluationError.generatedStringTooLong(literal)
      }
      return literal
    case let .ref(ref):
      try context.eval()
      guard let production = context.productions[ref] else {
        throw EvaluationError.refNotFound(ref)
      }
      return try assertLength(of: production.eval(with: context))
    case let .select(choices, productions):
      try context.eval()
      let n = choices.randomElement()!
      return try assertLength(of: productions[n]!.randomElement()!.eval(with: context))
    case let .concat(quantifiedProductions, rewrites):
      var produced = ""
      RETRY: while true {
        try context.eval()
        produced = ""
        for quantifiedProduction in quantifiedProductions {
          produced += try assertLength(of: quantifiedProduction.eval(with: context))
        }
        for rewrite in rewrites {
          switch rewrite {
          case let .skips(skips):
            for skip in skips {
              if skip.shouldSkip(produced) {
                continue RETRY
              }
            }
          case let .substitutions(substitutions):
            for substitution in substitutions {
              if let substituted = substitution.substitute(in: produced) {
                produced = try assertLength(of: substituted)
              }
            }
          }
        }
        break 
      }
      return try assertLength(of: produced)
    }
  }
}

private func assertLength(of string: String) throws -> String {
  guard string.count < Production.maximumStringLength else {
    throw EvaluationError.generatedStringTooLong(string)
  }
  return string
}

public extension Generator {
  func eval() throws -> String {
    let context = EvaluationContext(productions: productions)
    return try productions[""]!.eval(with: context)
  }
}