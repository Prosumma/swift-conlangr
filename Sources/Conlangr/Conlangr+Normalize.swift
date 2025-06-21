extension ParseProduction {
  func normalize(with variables: [String: UInt8]) -> Production {
    switch self {
    case let .literal(literal):
      return .literal(literal)
    case let .ref(ref):
      return .ref(ref)
    case let .spread(values):
      return .select([1], [1: Set(values.map(Production.literal))])
    case let .select(quantifiedProductions):
      var array: [UInt8] = []
      var dictionary: [UInt8: Set<Production>] = [:]
      for quantifiedProduction in quantifiedProductions {
        let quantity = switch quantifiedProduction.0 {
          case let .numeric(num): num
          case let .variable(variable): variables[variable] ?? 1
        }
        array.append(contentsOf: Array(repeating: quantity, count: Int(quantity)))
        dictionary[quantity] = dictionary[quantity] ?? []
        dictionary[quantity]?.insert(quantifiedProduction.1.normalize(with: variables))
      }
      return .select(array, dictionary)
    case let .concat(quantifiedProductions, rewrites):
      var result: [QuantifiedProduction] = []
      for quantifiedProduction in quantifiedProductions {
        let quantity = switch quantifiedProduction.0 {
          case let .numeric(num): num
          case let .variable(variable): variables[variable] ?? 1
        }
        let quantifiedProduction = QuantifiedProduction(
          quantity: quantity,
          production: quantifiedProduction.1.normalize(with: variables)
        )
        result.append(quantifiedProduction)
      }
      return .concat(result, rewrites)
    }
  }
}


extension Script {
  func normalize(with overrides: [String: UInt8] = [:]) throws -> Generator {
    var variables = variables
    variables.merge(overrides) { _, b in b } 
    print(variables)
    let normalized = productions.mapValues { $0.normalize(with: variables) }
    if !normalized.keys.contains("") {
      throw ScriptError.noMain
    }
    return Generator(productions: normalized)
  }
}