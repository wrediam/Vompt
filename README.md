<div align="center">

<img src="https://raw.githubusercontent.com/wrediaco/vompt/main/icon.png" alt="Vompt Logo" width="120" height="120">

# Vompt - AI-Powered Teleprompter

An intelligent iOS teleprompter that uses speech recognition to automatically scroll your script as you read. Perfect for video creators, presenters, and anyone who needs to deliver scripted content naturally.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.9.2-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-iOS%2013%2B-lightgrey)](https://www.apple.com/ios)

[Features](#features) • [Getting Started](#getting-started) • [Documentation](#documentation) • [Contributing](#contributing) • [License](#license)

</div>

## Features

### 🎤 Smart Auto-Scrolling
- **Speech Recognition**: Real-time speech-to-text using Apple's Speech Framework
- **Word Highlighting**: Visual feedback showing current word being spoken
- **Intelligent Tracking**: Automatically scrolls as you read your script
- **Adaptive Speed**: Matches your natural reading pace

### 📱 Remote Control
- **Web-Based Interface**: Control from any device on your network
- **QR Code Connection**: Instant setup via QR code scanning
- **Live Preview**: See exactly what's on the teleprompter screen
- **Full Control**: Adjust font size, navigate, and control playback remotely

### 📝 Document Management
- **Create & Edit**: Full-featured text editor with auto-save
- **Multiple Scripts**: Manage unlimited teleprompter scripts
- **Local Storage**: All data stored locally using SQLite - no cloud, no accounts
- **Word Count**: Track script length and estimated reading time

### ⚙️ Customization
- **Adjustable Font Size**: 16-72pt range for optimal readability
- **Dynamic Line Height**: Automatically adjusts for better text flow
- **Landscape Mode**: Optimized for teleprompter use
- **Clean Interface**: Distraction-free reading experience

## Getting Started

### Prerequisites
- Flutter SDK 3.35.7 or higher
- Dart 3.9.2 or higher
- iOS development environment (Xcode 26.1.1+)
- macOS for iOS development

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/vompt.git
   cd vompt
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### iOS Setup

The app requires microphone and local network permissions. These are already configured in `ios/Runner/Info.plist`:
- `NSMicrophoneUsageDescription`: For speech recognition
- `NSSpeechRecognitionUsageDescription`: For speech-to-text
- `NSLocalNetworkUsageDescription`: For remote control server
- `NSBonjourServices`: For network discovery

**Note:** Users will be prompted to grant these permissions on first launch.

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # Main app configuration
├── core/
│   ├── constants/           # App constants and colors
│   ├── theme/              # Theme configuration
│   └── utils/              # Utility classes (text processing, speech matching)
├── data/
│   ├── models/             # Data models (Document, Settings)
│   ├── repositories/       # Data access layer
│   └── database/           # SQLite database helper
├── services/
│   ├── speech_service.dart      # Speech recognition service
│   └── web_server_service.dart  # HTTP server for remote control
├── features/
│   ├── documents/          # Document list and management
│   ├── editor/             # Document editor
│   ├── teleprompter/       # Teleprompter view and controls
│   └── remote/             # Remote control screen
└── shared/
    └── widgets/            # Reusable UI components
```

## Usage

### Creating a Document
1. Tap the **+** button on the home screen
2. Enter a title for your script
3. Start typing your content in the editor
4. Changes are auto-saved every 2 seconds

### Using the Teleprompter
1. Open a document from the list
2. Tap the **Play** button in the editor
3. Adjust font size and scroll speed using the sliders
4. Tap the screen to show/hide controls
5. Controls auto-hide after 3 seconds

### Remote Control
1. Tap the **WiFi** icon on the home screen
2. The server will start automatically
3. Scan the QR code or enter the URL on another device
4. Control playback, speed, and font size remotely

## Development

### Running Tests
```bash
flutter test
```

### Code Analysis
```bash
flutter analyze
```

### Building for iOS
```bash
flutter build ios --release
```

## Documentation

- **[Architecture Guide](vompt/ARCHITECTURE.md)** - Detailed technical documentation, design decisions, and data flow
- **[Contributing Guide](vompt/CONTRIBUTING.md)** - How to contribute, code style, and development setup
- **[License](LICENSE)** - MIT License details

### Quick Architecture Overview

- **State Management**: Provider pattern with ChangeNotifier
- **Database**: SQLite with repository pattern
- **Web Server**: Shelf framework with embedded HTML/CSS/JS
- **Speech Recognition**: Apple Speech Framework for on-device processing

For detailed architecture documentation, see [ARCHITECTURE.md](vompt/ARCHITECTURE.md).

## Dependencies

### Core
- `flutter`: SDK
- `provider`: State management
- `sqflite`: Local database
- `path_provider`: File system access

### Features
- `speech_to_text`: Speech recognition
- `permission_handler`: Runtime permissions
- `shelf`: Web server
- `shelf_router`: HTTP routing
- `network_info_plus`: Network information
- `qr_flutter`: QR code generation
- `uuid`: Unique ID generation
- `intl`: Internationalization
- `wakelock_plus`: Prevent screen sleep

## Known Limitations

1. **Deprecation Warnings**: Some packages use deprecated Flutter APIs (will be updated in future releases)
2. **Speech Recognition**: Not yet fully integrated (Phase 3)
3. **iOS Only**: Currently targets iOS only (Android support planned)
4. **Local Network Only**: Remote control works only on local WiFi

## Contributing

Contributions are welcome! Please read our [Contributing Guide](vompt/CONTRIBUTING.md) for details on:

- How to report bugs
- How to suggest features
- Code style guidelines
- Pull request process
- Development setup

This is an open source project, and we appreciate your help in making Vompt better!

## License

MIT License

Copyright (c) 2025 Vompt Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Acknowledgments

- Built with Flutter
- Inspired by professional teleprompter applications
- Designed for content creators, presenters, and speakers
