import ArgumentParser
import Conlangr

@main
struct ConlangrCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "conlangr",
    abstract: "Generates random words for constructed languages from a Conlangr script.",
    discussion: """
      Scripts are usually .conlangr files. Give - as the path to read one from standard input. \
      Without a subcommand, conlangr generates words.
      """,
    version: version,
    subcommands: [Generate.self, Check.self, TraceCommand.self],
    defaultSubcommand: Generate.self
  )

  /// Conlangr's version, which `--version` prints. Update it with each release.
  static let version = "1.1.0"
}

struct Generate: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Generates words, one to a line.",
    discussion: "To see the script's warnings, use check."
  )

  @OptionGroup var script: ScriptOptions
  @OptionGroup var start: StartOptions

  @Option(name: [.customShort("n"), .long], help: "The number of words to generate.")
  var count = 10

  @Flag(help: "Don't generate any word more than once.")
  var distinct = false

  func validate() throws {
    guard count >= 0 else {
      throw ValidationError("The count can't be negative.")
    }
  }

  func run() throws {
    let loaded = try script.load()
    let generator = try start.generator(from: loaded)
    var random = start.randomness()
    let words: [String]
    do {
      words = try generator.generate(count: count, distinct: distinct, using: &random)
    } catch {
      printError(Report.line(loaded.path, nil, "error", error.description))
      throw ExitCode.failure
    }
    for word in words {
      print(word)
    }
    if words.count < count {
      printError(
        "\(loaded.path): note: The script only produced \(words.count) different words before "
          + "repeating itself \(Generator.maximumDuplicates) times in a row.")
    }
  }
}

struct Check: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Checks a script, and prints its errors and warnings.",
    discussion: """
      Like the other commands, it prints errors and warnings to standard error. It exits with a \
      nonzero status if the script has errors, or with --strict, warnings.
      """
  )

  @OptionGroup var script: ScriptOptions

  @Flag(help: "Treat warnings as errors.")
  var strict = false

  func run() throws {
    let loaded = try script.load()
    do {
      let generator = try loaded.compile()
      for line in Report.warnings(generator.warnings, path: loaded.path) {
        printError(line)
      }
      if strict && !generator.warnings.isEmpty {
        throw ExitCode.failure
      }
    } catch let error as ScriptError {
      for line in Report.diagnostics(error, path: loaded.path) {
        printError(line)
      }
      throw ExitCode.failure
    }
  }
}

struct TraceCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "trace",
    abstract: "Generates one word, and shows how.",
    discussion: """
      Each group (each concat, and each select with rewrites) is shown with the production it \
      was reached through and where it is in the script, followed by the groups inside it, the \
      words its skips rejected (-), what its substitutions did (>), and the word it produced (=).
      """
  )

  @OptionGroup var script: ScriptOptions
  @OptionGroup var start: StartOptions

  func run() throws {
    let loaded = try script.load()
    let generator = try start.generator(from: loaded)
    var random = start.randomness()
    let trace = generator.trace(using: &random)
    for line in Report.trace(trace, source: loaded.source) {
      print(line)
    }
    if case .failure(let error) = trace.result {
      printError(Report.line(loaded.path, nil, "error", error.description))
      throw ExitCode.failure
    }
  }
}
