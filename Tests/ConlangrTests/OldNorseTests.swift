import Conlangr
import Testing

/// A language inspired by Old Norse, as Old Icelandic is conventionally written in the
/// normalized spelling of modern editions.
///
/// This isn't Old Norse, only a sketch of its patterns:
///
/// - þ and ð are one sound: þ at the start of a word or of a compound's second element, and ð
///   everywhere else.
/// - The ð of the weak past becomes d after l, n and m, and t after a voiceless consonant:
///   taldi, nefndi, kastti.
/// - The nominative -r assimilates to a preceding l or n after a long vowel or diphthong:
///   stól-r → stóll, stein-r → steinn.
/// - u-umlaut: a becomes ǫ before an ending with u: land, plural lǫnd, dative lǫndum.
/// - Breaking gives ja and jǫ, as in hjarta and bjǫrn.
/// - Three identical consonants in a row, as where a compound's parts meet, become two.
///
/// The grammar writes θ for þ and ð, ɑ for the diphthong au, ks for x, and · between the parts
/// of a compound, and fills in the spelling at the end.
struct OldNorseTests {
  /// The grammar, in `Examples/OldNorse.conlangr`.
  static var source: String {
    get throws { try example("OldNorse") }
  }

  static let vowels = Set("aáeéiíoóuúyýæøœǫ")
  static let letters = vowels.union("bdðfghjklmnprstvxþ")

  /// The words to check, from a fixed seed.
  static func sample(overrides: [String: UInt8] = [:]) throws -> [String] {
    let generator = try Generator(source, overrides: overrides)
    var random = SplitMix64(seed: 874)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  @Test func usesOnlyTheInventory() throws {
    for word in try Self.sample() {
      #expect(word.count > 1)
      #expect(word.allSatisfy(Self.letters.contains), "\(word)")
    }
  }

  @Test func thornAndEth() throws {
    for word in try Self.sample() {
      #expect(word.first != "ð", "\(word)")
      let characters = Array(word)
      for i in characters.indices.dropFirst() where characters[i] == "þ" {
        // Inside a word, þ only starts a compound's second part, after a consonant.
        #expect(!Self.vowels.contains(characters[i - 1]), "\(word)")
      }
    }
  }

  @Test func assimilation() throws {
    for word in try Self.sample() {
      for cluster in ["lð", "nð", "mð", "sð", "kð", "pð", "tð", "fð"] {
        #expect(!word.contains(cluster), "\(word)")
      }
      for ending in ["álr", "ólr", "ílr", "ánr", "ónr", "ínr", "einr", "sr"] {
        #expect(!word.hasSuffix(ending), "\(word)")
      }
      let characters = Array(word)
      for i in characters.indices.dropFirst(2) {
        #expect(
          !(characters[i] == characters[i - 1] && characters[i] == characters[i - 2]), "\(word)")
      }
    }
  }

  @Test func uUmlaut() throws {
    // Every noun ending in -um has had its a's turned into ǫ, except in au. A compound's first
    // part isn't affected, so leave compounds out.
    let words = try Self.sample(overrides: ["compounds": 0, "verbs": 0])
    for word in words where word.hasSuffix("um") {
      #expect(!word.replacing("au", with: "").contains("a"), "\(word)")
    }
    #expect(words.contains { $0.contains("ǫ") })
    #expect(words.contains { $0.contains("au") })
  }

  @Test func familiarShapes() throws {
    let words = try Self.sample()
    for ending in ["garðr", "inn", "aði", "ldi", "um"] {
      #expect(words.contains { $0.hasSuffix(ending) }, "-\(ending)")
    }
    #expect(words.contains { $0.hasPrefix("þ") })
    #expect(words.contains { $0.dropFirst().contains("þ") })
  }
}
