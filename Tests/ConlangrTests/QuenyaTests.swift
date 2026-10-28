import Conlangr
import Testing

/// A language inspired by Quenya, the High-elven tongue of Tolkien's legendarium, in the spelling
/// of The Lord of the Rings and The Silmarillion.
///
/// This isn't Quenya, only a sketch of how it looks:
///
/// - c is written for k, qu for kw, and x for ks. A final e, and an e or o in hiatus, take a
///   diaeresis: Ainulindalë, Eärendil, Eönwë.
/// - A word ends in a vowel or in one of n, l, r, s and t.
/// - No cluster starts a word, except qu, ny, ty, hy and hw. b, d and g appear only in the
///   clusters mb, nd, ld, rd and ng.
/// - A long vowel never comes before a cluster.
/// - Plurals take -r after a vowel (Vala → Valar), -i after a consonant (Elen → Eleni), and turn a
///   final -ë into -i (lassë → lassi).
///
/// The grammar writes k, kw, ks and plain e, and fills in the spelling at the end.
struct QuenyaTests {
  /// The grammar, in `Examples/Quenya.conlangr`.
  static var source: String {
    get throws { try example("Quenya") }
  }

  static let vowels = Set("aeiouáéíóúëäö")
  static let letters = vowels.union("pctqmnlrshvfywdbgx")

  /// The words to check, from a fixed seed.
  static func sample(overrides: [String: UInt8] = [:]) throws -> [String] {
    let generator = try Generator(source, overrides: overrides)
    var random = SplitMix64(seed: 1977)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  @Test func usesOnlyTheInventory() throws {
    for word in try Self.sample() {
      #expect(word.count > 1)
      #expect(word.allSatisfy(Self.letters.contains), "\(word)")
    }
  }

  @Test func endsInAVowelOrADental() throws {
    for word in try Self.sample() {
      let last = word.last ?? "?"
      #expect(Self.vowels.contains(last) || "nlrst".contains(last), "\(word)")
      #expect(last != "e", "\(word)")
    }
  }

  @Test func spelling() throws {
    for word in try Self.sample() {
      let characters = Array(word)
      for (i, c) in characters.enumerated() {
        switch c {
        case "q": #expect(characters.dropFirst(i + 1).first == "u", "\(word)")
        case "b": #expect(i > 0 && characters[i - 1] == "m", "\(word)")
        case "d": #expect(i > 0 && "nlr".contains(characters[i - 1]), "\(word)")
        case "g": #expect(i > 0 && characters[i - 1] == "n", "\(word)")
        default: break
        }
      }
    }
  }

  @Test func noLongVowelBeforeACluster() throws {
    let long = Set("áéíóú")
    for word in try Self.sample() {
      // qu is one consonant, x is two, and a consonant followed by y is one, palatalized.
      let characters = Array(word.replacing("qu", with: "q"))
      for i in characters.indices where long.contains(characters[i]) {
        let run = characters[(i + 1)...].prefix { !Self.vowels.contains($0) }
        let single = run.count <= 1 && run.first != "x" || run.count == 2 && run.last == "y"
        #expect(single, "\(word)")
      }
    }
  }

  @Test func plurals() throws {
    let plurals = try Self.sample(overrides: ["plurals": 1, "words": 0])
    for word in plurals {
      #expect(word.hasSuffix("r") || word.hasSuffix("i"), "\(word)")
    }
    #expect(plurals.contains { $0.hasSuffix("ar") })
    #expect(plurals.contains { $0.hasSuffix("ier") })
  }

  @Test func familiarShapes() throws {
    let words = try Self.sample()
    for part in ["ndil", "ion", "wë", "qu", "eä"] {
      #expect(words.contains { $0.contains(part) }, "\(part)")
    }
  }
}
