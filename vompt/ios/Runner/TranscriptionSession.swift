import AVFoundation
import Speech

enum TranscriptionError: LocalizedError {
  case unavailable
  case unsupportedLocale(String)
  case noAudioFormat

  var errorDescription: String? {
    switch self {
    case .unavailable:
      return "On-device speech transcription is not available on this device."
    case .unsupportedLocale(let id):
      return "Speech transcription does not support the language \(id)."
    case .noAudioFormat:
      return "Could not find an audio format for speech transcription."
    }
  }
}

/// Streams PCM audio into Apple's SpeechAnalyzer and reports transcript events
/// as plain dictionaries, so they can cross the Flutter platform channel.
///
/// Two transcribers listen to the same audio:
/// - "track": DictationTranscriber. Lowest latency (~0.4 s, a word at a time),
///   used to follow the reader. It drops "um"/"uh".
/// - "full": SpeechTranscriber. About a second slower, but keeps disfluencies
///   such as "um" and "uh", so it feeds filler counting and stats.
/// If dictation doesn't support the locale, "full" is used for both jobs.
///
/// Event shapes:
///   ["type": "volatile" | "final", "channel": "track" | "full", "text": String,
///    "start": Double, "end": Double, "words": [["w": String, "s": Double, "e": Double]]]
///   ["type": "error", "message": String]
@available(iOS 26.0, macOS 26.0, *)
final class TranscriptionSession {
  private let onEvent: ([String: Any]) -> Void
  private var analyzer: SpeechAnalyzer?
  private var continuation: AsyncStream<AnalyzerInput>.Continuation?
  private var resultsTasks: [Task<Void, Never>] = []
  private var analyzerFormat: AVAudioFormat?
  private var converter: AVAudioConverter?
  private let lock = NSLock()

  init(onEvent: @escaping ([String: Any]) -> Void) {
    self.onEvent = onEvent
  }

  static func makeFullTranscriber(locale: Locale) -> SpeechTranscriber {
    SpeechTranscriber(
      locale: locale,
      transcriptionOptions: [],
      reportingOptions: [.volatileResults, .fastResults],
      attributeOptions: [.audioTimeRange]
    )
  }

  static func makeTrackTranscriber(locale: Locale) -> DictationTranscriber {
    DictationTranscriber(
      locale: locale,
      contentHints: [],
      transcriptionOptions: [],
      reportingOptions: [.volatileResults],
      attributeOptions: [.audioTimeRange]
    )
  }

  static func modules(locale: Locale, withDictation: Bool) -> [any SpeechModule] {
    let full = makeFullTranscriber(locale: locale)
    return withDictation ? [makeTrackTranscriber(locale: locale), full] : [full]
  }

  static func dictationSupports(_ locale: Locale) async -> Bool {
    await DictationTranscriber.supportedLocale(equivalentTo: locale) != nil
  }

  /// Resolves the closest supported locale and makes sure its on-device model
  /// is installed, downloading it on first use.
  static func ensureModel(
    locale: Locale,
    progress: @escaping (Double) -> Void
  ) async throws -> Locale {
    guard SpeechTranscriber.isAvailable else { throw TranscriptionError.unavailable }
    guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
      throw TranscriptionError.unsupportedLocale(locale.identifier)
    }
    let modules = modules(locale: supported, withDictation: await dictationSupports(supported))
    if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
      let observation = request.progress.observe(\.fractionCompleted) { p, _ in
        progress(p.fractionCompleted)
      }
      defer { observation.invalidate() }
      try await request.downloadAndInstall()
    }
    return supported
  }

  /// Starts the analyzer and returns which channel to track with.
  /// `contextualStrings` biases recognition toward words in the script.
  func start(locale: Locale, contextualStrings: [String]) async throws -> String {
    let withDictation = await Self.dictationSupports(locale)
    let modules = Self.modules(locale: locale, withDictation: withDictation)
    let analyzer = SpeechAnalyzer(
      modules: modules,
      options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .processLifetime)
    )
    guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules)
    else { throw TranscriptionError.noAudioFormat }

    if !contextualStrings.isEmpty {
      let context = AnalysisContext()
      context.contextualStrings[.general] = contextualStrings
      // Not every module honors contextual strings; recognition still works without them.
      try? await analyzer.setContext(context)
    }
    try await analyzer.prepareToAnalyze(in: format)

    let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
    lock.withLock {
      self.analyzer = analyzer
      self.analyzerFormat = format
      self.continuation = continuation
    }

    for module in modules {
      resultsTasks.append(Task { [weak self] in
        do {
          if let dictation = module as? DictationTranscriber {
            for try await r in dictation.results {
              self?.report(r.text, range: r.range, isFinal: r.isFinal, channel: "track")
            }
          } else if let full = module as? SpeechTranscriber {
            for try await r in full.results {
              self?.report(r.text, range: r.range, isFinal: r.isFinal, channel: "full")
            }
          }
        } catch {
          self?.onEvent(["type": "error", "message": error.localizedDescription])
        }
      })
    }
    try await analyzer.start(inputSequence: stream)
    return withDictation ? "track" : "full"
  }

  /// Feeds one buffer of audio in the input device's native format.
  /// Safe to call from the audio render thread.
  func append(_ buffer: AVAudioPCMBuffer) {
    let (continuation, format) = lock.withLock { (self.continuation, self.analyzerFormat) }
    guard let continuation, let format, let converted = convert(buffer, to: format) else { return }
    continuation.yield(AnalyzerInput(buffer: converted))
  }

  /// Ends input and waits for the remaining audio to be finalized, so the last
  /// words spoken are reported before this returns.
  func finish() async {
    let (continuation, analyzer) = lock.withLock {
      defer { self.continuation = nil }
      return (self.continuation, self.analyzer)
    }
    continuation?.finish()
    if let analyzer {
      do {
        try await analyzer.finalizeAndFinishThroughEndOfInput()
      } catch {
        await analyzer.cancelAndFinishNow()
      }
    }
    for task in resultsTasks {
      await task.value
    }
    resultsTasks = []
  }

  private func report(_ text: AttributedString, range: CMTimeRange, isFinal: Bool, channel: String) {
    var words: [[String: Any]] = []
    for run in text.runs {
      guard let time = run.audioTimeRange else { continue }
      let piece = String(text[run.range].characters)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if piece.isEmpty { continue }
      words.append(["w": piece, "s": time.start.seconds, "e": time.end.seconds])
    }
    onEvent([
      "type": isFinal ? "final" : "volatile",
      "channel": channel,
      "text": String(text.characters),
      "start": range.start.seconds,
      "end": range.end.seconds,
      "words": words,
    ])
  }

  private func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
    if buffer.format == format { return buffer }
    if converter == nil || converter?.inputFormat != buffer.format {
      converter = AVAudioConverter(from: buffer.format, to: format)
      // Without this the converter swallows the first few milliseconds of every buffer.
      converter?.primeMethod = .none
    }
    guard let converter else { return nil }
    let ratio = format.sampleRate / buffer.format.sampleRate
    let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
    guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
    var consumed = false
    var error: NSError?
    let status = converter.convert(to: output, error: &error) { _, inputStatus in
      if consumed {
        inputStatus.pointee = .noDataNow
        return nil
      }
      consumed = true
      inputStatus.pointee = .haveData
      return buffer
    }
    return status == .error ? nil : output
  }
}
