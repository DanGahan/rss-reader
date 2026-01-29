cat > docs/architecture/FEEDLY_RSS_READER_MVP.md << 'EOF'
# RSS Reader MVP - Technical Architecture
**Version:** 2.0 (Local-First Approach)  
**Last Updated:** January 28, 2026  
**Status:** Architecture Review

---

## Change Log

**v2.0 - Local-First Pivot:**
- Removed Feedly API integration (requires Pro subscription)
- Added RSS/Atom parsing capabilities
- Added Core Data for local persistence
- Added background feed refresh service
- Added OPML import/export for feed migration
- Simplified authentication (no OAuth needed)

---

## System Overview

A native macOS RSS reader that fetches and parses RSS/Atom feeds directly, storing all data locally with Core Data. Focused on keyboard-driven navigation and efficient reading workflows.

**Core Principles:**
- Local-first: No cloud dependencies
- Direct feed fetching: Parse RSS/Atom ourselves
- Native macOS: SwiftUI + proper HIG compliance
- Keyboard-first: Efficient navigation without mouse
- Simple & Fast: Quick launch, smooth scrolling

---

## Architecture Layers
```
┌─────────────────────────────────────────────────────────┐
│                    SwiftUI Views                         │
│  (ContentView, SidebarView, ArticleListView, etc.)      │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                    View Models (MVVM)                    │
│  (FeedListViewModel, ArticleListViewModel, etc.)        │
│              Uses @Published + Combine                   │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                    Service Layer                         │
│  - FeedService (fetch, parse, store)                    │
│  - RefreshService (background updates)                  │
│  - OPMLService (import/export)                          │
│  - ArticleService (mark read, cleanup)                  │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                  Core Data Layer                         │
│  Entities: Folder, Feed, Article, AppSettings           │
│  Managed Object Context + Background Contexts           │
└─────────────────────────────────────────────────────────┘
```

---

## Core Data Schema

### Entities

#### **Folder**
```swift
@Entity
class Folder: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var sortOrder: Int32
    @NSManaged var dateCreated: Date
    @NSManaged var feeds: NSSet // relationship to Feed
    
    // Computed
    var unreadCount: Int {
        feeds.compactMap { $0 as? Feed }
             .reduce(0) { $0 + $1.unreadCount }
    }
}
```

#### **Feed**
```swift
@Entity
class Feed: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var feedURL: URL
    @NSManaged var siteURL: URL?
    @NSManaged var iconURL: URL?
    @NSManaged var folder: Folder?
    @NSManaged var lastFetched: Date?
    @NSManaged var lastError: String?
    @NSManaged var refreshInterval: Int32 // minutes
    @NSManaged var articles: NSSet // relationship to Article
    
    // Computed
    var unreadCount: Int {
        articles.compactMap { $0 as? Article }
                .filter { !$0.isRead }
                .count
    }
}
```

#### **Article**
```swift
@Entity
class Article: NSManagedObject {
    @NSManaged var id: String // feed-specific article ID
    @NSManaged var feed: Feed
    @NSManaged var title: String
    @NSManaged var author: String?
    @NSManaged var published: Date
    @NSManaged var summary: String?
    @NSManaged var content: String? // full content if available
    @NSManaged var link: URL
    @NSManaged var thumbnailURL: URL?
    @NSManaged var isRead: Bool
    @NSManaged var dateAdded: Date
}
```

#### **AppSettings**
```swift
@Entity
class AppSettings: NSManagedObject {
    @NSManaged var id: UUID // singleton entity
    @NSManaged var refreshInterval: Int32 // default 10 minutes
    @NSManaged var articleRetentionDays: Int32 // default 30
    @NSManaged var articleRetentionCount: Int32 // default 1000 per feed
    @NSManaged var lastCleanupDate: Date?
}
```

### Relationships
- Folder ↔ Feed: One-to-many
- Feed ↔ Article: One-to-many

### Indexes
- Article: `feed` + `published` (for sorting)
- Article: `isRead` (for filtering)
- Article: `dateAdded` (for cleanup)

---

## RSS/Atom Parsing

### Approach: FeedKit Library (Recommended)

**Why FeedKit:**
- ✅ Mature, well-tested Swift package
- ✅ Supports RSS 0.90, 0.91, 1.0, 2.0 and Atom
- ✅ Handles malformed feeds gracefully
- ✅ Active maintenance

**Alternative:** Built-in XMLParser (more control, more code)

### Parser Service
```swift
class FeedParserService {
    func parse(data: Data) throws -> ParsedFeed {
        let parser = FeedParser(data: data)
        let result = parser.parse()
        
        switch result {
        case .success(let feed):
            return convertToModel(feed)
        case .failure(let error):
            throw FeedError.parsingFailed(error)
        }
    }
    
    private func convertToModel(_ feed: Feed) -> ParsedFeed {
        switch feed {
        case .rss(let rssFeed):
            return convertRSS(rssFeed)
        case .atom(let atomFeed):
            return convertAtom(atomFeed)
        case .json(let jsonFeed):
            return convertJSON(jsonFeed)
        }
    }
}

struct ParsedFeed {
    let title: String
    let siteURL: URL?
    let description: String?
    let articles: [ParsedArticle]
}

struct ParsedArticle {
    let id: String // guid or link
    let title: String
    let author: String?
    let published: Date
    let summary: String?
    let content: String?
    let link: URL
    let thumbnailURL: URL?
}
```

---

## Background Feed Refresh

### Strategy: Timer + URLSession

**Architecture:**
```swift
class RefreshService: ObservableObject {
    @Published var isRefreshing = false
    @Published var lastRefreshDate: Date?
    
    private var timer: Timer?
    private let interval: TimeInterval // from AppSettings
    
    func startAutoRefresh() {
        timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            Task { await self?.refreshAllFeeds() }
        }
    }
    
    func refreshAllFeeds() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        let feeds = fetchAllFeeds() // from Core Data
        
        // Fetch feeds with concurrency limit
        await withTaskGroup(of: Void.self) { group in
            for feed in feeds {
                group.addTask {
                    await self.refreshFeed(feed)
                }
            }
        }
        
        lastRefreshDate = Date()
    }
    
    private func refreshFeed(_ feed: Feed) async {
        do {
            let data = try await URLSession.shared.data(from: feed.feedURL).0
            let parsed = try FeedParserService().parse(data: data)
            
            await MainActor.run {
                storeParsedFeed(parsed, for: feed)
                feed.lastFetched = Date()
                feed.lastError = nil
            }
        } catch {
            await MainActor.run {
                feed.lastError = error.localizedDescription
            }
        }
    }
}
```

**Concurrency:**
- Fetch max 5 feeds simultaneously
- Use TaskGroup for structured concurrency
- Exponential backoff for failed feeds

**Error Handling:**
- Store last error per feed
- Don't block entire refresh if one feed fails
- Show error icon in UI for failed feeds

---

## OPML Support

### Import Flow
```swift
class OPMLService {
    func importOPML(from url: URL) throws -> OPMLDocument {
        let data = try Data(contentsOf: url)
        let parser = OPMLParser(data: data)
        return try parser.parse()
    }
    
    func createFeeds(from opml: OPMLDocument, 
                     in context: NSManagedObjectContext) {
        for outline in opml.outlines {
            if outline.isFolder {
                let folder = Folder(context: context)
                folder.name = outline.title
                
                for feedOutline in outline.children {
                    createFeed(from: feedOutline, in: folder, context: context)
                }
            } else {
                createFeed(from: outline, in: nil, context: context)
            }
        }
        
        try? context.save()
    }
}

struct OPMLDocument {
    let title: String
    let outlines: [OPMLOutline]
}

struct OPMLOutline {
    let title: String
    let xmlURL: URL? // feed URL
    let htmlURL: URL? // website URL
    let children: [OPMLOutline]
    
    var isFolder: Bool { xmlURL == nil }
}
```

### Export Flow
```swift
extension OPMLService {
    func exportOPML() -> Data {
        let folders = fetchAllFolders()
        let opml = generateOPML(from: folders)
        return opml.xmlData()
    }
}
```

---

## SwiftUI View Hierarchy
```
RSSReaderApp
└── ContentView (3-pane layout)
    ├── SidebarView
    │   ├── FolderRowView
    │   │   └── FeedRowView
    │   └── UnfiledFeedsSection
    │       └── FeedRowView
    ├── ArticleListView
    │   └── ArticleRowView
    └── ArticleDetailView
        ├── ArticleMetadataView
        ├── ArticleContentView
        └── ArticleActionsView

Sheets/Popovers:
├── AddFeedSheet
├── EditFeedSheet
├── PreferencesWindow
└── ErrorAlert
```

### ContentView (3-Pane Layout)
```swift
struct ContentView: View {
    @StateObject private var feedViewModel = FeedListViewModel()
    @StateObject private var articleViewModel = ArticleListViewModel()
    @State private var selectedFeed: Feed?
    @State private var selectedArticle: Article?
    
    var body: some View {
        NavigationSplitView {
            // Left pane: Sidebar
            SidebarView(
                selectedFeed: $selectedFeed,
                viewModel: feedViewModel
            )
            .frame(minWidth: 200)
        } content: {
            // Middle pane: Article list
            ArticleListView(
                feed: selectedFeed,
                selectedArticle: $selectedArticle,
                viewModel: articleViewModel
            )
            .frame(minWidth: 300)
        } detail: {
            // Right pane: Article detail (2/3 width)
            if let article = selectedArticle {
                ArticleDetailView(article: article)
            } else {
                Text("Select an article")
                    .foregroundStyle(.secondary)
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: refreshAll) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")
            }
            ToolbarItem {
                Button(action: addFeed) {
                    Label("Add Feed", systemImage: "plus")
                }
            }
        }
    }
}
```

---

## Keyboard Shortcuts

### Implementation: NSEvent Monitoring
```swift
class KeyboardShortcutManager: ObservableObject {
    private var monitor: Any?
    
    func startMonitoring(
        onNextUnread: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onOpenLink: @escaping () -> Void
    ) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard !event.modifierFlags.contains(.command) else { return event }
            
            switch event.charactersIgnoringModifiers {
            case "n":
                onNextUnread()
                return nil
            case String(NSUpArrowFunctionKey):
                onPrevious()
                return nil
            case String(NSDownArrowFunctionKey):
                onNext()
                return nil
            case " ", "\r": // space or enter
                onOpenLink()
                return nil
            default:
                return event
            }
        }
    }
    
    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
```

### Shortcut Map

| Key | Action |
|-----|--------|
| `n` | Next unread article |
| `↑` | Previous article in list |
| `↓` | Next article in list |
| `Space` / `Enter` | Open article link in Safari |
| `⌘R` | Refresh all feeds |
| `⌘N` | Add new feed |
| `⌘,` | Open preferences |
| `⌘W` | Close window |

---

## Article Retention & Cleanup

### Strategy

**Retention Rules:**
- Keep articles for 30 days (configurable)
- OR keep last 1000 articles per feed (whichever is less)
- Never delete unread articles

**Cleanup Schedule:**
- Run on app launch (if last cleanup > 24 hours ago)
- Run after each refresh cycle
- Background task to avoid UI blocking
```swift
class ArticleCleanupService {
    func performCleanup() async {
        let settings = fetchAppSettings()
        let cutoffDate = Date().addingTimeInterval(
            -Double(settings.articleRetentionDays) * 86400
        )
        
        let feeds = fetchAllFeeds()
        
        for feed in feeds {
            let articles = feed.articles
                .filter { $0.isRead } // don't delete unread
                .sorted { $0.dateAdded > $1.dateAdded }
            
            // Keep based on date
            let oldArticles = articles.filter { 
                $0.dateAdded < cutoffDate 
            }
            
            // Keep based on count
            let excessArticles = articles.count > settings.articleRetentionCount
                ? Array(articles.dropFirst(Int(settings.articleRetentionCount)))
                : []
            
            let toDelete = Set(oldArticles).union(Set(excessArticles))
            
            await deleteArticles(Array(toDelete))
        }
    }
}
```

---

## Error Handling

### Error Types
```swift
enum RSSReaderError: LocalizedError {
    case invalidFeedURL
    case networkError(URLError)
    case parsingFailed(Error)
    case feedNotFound
    case duplicateFeed
    case coreDataError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidFeedURL:
            return "The feed URL is not valid"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingFailed:
            return "Could not parse feed content"
        case .feedNotFound:
            return "No feed found at this URL"
        case .duplicateFeed:
            return "This feed is already subscribed"
        case .coreDataError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}
```

### User-Facing Error Handling

- **Feed refresh fails:** Show error icon next to feed, store error message
- **OPML import fails:** Show alert with specific error
- **Core Data errors:** Log and show generic "data error" to user
- **Network timeouts:** Retry with exponential backoff
- **Parsing errors:** Skip invalid articles, continue with valid ones

---

## Performance Considerations

### Database Optimization
- Fetch only visible articles (pagination in list)
- Use predicates to filter in Core Data, not memory
- Background contexts for writes (feed refresh)
- Batch delete for cleanup operations

### UI Performance
- Lazy loading in article list
- Image caching for thumbnails
- Debounce search/filter operations
- Virtual scrolling for large article lists

### Memory Management
- Release parsed feed data after storing
- Don't hold all articles in memory
- Use @FetchRequest with limits
- Periodic cleanup of image cache

---

## Technical Decisions & Trade-offs

### ✅ Chosen: FeedKit for Parsing
**Why:** Mature, handles edge cases, supports all formats
**Alternative:** XMLParser (more control, more code)

### ✅ Chosen: Core Data for Persistence
**Why:** Proven, performant, good SwiftUI integration
**Alternative:** SwiftData (too new, less mature)

### ✅ Chosen: Timer for Refresh
**Why:** Simple, works while app is active
**Alternative:** BGTaskScheduler (complex, for background-quit state)

### ✅ Chosen: Plain Text Article Display
**Why:** Simple, fast, consistent
**Alternative:** HTML rendering (complex, security concerns)

### ✅ Chosen: Direct Feed URLs Only (MVP)
**Why:** Simpler implementation
**Future:** Add HTML parsing for feed discovery

---

## Security Considerations

### Feed URLs
- Validate URLs before fetching
- Use https:// when available
- Handle redirects safely (limit chain)
- Timeout after 30 seconds

### Article Content
- Strip JavaScript from HTML (if rendering)
- Sanitize URLs before opening in Safari
- Don't execute any embedded content

### User Data
- Core Data encrypted at rest (macOS handles this)
- No credentials to store (local-only)
- Export OPML doesn't include read states

---

## Dependencies

### Swift Packages
- **FeedKit**: RSS/Atom parsing
  - Repo: https://github.com/nmdias/FeedKit
  - Version: ~9.1

### System Frameworks
- SwiftUI (UI)
- Combine (reactive bindings)
- Core Data (persistence)
- Foundation (networking, date handling)
- SafariServices (opening links)
- AppKit (keyboard events, NSEvent monitoring)

---

## Testing Strategy

### Unit Tests
- FeedParserService: RSS/Atom parsing with sample feeds
- RefreshService: Mock network responses
- OPMLService: Import/export with sample OPML files
- ArticleCleanupService: Retention logic with test data

### Integration Tests
- Core Data CRUD operations
- Feed fetch → parse → store pipeline
- OPML import → create feeds → verify structure

### UI Tests (Manual for MVP)
- Add feed flow
- Import OPML
- Keyboard navigation
- Article reading and marking as read

### Test Data
- Sample RSS 2.0 feeds
- Sample Atom feeds
- Malformed XML (edge cases)
- Sample OPML exports from Feedly

---

## Migration Path from Feedly

**User Steps:**
1. In Feedly: Settings → Import/Export → Export OPML
2. Save `feedly-export.opml` file
3. In RSS Reader: File → Import OPML
4. Select `feedly-export.opml`
5. App imports all feeds with folder structure
6. Initial refresh fetches recent articles

**Notes:**
- Read/unread state does NOT migrate
- All articles start as unread
- Folder structure IS preserved
- Feed URLs remain the same

---

## Future Enhancements (Post-MVP)

### Sync (v2)
- iCloud sync via CloudKit
- Or custom backend with REST API
- Sync read states, subscriptions, folders

### Advanced Features
- Full-text search
- Article starring/favoriting
- Smart folders (filters)
- Custom article filters
- Reader view (fetch full article)
- Dark mode

### Polish
- Feed icons/favicons
- Article images inline
- Customizable shortcuts
- Statistics/analytics
- Feed health monitoring

---

## Open Questions

1. **RSS Parsing Library:** FeedKit (recommended) or XMLParser?
2. **Feed Icons:** Fetch favicons in MVP or defer to v2?
3. **Article Content:** Strict plain text or allow basic HTML formatting?
4. **HTML Feed Discovery:** Auto-discover from website URLs in MVP?
5. **Concurrent Fetching:** Limit to 5 feeds or make configurable?
6. **Article Deduplication:** Implement in MVP or defer? (User requested this)

---

## Implementation Order

**Sprint 1 (Week 1):**
1. Core Data schema + stack
2. FeedParserService implementation
3. Basic feed add/remove
4. OPML import
5. Article list view
6. Article detail view

**Sprint 2 (Week 2):**
7. RefreshService (background refresh)
8. Keyboard shortcuts
9. Folder management UI
10. Article cleanup service
11. Error handling polish
12. OPML export

---

## Success Criteria

### Functional
- ✅ Import Feedly OPML successfully
- ✅ Fetch and parse 25+ feeds without errors
- ✅ Display articles in 3-pane layout
- ✅ Keyboard shortcuts work as specified
- ✅ Mark as read syncs correctly
- ✅ Safari link opening works

### Performance
- ✅ App launches in < 2 seconds
- ✅ Article list scrolls at 60fps
- ✅ Refresh 25 feeds in < 30 seconds
- ✅ No memory leaks

### UX
- ✅ Feels native to macOS
- ✅ Keyboard-first workflow is smooth
- ✅ No crashes or data loss
- ✅ Errors communicated clearly

---

## References

- [RSS 2.0 Specification](https://www.rssboard.org/rss-specification)
- [Atom 1.0 Specification](https://datatracker.ietf.org/doc/html/rfc4287)
- [OPML 2.0 Specification](http://opml.org/spec2.opml)
- [FeedKit Documentation](https://github.com/nmdias/FeedKit)
- [Core Data Programming Guide](https://developer.apple.com/documentation/coredata)
- [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
EOF