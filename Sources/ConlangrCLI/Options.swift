import ArgumentParser
import Conlangr
import Foundation

/// The script to read, and its variables.
struct ScriptOptions: ParsableArguments {
  @Argument(help: "The script: a .conlangr file, or - for standard input.")
  var path: String

  @Option(
    name: .customLong("set"),
    help: ArgumentHelp(
      "Sets a variable the script declares, as in --set syllables=4. Repeat it for more.",
      valueName: "name=value"))
  var overrides: [Override] = []

  /// Reads the script.
  func load() throws -> LoadedScript {
    let source: String
    if path == "-" {
      source = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
    } else {
      do {
        source = try String(contentsOfFile: path, encoding: .utf8)
      } catch {
        throw CommandError("Couldn't read \"\(path)\": \(error.localizedDescription)")
      }
    }
    let values = Dictionary(overrides.map { ($0.name, $0.value) }) { _, last in last }
    return LoadedScript(path: path == "-" ? "<stdin>" : path, source: source, overrides: values)
  }
}

/// A script that's been read but not compiled.
struct LoadedScript {
  /// The path to show in messages.
  let path: String
  let source: String
  let overrides: [String: UInt8]

  func compile() throws(ScriptError) -> Generator {
    try Script(source).compile(overrides: overrides)
  }
}

/// `name=value`, the argument to `--set`. A `$` before the name is allowed, since that's how
/// the script writes it.
struct Override: ExpressibleByArgument {
  let name: String
  let value: UInt8

  init?(argument: String) {
    let parts = argument.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2, let value = UInt8(parts[1]) else {
      return nil
    }
    let name = parts[0].hasPrefix("$") ? parts[0].dropFirst() : parts[0]
    guard !name.isEmpty else {
      return nil
    }
    self.name = String(name)
    self.value = value
  }
}

/// Where generating starts, and its randomness.
struct StartOptions: ParsableArguments {
  @Option(help: "The production to start from, instead of _.")
  var from: String?

  @Option(help: "Seeds the randomness, so the same seed gives the same words.")
  var seed: UInt64?

  /// Compiles the script, reporting any problems, and starts it where `--from` says.
  func generator(from script: LoadedScript) throws -> Generator {
    let generator: Generator
    do {
      generator = try script.compile()
    } catch {
      for line in Report.diagnostics(error, path: script.path) {
        printError(line)
      }
      throw ExitCode.failure
    }
    guard let from else {
      return generator
    }
    guard let started = generator.starting(at: from) else {
      let productions = generator.productions.joined(separator: ", ")
      throw CommandError("There's no production named \"\(from)\". The script has \(productions).")
    }
    return started
  }

  func randomness() -> Randomness {
    Randomness(seed: seed)
  }
}

/// Seeded randomness with `--seed`, and the system's otherwise.
struct Randomness: RandomNumberGenerator {
  private var seeded: SplitMix64?
  private var system = SystemRandomNumberGenerator()

  init(seed: UInt64?) {
    seeded = seed.map(SplitMix64.init)
  }

  mutating func next() -> UInt64 {
    seeded?.next() ?? system.next()
  }
}

/// A small seeded generator. The same seed gives the same words, as long as the script and the
/// version of Conlangr stay the same.
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

/// A failure that isn't about the script, such as a file that can't be read.
struct CommandError: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}

/// Prints `line` to standard error, the stream for errors and warnings, so that standard
/// output only has what was asked for: words or a trace.
func printError(_ line: String) {
  // Standard output is buffered when it's a pipe, so without this, an error could come out
  // before the output it follows.
  fflush(nil)
  FileHandle.standardError.write(Data((line + "\n").utf8))
}
