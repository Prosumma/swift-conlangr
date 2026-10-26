import ArgumentParser
import Conlangr
import Foundation
import Testing

@testable import ConlangrCLI

struct OverrideTests {
  @Test(arguments: [("n=4", "n", 4), ("$n=4", "n", 4), ("syllables=255", "syllables", 255)])
  func parses(argument: String, name: String, value: UInt8) throws {
    let override = try #require(Override(argument: argument))
    #expect(override.name == name)
    #expect(override.value == value)
  }

  @Test(arguments: ["n", "n=", "=4", "$=4", "n=256", "n=-1", "n=a", "n=4=5"])
  func rejects(argument: String) {
    #expect(Override(argument: argument) == nil)
  }
}

struct ParsingTests {
  @Test func generateIsTheDefault() throws {
    let command = try ConlangrCommand.parseAsRoot(["words.conlangr", "-n", "3", "--distinct"])
    let generate = try #require(command as? Generate)
    #expect(generate.script.path == "words.conlangr")
    #expect(generate.count == 3)
    #expect(generate.distinct)
  }

  @Test func generateOptions() throws {
    let command = try ConlangrCommand.parseAsRoot([
      "generate", "--count", "5", "--seed", "7", "--from", "syl", "--set", "a=1", "--set", "b=2",
      "-",
    ])
    let generate = try #require(command as? Generate)
    #expect(generate.script.path == "-")
    #expect(generate.count == 5)
    #expect(generate.start.seed == 7)
    #expect(generate.start.from == "syl")
    #expect(generate.script.overrides.map(\.name) == ["a", "b"])
  }

  @Test func countDefaultsToTen() throws {
    let command = try ConlangrCommand.parseAsRoot(["words.conlangr"])
    #expect((command as? Generate)?.count == 10)
  }

  @Test func negativeCountIsAnError() {
    // Written "--count=-1", since "-n -1" reads the -1 as an option and never gets to validate().
    do {
      _ = try ConlangrCommand.parseAsRoot(["words.conlangr", "--count=-1"])
      Issue.record("Expected an error.")
    } catch {
      #expect(ConlangrCommand.message(for: error) == "The count can't be negative.")
    }
  }

  @Test func check() throws {
    let command = try ConlangrCommand.parseAsRoot(["check", "--strict", "words.conlangr"])
    #expect((command as? Check)?.strict == true)
  }

  @Test func trace() throws {
    let command = try ConlangrCommand.parseAsRoot(["trace", "--seed", "3", "words.conlangr"])
    #expect((command as? TraceCommand)?.start.seed == 3)
  }
}

struct ReportTests {
  @Test func diagnostics() {
    do {
      _ = try Generator("_ = (+ &vowl x)\n_ = b")
      Issue.record("Expected errors.")
    } catch {
      #expect(
        Report.diagnostics(error, path: "a.conlangr") == [
          "a.conlangr:1:8: error: There is no production named \"vowl\".",
          "a.conlangr:2:1: error: The production \"_\" is already defined.",
        ])
    }
  }

  @Test func diagnosticWithoutALocation() {
    do {
      _ = try Generator("a = b")
      Issue.record("Expected an error.")
    } catch {
      #expect(
        Report.diagnostics(error, path: "<stdin>") == [
          "<stdin>: error: There is no main production. Define one named \"_\", as in \"_ = ...\"."
        ])
    }
  }

  @Test func warnings() throws {
    let generator = try Generator("_ = a\nb = c")
    #expect(
      Report.warnings(generator.warnings, path: "a.conlangr") == [
        "a.conlangr:2:1: warning: Nothing refers to the production \"b\"."
      ])
  }

  @Test func trace() throws {
    let source = "_ = (+ &a (+ b c) > *c=d)\na = (+ x y)"
    let trace = try Generator(source).trace()
    #expect(
      Report.trace(trace, source: source) == [
        "_  (1:5)",
        "  a  (2:5)",
        "    = xy",
        "  (+ …)  (1:11)",
        "    = bc",
        "  > xybc → xybd  by *c=d (1:21)",
        "  = xybd",
      ])
  }

  @Test func traceOfARejection() throws {
    let source = "_ = (+ *ab - a)"
    let generator = try Generator(source)
    let trace = try #require(
      (1...50 as ClosedRange<UInt64>).lazy.map { seed in
        var random = SplitMix64(seed: seed)
        return generator.trace(using: &random)
      }.first { $0.events.count > 2 })
    #expect(Report.trace(trace, source: source)[1] == "  - a  rejected by a (1:14)")
  }
}

struct ScriptTests {
  @Test func loadsAFileWithOverrides() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(UUID().uuidString).conlangr")
    try "$n = 1\n_ = (+ $n a)".write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    let options = try ScriptOptions.parse([url.path, "--set", "n=3", "--set", "$n=2"])
    let loaded = try options.load()
    #expect(loaded.path == url.path)
    // The last setting of a variable wins.
    #expect(loaded.overrides == ["n": 2])
    #expect(try loaded.compile().generate(count: 50).allSatisfy { ["a", "aa"].contains($0) })
  }

  @Test func missingFile() throws {
    let options = try ScriptOptions.parse(["/nonexistent/words.conlangr"])
    #expect(throws: CommandError.self) {
      try options.load()
    }
  }

  @Test func startsFromAProduction() throws {
    let loaded = LoadedScript(path: "a.conlangr", source: "_ = (+ &n x)\nn = y", overrides: [:])
    let start = try StartOptions.parse(["--from", "n"])
    #expect(try start.generator(from: loaded).generate() == "y")
  }

  @Test func unknownProduction() throws {
    let loaded = LoadedScript(path: "a.conlangr", source: "_ = &n\nn = y", overrides: [:])
    let start = try StartOptions.parse(["--from", "m"])
    #expect {
      try start.generator(from: loaded)
    } throws: { error in
      (error as? CommandError)?.description
        == "There's no production named \"m\". The script has _, n."
    }
  }

  @Test func seedMakesTheSameWords() throws {
    let generator = try Generator("_ = (+ *ptk *aeiou 2 (+ *ptk *aeiou))")
    let start = try StartOptions.parse(["--seed", "42"])
    var first = start.randomness()
    var second = start.randomness()
    #expect(
      try generator.generate(count: 20, using: &first)
        == generator.generate(count: 20, using: &second))
  }
}
