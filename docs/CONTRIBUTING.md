# Contributing to Vompt

Thank you for your interest in contributing to Vompt! This document provides guidelines and information for contributors.

## Code of Conduct

Be respectful, constructive, and professional in all interactions.

## How to Contribute

### Reporting Bugs

1. **Check existing issues** to avoid duplicates
2. **Use the bug report template** (if available)
3. **Include**:
   - iOS version
   - Device model
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots/videos if applicable

### Suggesting Features

1. **Check existing feature requests** to avoid duplicates
2. **Describe the use case** - why is this feature needed?
3. **Provide examples** of how it would work
4. **Consider alternatives** - are there other ways to solve this?

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes**
4. **Test thoroughly** on a real device
5. **Commit with clear messages** (`git commit -m 'Add amazing feature'`)
6. **Push to your fork** (`git push origin feature/amazing-feature`)
7. **Open a Pull Request**

## Development Setup

### Prerequisites
- macOS (for iOS development)
- Xcode 15.0+
- Flutter SDK 3.9.2+
- CocoaPods

### Setup Steps

```bash
# Clone your fork
git clone https://github.com/yourusername/vompt.git
cd vompt

# Install dependencies
flutter pub get

# Install iOS dependencies
cd ios && pod install && cd ..

# Run the app
flutter run
```

## Code Style

### Dart Code
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `flutter analyze` to check for issues
- Format code with `dart format .`
- Maximum line length: 80 characters (flexible for readability)

### File Organization
- Feature-first structure
- One class per file (with exceptions for small helper classes)
- Group imports: dart, flutter, packages, relative

### Naming Conventions
- **Classes**: PascalCase (`DocumentsProvider`)
- **Files**: snake_case (`documents_provider.dart`)
- **Variables**: camelCase (`currentWordIndex`)
- **Constants**: camelCase with const (`defaultFontSize`)
- **Private members**: prefix with underscore (`_scrollController`)

## Testing

### Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run with coverage
flutter test --coverage
```

### Writing Tests
- Write tests for business logic
- Test edge cases and error conditions
- Use descriptive test names
- Mock external dependencies

## Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(teleprompter): add adjustable scroll speed
fix(speech): handle microphone permission denial
docs(readme): update installation instructions
refactor(database): simplify query methods
```

## Pull Request Guidelines

### Before Submitting
- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] No new warnings from `flutter analyze`
- [ ] Tested on a real iOS device
- [ ] Updated documentation if needed
- [ ] Added tests for new features

### PR Description
Include:
- **What**: What does this PR do?
- **Why**: Why is this change needed?
- **How**: How does it work?
- **Testing**: How was it tested?
- **Screenshots**: If UI changes

## Architecture Guidelines

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation.

### Key Principles
1. **Feature-first organization** - keep related code together
2. **Provider for state management** - use ChangeNotifier
3. **Repository pattern** - abstract data access
4. **Service layer** - for cross-cutting concerns
5. **Immutability** - prefer immutable data structures

## Questions?

- Open an issue for questions
- Check existing documentation
- Review closed issues and PRs

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
