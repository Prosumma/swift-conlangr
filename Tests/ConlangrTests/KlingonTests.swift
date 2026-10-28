import Conlangr
import Testing

/// A language inspired by Klingon, as Marc Okrand describes it in The Klingon Dictionary.
///
/// This isn't Klingon, only a sketch of its patterns:
///
/// - The spelling is case-sensitive: D, H, I, Q and S are distinct letters, and ch, gh, ng, tlh
///   and ' are single sounds.
/// - Every syllable starts with a consonant (' counts), and vowels never meet. The only clusters
///   that can end a syllable are rgh, w' and y'.
/// - Roots are mostly one syllable, CVC, sometimes two: tlhIngan, Qapla'.
/// - A verb takes an optional prefix for its subject and object, then suffixes in nine ordered
///   types: -'egh before -nIS before -choH, and so on, then a rover such as -be' (not). A noun takes
///   suffixes in five ordered types: -Hom, then -pu', then -qoq, then -wIj, then -Daq.
///
/// The grammar writes each sound as one lowercase symbol (ɖ for D, x for H, ɪ for I, χ for Q, ʂ
/// for S, č for ch, ɣ for gh, ŋ for ng, ƛ for tlh and ʔ for '), and the spelling is filled in at
/// the end.
struct KlingonTests {
  /// The grammar, in `Examples/Klingon.conlangr`.
  static var source: String {
    get throws { try example("Klingon") }
  }

  static let letters = Set("abDeghHIjlmnopqQrStuvwy'c")

  /// The words to check, from a fixed seed.
  static func sample() throws -> [String] {
    let generator = try Generator(source)
    var random = SplitMix64(seed: 1985)
    return try (0..<2_000).map { _ in try generator.generate(using: &random) }
  }

  /// `word` split into its sounds, with tlh, ch, gh and ng each one sound. As in Klingon, ngh is
  /// n followed by gh.
  static func sounds(_ word: String) -> [String] {
    var sounds: [String] = []
    var rest = Substring(word)
    while !rest.isEmpty {
      let sound =
        rest.hasPrefix("ngh")
        ? "n" : ["tlh", "ch", "gh", "ng"].first { rest.hasPrefix($0) } ?? String(rest.first!)
      sounds.append(sound)
      rest = rest.dropFirst(sound.count)
    }
    return sounds
  }

  static let vowels: Set<String> = ["a", "e", "I", "o", "u"]

  @Test func usesOnlyTheInventory() throws {
    for word in try Self.sample() {
      #expect(word.allSatisfy(Self.letters.contains), "\(word)")
      // c, g and lowercase h only appear in ch, gh, ng and tlh.
      let sounds = Set(Self.sounds(word))
      #expect(sounds.isDisjoint(with: ["c", "g", "h"]), "\(word)")
    }
  }

  @Test func syllables() throws {
    for word in try Self.sample() {
      let sounds = Self.sounds(word)
      #expect(!Self.vowels.contains(sounds[0]), "\(word)")
      // Split into runs of consonants. Between vowels, a run is at most two consonants, or three
      // after rgh, w' or y'. At the end of the word, it's one consonant, or one of those.
      var runs: [[String]] = [[]]
      for sound in sounds {
        if Self.vowels.contains(sound) {
          #expect(!runs[runs.count - 1].isEmpty, "\(word): vowels meet")
          runs.append([])
        } else {
          runs[runs.count - 1].append(sound)
        }
      }
      let special: Set<[String]> = [["r", "gh"], ["w", "'"], ["y", "'"]]
      for (i, run) in runs.enumerated().dropFirst() {
        let isLast = i == runs.count - 1
        let coda = run.count > 1 ? Array(run.prefix(2)) : []
        let limit = special.contains(coda) ? 3 : 2
        if isLast {
          #expect(run.count <= 1 || special.contains(run), "\(word)")
        } else {
          #expect(run.count <= limit, "\(word)")
        }
      }
    }
  }

  @Test func familiarShapes() throws {
    let words = try Self.sample()
    for part in ["tlh", "Q", "gh", "be'", "pu'", "mey", "Daq", "'"] {
      #expect(words.contains { $0.contains(part) }, "\(part)")
    }
  }
}
