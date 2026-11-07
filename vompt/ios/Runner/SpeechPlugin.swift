import AVFoundation
import Flutter
import Speech

/// Live on-device transcription for the teleprompter, built on SpeechAnalyzer.
///
/// Method channel "vompt/speech":
///   isSupported -> Bool
///   prepare {locale} -> String   resolved locale; downloads the model on first use
///                                and reports ["type": "model", "progress": Double]
///   start {locale, contextualStrings} -> String   channel to track with
///   stop -> nil                  returns once the last words have been reported
/// Event channel "vompt/speech/events": transcript events from
/// TranscriptionSession, plus ["type": "level", "db": Double] while listening and
/// ["type": "interrupted" | "resumed"] around audio interruptions.
final class SpeechPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var live: AnyObject?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SpeechPlugin()
    let methods = FlutterMethodChannel(name: "vompt/speech", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(name: "vompt/speech/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func send(_ event: [String: Any]) {
    DispatchQueue.main.async { self.sink?(event) }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *) else {
      if call.method == "isSupported" {
        result(false)
      } else {
        result(FlutterError(code: "unsupported", message: "Requires iOS 26 or later.", details: nil))
      }
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    let locale = Locale(identifier: args["locale"] as? String ?? Locale.current.identifier)

    switch call.method {
    case "isSupported":
      result(SpeechTranscriber.isAvailable)

    case "prepare":
      Task { @MainActor in
        do {
          let resolved = try await TranscriptionSession.ensureModel(locale: locale) { [weak self] p in
            self?.send(["type": "model", "progress": p])
          }
          result(resolved.identifier)
        } catch {
          result(FlutterError(code: "prepare_failed", message: error.localizedDescription, details: nil))
        }
      }

    case "start":
      let strings = args["contextualStrings"] as? [String] ?? []
      Task { @MainActor in
        do {
          if let existing = self.live as? LiveTranscriber {
            await existing.stop()
          }
          let live = LiveTranscriber { [weak self] event in self?.send(event) }
          self.live = live
          let channel = try await live.start(locale: locale, contextualStrings: strings)
          result(channel)
        } catch {
          self.live = nil
          result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
        }
      }

    case "stop":
      Task { @MainActor in
        if let live = self.live as? LiveTranscriber {
          await live.stop()
        }
        self.live = nil
        result(nil)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Owns the microphone: audio session, engine tap, interruptions and route
/// changes (AirPods, wired mics), feeding a TranscriptionSession.
@available(iOS 26.0, *)
@MainActor
final class LiveTranscriber {
  private let audioEngine = AVAudioEngine()
  private var session: TranscriptionSession?
  private let send: ([String: Any]) -> Void
  private var observers: [NSObjectProtocol] = []

  init(send: @escaping ([String: Any]) -> Void) {
    self.send = send
  }

  func start(locale: Locale, contextualStrings: [String]) async throws -> String {
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(
      .playAndRecord,
      mode: .spokenAudio,
      options: [.defaultToSpeaker, .allowBluetoothHFP]
    )
    try audioSession.setActive(true)

    let session = TranscriptionSession(onEvent: send)
    let channel = try await session.start(locale: locale, contextualStrings: contextualStrings)
    self.session = session
    try startAudio()
    observe()
    return channel
  }

  func stop() async {
    observers.forEach(NotificationCenter.default.removeObserver)
    observers = []
    audioEngine.inputNode.removeTap(onBus: 0)
    audioEngine.stop()
    await session?.finish()
    session = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func startAudio() throws {
    guard let session else { return }
    let input = audioEngine.inputNode
    input.removeTap(onBus: 0)
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      throw NSError(
        domain: "Vompt", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "No microphone input is available."]
      )
    }
    let meter = LevelMeter(send: send)
    input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
      session.append(buffer)
      meter.measure(buffer)
    }
    audioEngine.prepare()
    try audioEngine.start()
  }

  private func observe() {
    let center = NotificationCenter.default
    observers.append(center.addObserver(
      forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
    ) { [weak self] note in
      guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
      MainActor.assumeIsolated {
        guard let self else { return }
        if type == .began {
          self.send(["type": "interrupted"])
        } else {
          try? AVAudioSession.sharedInstance().setActive(true)
          self.restartAudio()
        }
      }
    })
    // Plugging in headphones or connecting AirPods changes the input format;
    // the engine stops and the tap must be reinstalled.
    observers.append(center.addObserver(
      forName: .AVAudioEngineConfigurationChange, object: audioEngine, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.restartAudio() }
    })
  }

  private func restartAudio() {
    audioEngine.stop()
    do {
      try startAudio()
      send(["type": "resumed"])
    } catch {
      send(["type": "error", "message": error.localizedDescription])
    }
  }
}

/// Reports input loudness about ten times a second for the on-screen meter.
private final class LevelMeter: @unchecked Sendable {
  private let send: ([String: Any]) -> Void
  private var lastSent: CFTimeInterval = 0

  init(send: @escaping ([String: Any]) -> Void) {
    self.send = send
  }

  func measure(_ buffer: AVAudioPCMBuffer) {
    let now = CACurrentMediaTime()
    guard now - lastSent >= 0.1, let samples = buffer.floatChannelData?[0] else { return }
    lastSent = now
    let count = Int(buffer.frameLength)
    guard count > 0 else { return }
    var sum: Float = 0
    for i in 0..<count {
      sum += samples[i] * samples[i]
    }
    let rms = (sum / Float(count)).squareRoot()
    let db = 20 * log10(max(rms, 1e-7))
    send(["type": "level", "db": Double(db)])
  }
}
