import Flutter
import Foundation
import FoundationModels

/// Apple's on-device language model (Apple Intelligence) for script tools.
/// Prompts live on the Dart side so the app and the web remote share them.
///
/// Method channel "vompt/ai":
///   availability -> ["available": Bool, "reason": String?]
///   generate {instructions, prompt, temperature?, maxTokens?} -> String
///   stream {id, instructions, prompt, temperature?, maxTokens?} -> nil
///   cancel {id} -> nil
/// Event channel "vompt/ai/events": ["id": String, "text": String] as the
/// response grows, then ["id": String, "done": true, "error": String?].
final class AIPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var tasks: [String: Task<Void, Never>] = [:]

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AIPlugin()
    let methods = FlutterMethodChannel(name: "vompt/ai", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(name: "vompt/ai/events", binaryMessenger: registrar.messenger())
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
      if call.method == "availability" {
        result(["available": false, "reason": "Needs iOS 26 or later."])
      } else {
        result(FlutterError(code: "unavailable", message: "Needs iOS 26 or later.", details: nil))
      }
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "availability":
      switch SystemLanguageModel.default.availability {
      case .available:
        result(["available": true])
      case .unavailable(let reason):
        result(["available": false, "reason": Self.describe(reason)])
      }

    case "generate":
      Task { @MainActor in
        do {
          let session = LanguageModelSession(instructions: args["instructions"] as? String)
          let response = try await session.respond(to: args["prompt"] as? String ?? "", options: Self.options(args))
          result(response.content)
        } catch {
          result(FlutterError(code: "generation_failed", message: Self.describe(error), details: nil))
        }
      }

    case "stream":
      let id = args["id"] as? String ?? UUID().uuidString
      tasks[id]?.cancel()
      tasks[id] = Task { @MainActor [weak self] in
        do {
          let session = LanguageModelSession(instructions: args["instructions"] as? String)
          let stream = session.streamResponse(to: args["prompt"] as? String ?? "", options: Self.options(args))
          for try await snapshot in stream {
            if Task.isCancelled { break }
            self?.send(["id": id, "text": snapshot.content])
          }
          self?.send(["id": id, "done": true])
        } catch {
          self?.send(["id": id, "done": true, "error": Self.describe(error)])
        }
        self?.tasks[id] = nil
      }
      result(nil)

    case "cancel":
      if let id = args["id"] as? String {
        tasks[id]?.cancel()
        tasks[id] = nil
      }
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 26.0, *)
  private static func options(_ args: [String: Any]) -> GenerationOptions {
    GenerationOptions(
      temperature: args["temperature"] as? Double,
      maximumResponseTokens: args["maxTokens"] as? Int
    )
  }

  @available(iOS 26.0, *)
  private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
    switch reason {
    case .deviceNotEligible:
      return "This iPhone doesn't support Apple Intelligence."
    case .appleIntelligenceNotEnabled:
      return "Turn on Apple Intelligence in Settings to use script tools."
    case .modelNotReady:
      return "Apple Intelligence is still downloading. Try again in a few minutes."
    @unknown default:
      return "Apple Intelligence isn't available right now."
    }
  }

  @available(iOS 26.0, *)
  private static func describe(_ error: Error) -> String {
    if let error = error as? LanguageModelSession.GenerationError {
      switch error {
      case .exceededContextWindowSize:
        return "That's more text than the on-device model can take at once. Try a shorter section."
      case .guardrailViolation:
        return "Apple Intelligence declined to rewrite this text."
      case .unsupportedLanguageOrLocale:
        return "Apple Intelligence doesn't support this language yet."
      case .assetsUnavailable:
        return "Apple Intelligence is still downloading. Try again in a few minutes."
      case .rateLimited:
        return "Apple Intelligence is busy. Try again in a moment."
      default:
        return error.localizedDescription
      }
    }
    return error.localizedDescription
  }
}
