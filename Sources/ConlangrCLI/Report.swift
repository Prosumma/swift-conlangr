import Conlangr

/// How the command line shows diagnostics, warnings and traces.
enum Report {
  /// A message in the form editors and terminals recognize: `path:line:column: severity: message`.
  static func line(
    _ path: String, _ location: SourceLocation?, _ severity: String, _ message: String
  ) -> String {
    guard let location else {
      return "\(path): \(severity): \(message)"
    }
    return "\(path):\(location.line):\(location.column): \(severity): \(message)"
  }

  static func diagnostics(_ error: ScriptError, path: String) -> [String] {
    error.diagnostics.map { line(path, $0.location, "error", $0.problem.description) }
  }

  static func warnings(_ warnings: [Warning], path: String) -> [String] {
    warnings.map { line(path, $0.location, "warning", $0.problem.description) }
  }

  /// Each event on a line of its own. A group's own events, and the groups inside it, are
  /// indented under it.
  static func trace(_ trace: Trace, source: String) -> [String] {
    trace.events.map { event in
      let indent = String(repeating: "  ", count: event.depth)
      switch event.kind {
      case .started(let production, let location):
        // An unnamed group is shown by how it starts: "(+" or "(?".
        let name = production ?? "\(source[location.range].prefix(2)) …)"
        return "\(indent)\(name)  \(at(location))"
      case .rejected(let word, let location):
        return "\(indent)  - \(word)  rejected by \(source[location.range]) \(at(location))"
      case .substituted(let from, let to, let location):
        return "\(indent)  > \(from) → \(to)  by \(source[location.range]) \(at(location))"
      case .finished(let word):
        return "\(indent)  = \(word)"
      }
    }
  }

  private static func at(_ location: SourceLocation) -> String {
    "(\(location.line):\(location.column))"
  }
}
