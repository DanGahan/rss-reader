# Syndicate

A native macOS RSS reader that fetches and parses RSS/Atom feeds directly, storing all data locally with Core Data. Focused on keyboard-driven navigation and efficient reading workflows.

## Features

- **Local-first:** No cloud dependencies, all data stored locally
- **Direct feed parsing:** Parses RSS/Atom feeds directly via FeedKit
- **Native macOS:** Built with SwiftUI, follows Human Interface Guidelines
- **Keyboard-first:** Efficient navigation without mouse
- **OPML Support:** Import/export subscriptions for easy migration

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+
- Swift 5.9+

## Getting Started

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/DanGahan/rss-reader.git
   cd rss-reader
   ```

2. Open the project in Xcode:
   ```bash
   open RSSReader.xcodeproj
   ```

3. Build and run (Cmd+R)

### Migrating from Feedly

1. In Feedly: Settings > Import/Export > Export OPML
2. Save the `feedly-export.opml` file
3. In Syndicate: File > Import Subscriptions
4. Select the OPML file
5. Choose which feeds to import and their folder destinations
6. Click Import

Note: Read/unread status does not migrate from Feedly.

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `n` | Next article |
| `j` | Next article (vim-style) |
| `k` | Previous article (vim-style) |
| `Enter/Space` | Open article in Safari |
| `Cmd+R` | Refresh all feeds |
| `Cmd+N` | Add new feed |
| `Cmd+Shift+N` | New folder |
| `Cmd+,` | Open settings |

## Architecture

The app follows the MVVM pattern:

```
SwiftUI Views -> ViewModels -> Service Layer -> Core Data
                               |-- FeedParserService
                               |-- RefreshService
                               |-- OPMLService
                               +-- ArticleCleanupService
```

### Key Components

- **FeedParserService:** Parses RSS 2.0, RSS 1.0, and Atom feeds using FeedKit
- **RefreshService:** Manages manual and automatic feed refresh with concurrency control
- **OPMLService:** Handles OPML import/export for feed migration
- **ArticleCleanupService:** Manages article retention (30 days / 1000 per feed)
- **PersistenceController:** Core Data stack management

## Development

### Running Tests

```bash
xcodebuild test -scheme RSSReader -destination 'platform=macOS'
```

### SwiftLint

The project uses SwiftLint for code style. Run locally:

```bash
swiftlint lint
```

### Project Structure

```
RSSReader/
  App/           # App entry point, keyboard commands
  Models/        # Core Data models and entities
  Services/      # Business logic services
  ViewModels/    # MVVM view models
  Views/         # SwiftUI views
  Utilities/     # Extensions and helpers
RSSReaderTests/
  UnitTests/     # Unit tests for models, services, viewmodels
  IntegrationTests/  # Integration tests
```

## Known Limitations

- **No sync:** Data is stored locally only; no iCloud sync in MVP
- **No full-text search:** Search functionality not yet implemented
- **No article starring:** Favoriting articles not yet available
- **Basic content display:** Article content shown as formatted text, no full web rendering
- **No feed discovery:** Must enter exact feed URL, no auto-discovery from website URLs

## Contributing

1. Create a feature branch: `git checkout -b feature/issue-X-description`
2. Make your changes following the code standards in `docs/STANDARDS.md`
3. Run tests: `xcodebuild test -scheme RSSReader`
4. Run SwiftLint: `swiftlint lint`
5. Create a PR with a clear description

## License

MIT License - see LICENSE file for details.
