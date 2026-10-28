import Conlangr
import Foundation
import Testing

/// The example grammars in `Examples`, one `.conlangr` file each, by name.
let examples = [
  "Quenya", "Sindarin", "OldNorse", "IndoEuropean", "Polynesian", "Sinitic", "DineBizaad",
  "Klingon", "Sumerian", "Thelimu",
]

/// The package's `Examples` directory.
let examplesDirectory = URL(filePath: #filePath)
  .deletingLastPathComponent()  // ConlangrTests
  .deletingLastPathComponent()  // Tests
  .deletingLastPathComponent()  // the package
  .appending(path: "Examples")

/// The source of the example grammar `name`, from `Examples/<name>.conlangr`.
func example(_ name: String) throws -> String {
  try String(contentsOf: examplesDirectory.appending(path: "\(name).conlangr"), encoding: .utf8)
}

/// A small seeded generator, so that tests which sample many words are deterministic.
struct SplitMix64: RandomNumberGenerator {
  var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

/// Generates `count` words from `source` and tallies them.
func tally(
  _ source: String,
  overrides: [String: UInt8] = [:],
  count: Int = 10_000,
  seed: UInt64 = 1
) throws -> [String: Int] {
  let generator = try Generator(source, overrides: overrides)
  var random = SplitMix64(seed: seed)
  var tally: [String: Int] = [:]
  for _ in 0..<count {
    tally[try generator.generate(using: &random), default: 0] += 1
  }
  return tally
}

/// The set of words `source` generates, sampled enough times to see them all.
func words(_ source: String, overrides: [String: UInt8] = [:]) throws -> Set<String> {
  Set(try tally(source, overrides: overrides, count: 2_000).keys)
}

/// Generates a single word from `source`.
func word(_ source: String) throws -> String {
  var random = SplitMix64(seed: 1)
  return try Generator(source).generate(using: &random)
}

/// Whether `count` out of `total` is within 5% of `expected`, a fraction of `total`.
func near(_ count: Int?, _ expected: Double, of total: Int = 10_000) -> Bool {
  abs(Double(count ?? 0) / Double(total) - expected) < 0.05
}

/// The diagnostics from parsing and compiling `source`, or `[]` if it compiles.
func diagnostics(_ source: String, overrides: [String: UInt8] = [:]) -> [Diagnostic] {
  do {
    _ = try Generator(source, overrides: overrides)
    return []
  } catch {
    return error.diagnostics
  }
}

/// Each diagnostic as `line:column: message`, or just the message if it has no location.
func messages(_ source: String, overrides: [String: UInt8] = [:]) -> [String] {
  diagnostics(source, overrides: overrides).map(\.description)
}

/// Each warning as `line:column: message`.
func warnings(_ source: String) throws -> [String] {
  try Generator(source).warnings.map(\.description)
}
