# Vompt Architecture Documentation

## Table of Contents
- [Overview](#overview)
- [Architecture Patterns](#architecture-patterns)
- [Project Structure](#project-structure)
- [Key Components](#key-components)
- [Data Flow](#data-flow)
- [Design Decisions](#design-decisions)
- [Performance Considerations](#performance-considerations)

---

## Overview

Vompt is built using Flutter with a clean architecture approach, emphasizing separation of concerns, testability, and maintainability. The app uses Provider for state management and follows a feature-first organization pattern. The original name was Fluttele (Flutter Telepromter) but it was later renamed to Vompt. Class names may reflect the old name.

### Core Technologies
- **Framework**: Flutter 3.9.2
- **Language**: Dart 3.9.2
- **State Management**: Provider
- **Database**: SQLite (sqflite)
- **Web Server**: Shelf
- **Speech Recognition**: Apple Speech Framework (speech_to_text)

---

## Architecture Patterns

### 1. Feature-First Organization
The codebase is organized by features rather than layers, making it easier to understand and maintain related functionality.

```
lib/
├── features/
│   ├── documents/      # Document management feature
│   ├── editor/         # Script editing feature
│   ├── teleprompter/   # Teleprompter display feature
│   └── remote/         # Remote control feature
```

### 2. Provider Pattern (State Management)
Each feature has its own provider that manages state and business logic:

- **DocumentsProvider**: CRUD operations for scripts
- **EditorProvider**: Editor state, auto-save, validation
- **IntelligentTeleprompterProvider**: Teleprompter state, speech recognition
- **ServerProvider**: Web server lifecycle management

### 3. Repository Pattern (Data Access)
Data access is abstracted through repositories, providing a clean interface between business logic and data sources.

```dart
DocumentsRepository
├── getAllDocuments()
├── getDocumentById()
├── createDocument()
├── updateDocument()
└── deleteDocument()
```

### 4. Service Layer
Services handle cross-cutting concerns:

- **RemoteControlService**: Manages teleprompter state for remote clients
- **WebServerService**: HTTP server for remote control
- **IntelligentSpeechService**: Speech recognition and word tracking

---

## Project Structure

### Core Layer (`lib/core/`)
Foundation code used across features:

```
core/
├── constants/
│   └── app_constants.dart    # App-wide constants
├── theme/
│   └── app_theme.dart         # Dark theme configuration
└── utils/
    └── (future utilities)
```

### Data Layer (`lib/data/`)
Data models and persistence:

```
data/
├── models/
│   └── document.dart          # Document model with JSON serialization
├── repositories/
│   └── documents_repository.dart  # Data access abstraction
└── database/
    └── database_helper.dart   # SQLite database management
```

### Services Layer (`lib/services/`)
Cross-cutting services:

```
services/
├── remote_control_service.dart    # State sync for remote control
├── web_server_service.dart        # HTTP server + web UI
└── (speech service in features/)
```

### Features Layer (`lib/features/`)
Feature modules with screens, widgets, providers, and services:

```
features/
├── documents/
│   ├── screens/
│   │   └── document_list_screen.dart
│   └── providers/
│       └── documents_provider.dart
├── editor/
│   ├── screens/
│   │   └── document_editor_screen.dart
│   └── providers/
│       └── editor_provider.dart
├── teleprompter/
│   ├── screens/
│   │   └── intelligent_teleprompter_screen.dart
│   ├── providers/
│   │   └── intelligent_teleprompter_provider.dart
│   ├── services/
│   │   └── intelligent_speech_service.dart
│   └── widgets/
│       └── intelligent_teleprompter_controls.dart
└── remote/
    ├── screens/
    │   └── active_remote_control_screen.dart
    └── providers/
        └── server_provider.dart
```

---

## Key Components

### 1. Speech Recognition System

**Architecture:**
```
IntelligentSpeechService
├── Listens to microphone input
├── Converts speech to text in real-time
├── Normalizes text (lowercase, punctuation removal)
├── Matches spoken words to script
└── Updates current word index
```

**Word Matching Algorithm:**
- Normalizes both script and spoken text
- Splits into individual words
- Tracks position in script
- Handles variations and filler words
- Updates UI via provider notification

**Key Design Decision:** 
We chose Apple's native Speech Framework over third-party solutions for:
- Better iOS integration
- Lower latency
- No API costs
- Offline capability
- Privacy (on-device processing)

### 2. Remote Control System

**Architecture:**
```
Web Server (Shelf)
├── Serves HTML/CSS/JS web UI
├── REST API endpoints
│   ├── GET /api/documents
│   ├── GET /api/control/state
│   ├── POST /api/control/select-document
│   ├── POST /api/control/start
│   ├── POST /api/control/stop
│   └── POST /api/control/fontsize
└── Communicates with RemoteControlService
```

**State Synchronization:**
```
iOS App ←→ RemoteControlService ←→ Web Server ←→ Web Client
```

**Key Design Decisions:**
- **Embedded Web UI**: HTML/CSS/JS embedded in Dart code for single-binary deployment
- **Polling vs WebSockets**: Used polling for simplicity (1-second interval)
- **Server-Side Rendering**: Screen dimensions and font size injected into HTML on page load
- **Local Network Only**: No cloud dependency, works offline

### 3. Teleprompter Display

**Rendering Strategy:**
```
Wrap Widget (word-by-word layout)
├── Each word is a separate Text widget
├── Current word highlighted in yellow
├── Past words dimmed (50% opacity)
├── Future words at full brightness
└── Auto-scroll based on current word position
```

**Scrolling Algorithm:**
```dart
// Calculate scroll position
final wordsPerLine = screenWidth / (fontSize * 0.6);
final currentLine = currentWordIndex / wordsPerLine;
final lineHeight = fontSize * lineHeightMultiplier;
final targetScroll = (currentLine * lineHeight) - (screenHeight * 0.35);
```

**Key Design Decisions:**
- **Word-based layout**: Easier to highlight individual words
- **35% scroll offset**: Keeps current word in upper-middle of screen
- **Dynamic line height**: Adjusts based on font size (1.4 → 1.1 multiplier)
- **Centered text**: Better visual balance than justified

### 4. Database Schema

**Documents Table:**
```sql
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
```

**Key Design Decisions:**
- **UUID for IDs**: Prevents conflicts, enables future sync
- **Timestamps as integers**: Unix epoch for simplicity
- **No soft deletes**: Hard deletes for simplicity (can add later)
- **No versioning**: Single version per document (can add later)

---

## Data Flow

### 1. Document Creation Flow
```
User taps "+" button
    ↓
DocumentListScreen calls provider
    ↓
DocumentsProvider.createDocument()
    ↓
DocumentsRepository.createDocument()
    ↓
DatabaseHelper.insert()
    ↓
SQLite database
    ↓
Provider notifies listeners
    ↓
UI updates with new document
```

### 2. Speech Recognition Flow
```
User taps mic button
    ↓
IntelligentTeleprompterProvider.startListening()
    ↓
IntelligentSpeechService.startListening()
    ↓
Apple Speech Framework captures audio
    ↓
Transcribed text returned
    ↓
Service normalizes and matches words
    ↓
Updates currentWordIndex
    ↓
Provider notifies listeners
    ↓
UI highlights current word and scrolls
```

### 3. Remote Control Flow
```
User scans QR code
    ↓
Web browser opens remote UI
    ↓
JavaScript polls /api/control/state
    ↓
WebServerService returns current state
    ↓
Web UI updates display
    ↓
User clicks button on web UI
    ↓
JavaScript sends POST request
    ↓
WebServerService updates RemoteControlService
    ↓
RemoteControlService notifies listeners
    ↓
IntelligentTeleprompterProvider receives callback
    ↓
iOS app updates state
```

---

## Design Decisions

### 1. Why Provider over Bloc/Riverpod?
**Decision**: Use Provider for state management

**Rationale**:
- Simpler learning curve
- Less boilerplate
- Sufficient for app complexity
- Official Flutter recommendation
- Easy to migrate to Riverpod later if needed

### 2. Why SQLite over Hive/Shared Preferences?
**Decision**: Use SQLite for data persistence

**Rationale**:
- Structured data with relationships
- SQL queries for complex operations
- Industry standard
- Better for future features (search, filtering)
- Easier to export/import data

### 3. Why Embedded Web UI over Native App?
**Decision**: Embed HTML/CSS/JS in Dart code for remote control

**Rationale**:
- Single binary deployment
- No need for separate web server
- Easier to maintain (one codebase)
- Works offline
- No CORS issues

### 4. Why Polling over WebSockets?
**Decision**: Use HTTP polling (1-second interval) for state sync

**Rationale**:
- Simpler implementation
- Fewer edge cases (reconnection, etc.)
- Sufficient for use case (not real-time critical)
- Less battery drain on mobile
- Easier to debug

### 5. Why Word-by-Word Rendering?
**Decision**: Render each word as separate Text widget

**Rationale**:
- Easy to highlight individual words
- Simple to implement
- Good performance (< 1000 words typically)
- Flexible for future features (word-level styling)

**Trade-off**: Slightly higher memory usage, but negligible for typical scripts

### 6. Why Landscape Orientation for Teleprompter?
**Decision**: Force landscape mode when teleprompter is active

**Rationale**:
- More words per line
- Better for video recording
- Standard for professional teleprompters
- Easier to read at distance

### 7. Why Server-Side Dimension Injection?
**Decision**: Inject screen dimensions into HTML on page load

**Rationale**:
- Eliminates race conditions
- No async fetching needed
- Instant rendering
- Simpler JavaScript code
- More reliable

---

## Performance Considerations

### 1. Speech Recognition
- **On-device processing**: No network latency
- **Continuous recognition**: Minimal overhead
- **Word normalization**: Cached regex patterns
- **Debouncing**: Prevents excessive updates

### 2. Teleprompter Rendering
- **Widget reuse**: Flutter's widget tree optimization
- **Selective rebuilds**: Only rebuild affected widgets
- **Scroll optimization**: AnimateTo with duration
- **Memory**: ~1MB for 1000-word script

### 3. Remote Control
- **Polling interval**: 1 second (configurable)
- **Minimal payload**: JSON state < 1KB
- **No video streaming**: Only state sync
- **Local network**: Low latency

### 4. Database
- **Indexed queries**: ID-based lookups
- **Batch operations**: Single transaction for multiple ops
- **Lazy loading**: Documents loaded on demand
- **Auto-save debouncing**: 2-second delay

### 5. Memory Management
- **Provider disposal**: Cleanup listeners on dispose
- **Speech service**: Stop recognition when not needed
- **Web server**: Graceful shutdown
- **Database connections**: Singleton pattern

---

## Future Improvements

### Architecture
- [ ] Add unit tests for providers
- [ ] Add integration tests for critical flows
- [ ] Implement repository pattern for settings
- [ ] Add error boundary widgets
- [ ] Implement logging framework

### Performance
- [ ] Profile and optimize word rendering
- [ ] Implement virtual scrolling for large scripts
- [ ] Add caching layer for frequent queries
- [ ] Optimize web UI bundle size

### Features
- [ ] Add undo/redo to editor
- [ ] Implement document versioning
- [ ] Add iCloud sync
- [ ] Support multiple languages
- [ ] Add accessibility features

---

## Contributing

When contributing to Vompt, please follow these architectural principles:

1. **Feature-first organization**: Keep related code together
2. **Single responsibility**: Each class/function does one thing
3. **Dependency injection**: Use Provider for dependencies
4. **Immutability**: Prefer immutable data structures
5. **Error handling**: Handle errors gracefully with user feedback
6. **Documentation**: Document complex logic and design decisions
7. **Testing**: Write tests for business logic

---

## Questions?

For architecture questions or suggestions, please open an issue on GitHub.
