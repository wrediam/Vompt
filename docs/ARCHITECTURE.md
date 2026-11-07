# Architecture

Vompt is a Flutter app for iOS and iPadOS with a native Swift layer for speech and Apple Intelligence. State lives in `ChangeNotifier` providers; storage is SQLite (`sqflite`).

## Speech: from microphone to highlighted word

```
microphone ──► LiveTranscriber (Swift, AVAudioEngine)
                 │ PCM buffers
                 ▼
             TranscriptionSession ──► SpeechAnalyzer
                                        ├─ DictationTranscriber  "track"  ~0.4 s, word by word
                                        └─ SpeechTranscriber     "full"   keeps um/uh, per sentence
                 │ volatile / final events (EventChannel vompt/speech/events)
                 ▼
             SpeechInput (Dart)  ── falls back to speech_to_text on iOS < 26
                 │
     ┌───────────┴──────────────┐
     ▼                          ▼
 ScriptTracker              PerformanceAnalyzer
 (track channel)            (full channel, finished sentences)
 where the reader is        fillers, skips, misreads, restarts, pauses, pace
```

- **`ios/Runner/TranscriptionSession.swift`** runs both transcribers on one `SpeechAnalyzer`, converts audio to the analyzer's format, and reports events as plain dictionaries. It compiles on macOS too, which is how the test fixtures were recorded.
- **`ios/Runner/SpeechPlugin.swift`** owns the audio session and engine: interruptions (calls, Siri), route changes (AirPods, wired mics) and a level meter.
- **`engine/script_document.dart`** splits the script into on-screen words (whitespace-delimited, matching the web remote) and normalized units for matching: case, punctuation, contractions, numbers as words or digits, hyphenated and split compounds.
- **`engine/script_tracker.dart`** is an online Viterbi alignment over every script position. Each recognized word updates all positions with costs for reading the next word, skipping ahead, going back, misreading, or ad-libbing. Recognizers revise the end of their transcript constantly, so `update()` takes the whole transcript, rolls back to the last unchanged word, and replays from there. Display hysteresis stops one stray word from jerking the screen.
- **`engine/performance_analyzer.dart`** aligns each finished sentence to a window of the script (affine gaps, so skipping a sentence is one cheap gap) and classifies extra words as fillers, restarts, or ad-libs.

Tests in `test/engine` replay real recognizer output recorded from synthesized takes with fillers, ad-libs, skipped sentences and re-reads.

## Screens

| Path | Screen |
| --- | --- |
| `features/documents` | Script library |
| `features/editor` | Editor, auto-save, Assist sheet |
| `features/teleprompter` | Prompter (`PrompterText` renders one paragraph and scrolls the current line onto the reading mark), controls, take summary |
| `features/history` | Takes per script and the filler trend |
| `features/remote` | Web remote status and `RemoteCoordinator` |

## Apple Intelligence

`ios/Runner/AIPlugin.swift` exposes `LanguageModelSession` (Foundation Models) over a method channel. Prompts live in `lib/services/script_assistant.dart`, so the app and the web remote share them. Long scripts are processed paragraph by paragraph to fit the on-device model's context window.

## Web remote (Vompt Studio)

`lib/services/web_server_service.dart` serves `assets/web/index.html` and a JSON API on port 8080 of the local network. Each start of the remote creates a random key, carried in the link and QR code; every `/api` request must include it.

Navigation the browser asks for (open a script, close the prompter) goes through `RemoteCoordinator`, which uses the app's navigator key: it opens the prompter from any screen, swaps scripts in place, pops exactly to the prompter's route, and queues requests so rapid clicks apply in order. A browser disconnecting never navigates.

## Storage

`data/database/database_helper.dart`, schema version 2:

- `documents`: scripts
- `settings`: one row of display preferences
- `practice_sessions`: one row per finished take (fillers as JSON)

## Screenshots and icon

`lib/showcase.dart` (debug builds only) seeds demo content and opens a staged screen when `Documents/showcase.txt` names a scene. `tools/screenshots.py` drives the simulators. `tools/make_icon.py` draws the app icon.
