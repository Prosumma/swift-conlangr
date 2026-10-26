import Conlangr
import Testing

/// Each event as one line, indented by its depth, with locations as `line:column`.
func lines(_ trace: Trace) -> [String] {
  trace.events.map { event in
    let indent = String(repeating: "  ", count: event.depth)
    switch event.kind {
    case .started(let production, let location):
      return "\(indent)start \(production ?? "-") \(location.line):\(location.column)"
    case .rejected(let word, let location):
      return "\(indent)reject \(word) \(location.line):\(location.column)"
    case .substituted(let from, let to, let location):
      return "\(indent)\(from) > \(to) \(location.line):\(location.column)"
    case .finished(let word):
      return "\(indent)finish \(word)"
    }
  }
}

struct TraceTests {
  @Test func groupsAndSubstitutions() throws {
    let trace = try Generator("_ = (+ &a b > *b=c)\na = (+ x y)").trace()
    #expect(trace.result == .success("xyc"))
    #expect(
      lines(trace) == [
        "start _ 1:5",
        "  start a 2:5",
        "  finish xy",
        "xyb > xyc 1:15",
        "finish xyc",
      ])
  }

  @Test func sameWordAsGenerating() throws {
    let generator = try Generator(IndoEuropeanTests.source)
    var first = SplitMix64(seed: 9)
    var second = SplitMix64(seed: 9)
    for _ in 0..<50 {
      let trace = generator.trace(using: &first)
      #expect(trace.result == .success(try generator.generate(using: &second)))
      if case .finished(let word) = trace.events.last?.kind {
        #expect(trace.result == .success(word))
      } else {
        Issue.record("The last event isn't the main production finishing.")
      }
    }
  }

  @Test func rejectionStartsAgain() throws {
    let generator = try Generator("_ = (+ *ab - a)")
    // Find a seed whose first attempt is rejected.
    let trace = try #require(
      (1...50 as ClosedRange<UInt64>).lazy.map { seed in
        var random = SplitMix64(seed: seed)
        return generator.trace(using: &random)
      }.first { $0.events.count > 2 })
    #expect(lines(trace).first == "start _ 1:5")
    #expect(lines(trace).dropFirst().dropLast().allSatisfy { $0 == "reject a 1:14" })
    #expect(lines(trace).last == "finish b")
  }

  @Test func selectWithRewritesIsAGroup() throws {
    let trace = try Generator("_ = (+ i &v)\nv = (? a > *a=e)").trace()
    #expect(
      lines(trace) == [
        "start _ 1:5",
        "  start v 2:5",
        "  a > e 2:12",
        "  finish e",
        "finish ie",
      ])
  }

  @Test func plainSelectsAndLiteralsDoNotShow() throws {
    let trace = try Generator("_ = (? (+ a b))").trace()
    // The concat is labeled with the production whose select chose it.
    #expect(lines(trace) == ["start _ 1:8", "finish ab"])
  }

  @Test func ruleSetRewritesAreWhereTheRuleSetIs() throws {
    let trace = try Generator("@r = (> a=b)\n_ = (+ a @r)").trace()
    #expect(lines(trace) == ["start _ 2:5", "a > b 1:9", "finish b"])
  }

  @Test func startsWhereTheGeneratorStarts() throws {
    let generator = try #require(try Generator("_ = &n\nn = (+ a b)").starting(at: "n"))
    #expect(lines(generator.trace()) == ["start n 2:5", "finish ab"])
  }

  @Test func failureKeepsWhatHappened() throws {
    let trace = try Generator("_ = (+ a - a)").trace()
    #expect(trace.result == .failure(.tooManySteps))
    #expect(trace.events.count > 1_000)
    #expect(lines(trace).dropFirst().allSatisfy { $0 == "reject a 1:12" })
  }

  @Test func tooLong() throws {
    let long = String(repeating: "a", count: 40)
    let trace = try Generator("_ = (+ &x &x)\nx = \(long)").trace()
    #expect(trace.result == .failure(.tooLong(long + long)))
    #expect(lines(trace) == ["start _ 1:5"])
  }
}
