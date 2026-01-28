# Technical Architecture: Feedly-Integrated macOS RSS Reader MVP

**Document Version:** 1.0
**Issue Reference:** #1
**Author:** Senior macOS Architect
**Date:** 2026-01-28
**Target Platform:** macOS 14.0+ (Sonoma)

---

## Executive Summary

This document outlines the technical architecture for a native macOS RSS reader that integrates with Feedly's API. The application follows SwiftUI MVVM patterns, prioritizes keyboard-driven workflows, and maintains native macOS design principles. The MVP focuses on read-only consumption with bidirectional sync for read/unread states.

---

## 1. System Architecture

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                         │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │  Sidebar    │  │ Article List │  │  Reading Pane    │   │
│  │  View       │  │    View      │  │     View         │   │
│  └──────┬──────┘  └──────┬───────┘  └────────┬─────────┘   │
└─────────┼─────────────────┼──────────────────┼──────────────┘
          │                 │                  │
          └─────────────────┼──────────────────┘
                            │
          ┌─────────────────▼──────────────────┐
          │          ViewModels                 │
          │  • FeedViewModel                    │
          │  • ArticleListViewModel             │
          │  • ArticleDetailViewModel           │
          │  • AuthenticationViewModel          │
          └─────────────────┬──────────────────┘
                            │
          ┌─────────────────▼──────────────────┐
          │         Service Layer               │
          │  • FeedlyAPIService                 │
          │  • AuthenticationService            │
          │  • CacheService                     │
          │  • KeyboardService                  │
          └─────────────────┬──────────────────┘
                            │
          ┌─────────────────▼──────────────────┐
          │        Data Models                  │
          │  • Feed, Category, Article          │
          │  • User, Subscription               │
          └─────────────────┬──────────────────┘
                            │
          ┌─────────────────▼──────────────────┐
          │      External Services              │
          │  • Feedly API (REST)                │
          │  • URLSession (Networking)          │
          │  • Keychain (Secure Storage)        │
          └─────────────────────────────────────┘
```

### 1.2 Architectural Patterns

- **MVVM (Model-View-ViewModel)**: Separation of concerns with SwiftUI bindings
- **Protocol-Oriented Design**: Testable interfaces for services
- **Reactive Programming**: Combine publishers for async operations
- **Repository Pattern**: Abstract data access layer for Feedly API
- **Coordinator Pattern**: Navigation and flow management (if needed for OAuth)

---

## 2. Data Models

### 2.1 Core Domain Models

```swift
// MARK: - User & Authentication

struct FeedlyUser: Codable, Identifiable {
    let id: String
    let email: String
    let fullName: String?
    let picture: URL?
    let givenName: String?
    let familyName: String?
    let locale: String?
}

struct AuthenticationToken: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: TimeInterval
    let scope: String?

    var expirationDate: Date {
        Date().addingTimeInterval(expiresIn)
    }
}

// MARK: - Feed Structure

struct Category: Identifiable, Hashable {
    let id: String
    let label: String
    var unreadCount: Int
    var feeds: [Feed]

    // Computed properties
    var displayName: String {
        label.replacingOccurrences(of: "user/\\d+/category/", with: "", options: .regularExpression)
    }
}

struct Feed: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let website: URL?
    let iconUrl: URL?
    let description: String?
    var unreadCount: Int
    let visualUrl: URL?
    let updated: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, website, description, updated
        case iconUrl = "iconUrl"
        case visualUrl = "visualUrl"
    }
}

struct Subscription: Identifiable, Codable {
    let id: String
    let title: String
    let categories: [CategoryReference]
    let website: URL?
    let iconUrl: URL?
    let visualUrl: URL?

    struct CategoryReference: Codable {
        let id: String
        let label: String
    }
}

// MARK: - Article

struct Article: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String?
    let published: Date
    let updated: Date?
    let summary: ArticleContent?
    let content: ArticleContent?
    let origin: Origin
    let canonical: [Link]?
    let alternate: [Link]?
    let visual: Visual?
    var isRead: Bool
    let engagement: Int?
    let keywords: [String]?

    // Computed properties
    var displayDate: String {
        published.formatted(date: .abbreviated, time: .shortened)
    }

    var primaryLink: URL? {
        alternate?.first?.href ?? canonical?.first?.href
    }

    var thumbnailUrl: URL? {
        visual?.url
    }

    var plainTextContent: String {
        let rawContent = content?.content ?? summary?.content ?? ""
        return rawContent.stripHTML()
    }

    struct ArticleContent: Codable, Hashable {
        let content: String
        let direction: String?
    }

    struct Origin: Codable, Hashable {
        let streamId: String
        let title: String
        let htmlUrl: URL?
    }

    struct Link: Codable, Hashable {
        let href: URL
        let type: String?
    }

    struct Visual: Codable, Hashable {
        let url: URL
        let width: Int?
        let height: Int?
        let contentType: String?
    }
}

// MARK: - API Response Models

struct StreamContents: Codable {
    let id: String
    let title: String?
    let direction: String?
    let items: [Article]
    let continuation: String?
    let updated: Date?
}

struct UnreadCountsResponse: Codable {
    let unreadcounts: [UnreadCount]
    let updated: Date?

    struct UnreadCount: Codable {
        let id: String
        let count: Int
        let updated: Date?
    }
}

struct SubscriptionsResponse: Codable {
    let subscriptions: [Subscription]
}
```

### 2.2 Session Cache Models

```swift
// Lightweight in-memory cache for session
struct SessionCache {
    var categories: [Category] = []
    var articles: [String: Article] = [:] // Keyed by article ID
    var lastRefresh: Date?
    var selectedCategoryId: String?
    var selectedArticleId: String?
}
```

---

## 3. Service Layer

### 3.1 FeedlyAPIService

**Purpose:** Handle all HTTP communication with Feedly API v3

```swift
protocol FeedlyAPIServiceProtocol {
    // Authentication
    func getAuthorizationURL() -> URL
    func exchangeCodeForToken(code: String) async throws -> AuthenticationToken
    func refreshToken(refreshToken: String) async throws -> AuthenticationToken

    // User Profile
    func getCurrentUser() async throws -> FeedlyUser

    // Subscriptions & Categories
    func getSubscriptions() async throws -> [Subscription]
    func getCategories() async throws -> [Category]
    func getUnreadCounts() async throws -> [UnreadCountsResponse.UnreadCount]

    // Articles
    func getStreamContents(
        streamId: String,
        unreadOnly: Bool,
        newerThan: Date?,
        continuation: String?
    ) async throws -> StreamContents

    // Mark as read
    func markArticleAsRead(articleId: String) async throws
    func markArticlesAsRead(articleIds: [String]) async throws
    func markStreamAsRead(streamId: String, asOf: Date) async throws
}

final class FeedlyAPIService: FeedlyAPIServiceProtocol {
    private let baseURL = "https://cloud.feedly.com/v3"
    private let clientId: String
    private let clientSecret: String
    private let redirectURI: String
    private var authToken: AuthenticationToken?

    // URLSession configuration
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    // Rate limiting
    private let rateLimiter = RateLimiter(requestsPerMinute: 60)

    // Implementation details...
}
```

### 3.2 AuthenticationService

**Purpose:** Manage OAuth 2.0 flow and token persistence

```swift
protocol AuthenticationServiceProtocol {
    var isAuthenticated: Bool { get }
    var currentUser: FeedlyUser? { get }

    func startOAuthFlow() async throws -> URL
    func handleCallback(url: URL) async throws -> FeedlyUser
    func logout() async throws
    func refreshTokenIfNeeded() async throws
}

final class AuthenticationService: AuthenticationServiceProtocol, ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: FeedlyUser?

    private let apiService: FeedlyAPIServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private var authToken: AuthenticationToken?

    // Implementation with Keychain storage...
}
```

### 3.3 CacheService

**Purpose:** In-memory session cache for articles and feeds

```swift
protocol CacheServiceProtocol {
    func cacheArticles(_ articles: [Article])
    func getArticle(id: String) -> Article?
    func updateArticleReadStatus(id: String, isRead: Bool)
    func clearCache()
    func getCachedCategories() -> [Category]
    func cacheCategories(_ categories: [Category])
}

final class CacheService: CacheServiceProtocol {
    private var cache = SessionCache()
    private let lock = NSLock()

    // Thread-safe cache operations
}
```

### 3.4 KeychainService

**Purpose:** Secure storage for OAuth tokens

```swift
protocol KeychainServiceProtocol {
    func save(token: AuthenticationToken) throws
    func retrieveToken() throws -> AuthenticationToken?
    func deleteToken() throws
}

final class KeychainService: KeychainServiceProtocol {
    private let service = "com.yourapp.feedlyreader"
    private let account = "feedlyToken"

    // Security.framework implementation
}
```

---

## 4. ViewModels

### 4.1 FeedViewModel

```swift
@MainActor
final class FeedViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var selectedCategory: Category?
    @Published var isLoading = false
    @Published var error: AppError?
    @Published var lastRefresh: Date?

    private let apiService: FeedlyAPIServiceProtocol
    private let cacheService: CacheServiceProtocol
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(
        apiService: FeedlyAPIServiceProtocol,
        cacheService: CacheServiceProtocol
    ) {
        self.apiService = apiService
        self.cacheService = cacheService
        setupAutoRefresh()
    }

    func loadCategories() async {
        // Load categories and unread counts
    }

    func refresh() async {
        // Manual refresh
    }

    private func setupAutoRefresh() {
        // 10-minute auto-refresh timer
    }
}
```

### 4.2 ArticleListViewModel

```swift
@MainActor
final class ArticleListViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var selectedArticle: Article?
    @Published var isLoading = false
    @Published var error: AppError?

    private let apiService: FeedlyAPIServiceProtocol
    private let cacheService: CacheServiceProtocol
    private var continuation: String?

    func loadArticles(for category: Category) async {
        // Load unread articles for category
    }

    func loadMoreArticles() async {
        // Pagination support
    }

    func selectNextUnread() {
        // Navigate to next unread article
    }

    func selectPrevious() {
        // Navigate to previous article
    }
}
```

### 4.3 ArticleDetailViewModel

```swift
@MainActor
final class ArticleDetailViewModel: ObservableObject {
    @Published var article: Article?
    @Published var isMarking = false

    private let apiService: FeedlyAPIServiceProtocol
    private let cacheService: CacheServiceProtocol

    func displayArticle(_ article: Article) async {
        self.article = article
        await markAsRead()
    }

    private func markAsRead() async {
        // Automatically mark as read when displayed
    }

    func openInSafari() {
        // Open primary link in Safari background tab
    }
}
```

---

## 5. User Interface Architecture

### 5.1 View Hierarchy

```swift
@main
struct FeedlyReaderApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.isAuthenticated {
                MainView()
                    .environmentObject(appState)
            } else {
                AuthenticationView()
                    .environmentObject(appState)
            }
        }
        .commands {
            KeyboardCommands()
        }
    }
}

struct MainView: View {
    @StateObject private var feedViewModel: FeedViewModel
    @StateObject private var articleListViewModel: ArticleListViewModel
    @StateObject private var articleDetailViewModel: ArticleDetailViewModel

    var body: some View {
        NavigationSplitView {
            // Left sidebar - Categories & Feeds
            SidebarView(viewModel: feedViewModel)
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
        } content: {
            // Middle pane - Article List
            ArticleListView(viewModel: articleListViewModel)
                .frame(minWidth: 300, idealWidth: 400)
        } detail: {
            // Right pane - Article Content
            ArticleDetailView(viewModel: articleDetailViewModel)
                .frame(minWidth: 500)
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

### 5.2 Key Views

**SidebarView:**
- Displays categories with disclosure groups
- Shows feeds within categories
- Displays unread count badges
- Handles selection state

**ArticleListView:**
- List of articles with metadata
- Thumbnail images (async loaded)
- Title, author, date
- Read/unread indicator
- Smooth scrolling with LazyVStack

**ArticleDetailView:**
- Article title and metadata header
- Plain text content (HTML stripped)
- Link button for Safari
- Automatic mark as read

**AuthenticationView:**
- OAuth login button
- Handles callback URL
- Loading and error states

---

## 6. Keyboard Navigation System

### 6.1 Key Bindings

```swift
struct KeyboardCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {}

        CommandMenu("Navigation") {
            Button("Next Unread") {
                NotificationCenter.default.post(name: .nextUnread, object: nil)
            }
            .keyboardShortcut("n", modifiers: [])

            Button("Refresh") {
                NotificationCenter.default.post(name: .refresh, object: nil)
            }
            .keyboardShortcut("r", modifiers: [])

            Button("Open in Safari") {
                NotificationCenter.default.post(name: .openInSafari, object: nil)
            }
            .keyboardShortcut(.return, modifiers: [])
            .keyboardShortcut(.space, modifiers: [])
        }
    }
}
```

### 6.2 Keyboard Service

```swift
final class KeyboardService: ObservableObject {
    enum KeyboardAction {
        case nextUnread
        case previousArticle
        case nextArticle
        case refresh
        case openInSafari
        case markReadUnread
    }

    func handleAction(_ action: KeyboardAction, context: KeyboardContext) {
        // Dispatch actions to appropriate ViewModels
    }
}
```

---

## 7. Error Handling Strategy

### 7.1 Error Types

```swift
enum AppError: LocalizedError, Identifiable {
    case authenticationFailed(String)
    case networkError(Error)
    case apiError(statusCode: Int, message: String)
    case invalidResponse
    case rateLimitExceeded
    case tokenExpired
    case noInternet

    var id: String { errorDescription ?? "" }

    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "Feedly API error (\(code)): \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .tokenExpired:
            return "Session expired. Please log in again."
        case .noInternet:
            return "No internet connection. Unable to connect to Feedly."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noInternet:
            return "Check your internet connection and try again."
        case .tokenExpired:
            return "Please log in again to continue."
        case .rateLimitExceeded:
            return "Wait a few minutes before trying again."
        default:
            return "Please try again later."
        }
    }
}
```

### 7.2 Error Presentation

- **Modal alerts** for critical errors (auth failure, no internet)
- **Inline error banners** for recoverable errors
- **Fail-hard approach**: No stale data displayed
- **Retry mechanisms** with exponential backoff

---

## 8. OAuth 2.0 Implementation

### 8.1 OAuth Flow

```
1. User clicks "Sign in with Feedly"
   ↓
2. App opens authorization URL in default browser
   URL: https://cloud.feedly.com/v3/auth/auth?
        response_type=code&
        client_id={CLIENT_ID}&
        redirect_uri={REDIRECT_URI}&
        scope=https://cloud.feedly.com/subscriptions
   ↓
3. User authenticates in browser
   ↓
4. Feedly redirects to custom URL scheme
   feedlyreader://oauth/callback?code={CODE}&state={STATE}
   ↓
5. App captures URL via URL handler
   ↓
6. Exchange code for access token
   POST /v3/auth/token
   {
     "code": "{CODE}",
     "client_id": "{CLIENT_ID}",
     "client_secret": "{CLIENT_SECRET}",
     "redirect_uri": "{REDIRECT_URI}",
     "grant_type": "authorization_code"
   }
   ↓
7. Store token in Keychain
   ↓
8. Load user profile and subscriptions
```

### 8.2 Custom URL Scheme

**Info.plist Configuration:**

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>feedlyreader</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.yourapp.feedlyreader</string>
    </dict>
</array>
```

**URL Handling:**

```swift
.onOpenURL { url in
    Task {
        await authViewModel.handleOAuthCallback(url)
    }
}
```

---

## 9. Performance Optimization

### 9.1 Strategies

1. **Lazy Loading**: Load articles on-demand, not all at once
2. **Image Caching**: Use AsyncImage with cache or custom image cache
3. **Pagination**: Load 20-50 articles initially, more on scroll
4. **Debouncing**: Debounce mark-as-read API calls
5. **Background Refresh**: Use background tasks for auto-refresh
6. **List Virtualization**: LazyVStack handles large lists efficiently

### 9.2 Memory Management

- **Max cached articles**: 500 articles in memory
- **LRU eviction**: Remove oldest articles when limit reached
- **Clear on logout**: Wipe all cached data
- **Image cache limit**: 50MB maximum

### 9.3 Network Optimization

- **Request batching**: Batch mark-as-read operations
- **Conditional requests**: Use If-Modified-Since headers
- **Compression**: Enable gzip compression
- **Connection pooling**: Reuse URLSession

---

## 10. Dependencies

### 10.1 External Dependencies (Swift Package Manager)

**None required for MVP**

All functionality can be implemented with native frameworks:
- **SwiftUI**: UI framework
- **Combine**: Reactive programming
- **Foundation**: Networking (URLSession)
- **Security**: Keychain storage
- **AppKit**: Safari integration (NSWorkspace)

### 10.2 Rationale for Zero Dependencies

- Minimizes attack surface
- Reduces build complexity
- Improves compile times
- Native frameworks are well-tested and maintained
- No dependency version conflicts

---

## 11. Testing Strategy

### 11.1 Test Coverage Targets

- **Service Layer**: 90%+ coverage
- **ViewModels**: 85%+ coverage
- **Models**: 100% coverage
- **Overall Target**: 80%+ coverage

### 11.2 Test Structure

```
Tests/
├── UnitTests/
│   ├── Services/
│   │   ├── FeedlyAPIServiceTests.swift
│   │   ├── AuthenticationServiceTests.swift
│   │   └── CacheServiceTests.swift
│   ├── ViewModels/
│   │   ├── FeedViewModelTests.swift
│   │   ├── ArticleListViewModelTests.swift
│   │   └── ArticleDetailViewModelTests.swift
│   └── Models/
│       └── ArticleTests.swift
├── IntegrationTests/
│   └── FeedlyAPIIntegrationTests.swift
└── UITests/
    ├── AuthenticationFlowUITests.swift
    └── ReadingWorkflowUITests.swift
```

### 11.3 Mocking Strategy

```swift
// Mock API Service for testing
final class MockFeedlyAPIService: FeedlyAPIServiceProtocol {
    var mockUser: FeedlyUser?
    var mockSubscriptions: [Subscription] = []
    var mockArticles: [Article] = []
    var shouldFail = false
    var apiCallCount = 0

    func getCurrentUser() async throws -> FeedlyUser {
        apiCallCount += 1
        if shouldFail { throw AppError.networkError(NSError()) }
        return mockUser ?? FeedlyUser.fixture()
    }

    // ... other mock implementations
}
```

---

## 12. Security Considerations

### 12.1 Token Storage

- **Keychain**: Store OAuth tokens in macOS Keychain
- **Access Control**: kSecAttrAccessibleAfterFirstUnlock
- **Encryption**: Automatic encryption by system

### 12.2 Network Security

- **HTTPS Only**: All API calls use HTTPS
- **Certificate Pinning**: Consider for production
- **No plaintext secrets**: Client secret in environment variable or secure config

### 12.3 Data Privacy

- **No local persistence**: Articles not stored permanently
- **Memory-only cache**: Cleared on app termination
- **Secure by default**: No analytics or tracking

---

## 13. Feedly API Integration

### 13.1 Key Endpoints

| Endpoint | Method | Purpose | Rate Limit |
|----------|--------|---------|------------|
| `/v3/auth/auth` | GET | OAuth authorization | - |
| `/v3/auth/token` | POST | Token exchange/refresh | - |
| `/v3/profile` | GET | User profile | 60/min |
| `/v3/subscriptions` | GET | User subscriptions | 60/min |
| `/v3/categories` | GET | Categories | 60/min |
| `/v3/markers/counts` | GET | Unread counts | 60/min |
| `/v3/streams/contents` | GET | Article stream | 60/min |
| `/v3/markers` | POST | Mark as read | 60/min |

### 13.2 Authentication Headers

```
Authorization: Bearer {ACCESS_TOKEN}
```

### 13.3 API Response Handling

```swift
func performRequest<T: Decodable>(
    _ endpoint: String,
    method: String = "GET",
    body: Data? = nil
) async throws -> T {
    var request = URLRequest(url: URL(string: baseURL + endpoint)!)
    request.httpMethod = method
    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw AppError.invalidResponse
    }

    switch httpResponse.statusCode {
    case 200...299:
        return try JSONDecoder().decode(T.self, from: data)
    case 401:
        throw AppError.tokenExpired
    case 429:
        throw AppError.rateLimitExceeded
    default:
        throw AppError.apiError(
            statusCode: httpResponse.statusCode,
            message: String(data: data, encoding: .utf8) ?? "Unknown error"
        )
    }
}
```

---

## 14. Risk Assessment

### 14.1 Technical Risks

| Risk | Severity | Probability | Mitigation |
|------|----------|-------------|------------|
| Feedly API rate limits too restrictive | High | Medium | Implement aggressive caching, batch operations, monitor usage |
| OAuth callback handling on macOS | Medium | Low | Use custom URL scheme, test extensively |
| Large article lists cause performance issues | Medium | Medium | Implement pagination, lazy loading, limit cache size |
| HTML content rendering issues | Low | Medium | Strip HTML, display plain text only for MVP |
| Token expiration during use | Medium | High | Implement automatic token refresh before expiration |
| No internet connectivity | Medium | High | Fail gracefully with clear error messages |
| API response format changes | Low | Low | Version API client, add response validation |

### 14.2 Product Risks

| Risk | Severity | Probability | Mitigation |
|------|----------|-------------|------------|
| Feedly API provides summaries only, not full content | High | High | Clarify during development, document limitation |
| User doesn't have Feedly Pro account (if required) | Medium | Medium | Research API tier requirements, document in README |
| Keyboard shortcuts conflict with system shortcuts | Low | Low | Test thoroughly, provide customization in v2 |
| 3-pane layout doesn't work on smaller screens | Low | Low | Set minimum window size, test on various displays |

### 14.3 Schedule Risks

| Risk | Severity | Probability | Mitigation |
|------|----------|-------------|------------|
| OAuth implementation takes longer than expected | High | Medium | Allocate extra time, research early |
| Feedly API registration delayed | High | Medium | Start registration process immediately |
| Performance optimization needed | Medium | Medium | Profile early, optimize iteratively |
| Scope creep (adding out-of-scope features) | Medium | High | Strict adherence to MVP definition |

---

## 15. Technical Constraints

### 15.1 Platform Constraints

- **macOS 14.0+**: Cannot use APIs from macOS 15
- **SwiftUI**: Limited compared to AppKit for some features
- **No AppKit**: Must find SwiftUI alternatives or bridge
- **Sandbox restrictions**: May limit some functionality

### 15.2 API Constraints

- **Read-only focus**: No feed management in MVP
- **Rate limits**: Must respect Feedly API limits
- **OAuth complexity**: Native app OAuth is complex
- **API quotas**: Unknown until testing

### 15.3 Design Constraints

- **Native macOS feel**: Must follow HIG
- **Keyboard-first**: All actions accessible via keyboard
- **No offline mode**: Requires active connection
- **Plain text only**: No rich HTML rendering

---

## 16. Implementation Breakdown

### 16.1 Sprint 1 (Week 1, Days 1-3): Foundation & Authentication

**Sub-tasks:**

1. **[Task] Project Setup** (2 hours)
   - Create Xcode project
   - Configure SwiftUI app structure
   - Set up folder structure (Models, Views, ViewModels, Services)
   - Add .swiftlint.yml configuration
   - Set up unit test target

2. **[Task] Feedly API Client Setup** (4 hours)
   - Register for Feedly API access
   - Create FeedlyAPIService protocol and implementation
   - Implement network request wrapper with error handling
   - Add URLSession configuration
   - Write unit tests for API client

3. **[Task] Data Models** (4 hours)
   - Implement User, AuthenticationToken models
   - Implement Feed, Category, Subscription models
   - Implement Article and related models
   - Add Codable conformance
   - Write model tests

4. **[Task] OAuth 2.0 Flow** (8 hours)
   - Implement AuthenticationService
   - Add custom URL scheme to Info.plist
   - Create OAuth authorization URL generation
   - Implement code exchange for token
   - Add token refresh logic
   - Test OAuth flow end-to-end

5. **[Task] Keychain Integration** (3 hours)
   - Implement KeychainService
   - Add token storage
   - Add token retrieval
   - Add token deletion
   - Write keychain tests

6. **[Task] Authentication UI** (4 hours)
   - Create AuthenticationView
   - Add login button
   - Implement loading states
   - Add error handling UI
   - Test authentication flow

### 16.2 Sprint 1 (Week 1, Days 4-5): Core Data Loading

**Sub-tasks:**

7. **[Task] Subscription Loading** (4 hours)
   - Implement getSubscriptions API call
   - Parse subscription response
   - Transform into Category and Feed models
   - Add caching logic
   - Write tests

8. **[Task] Unread Counts** (3 hours)
   - Implement getUnreadCounts API call
   - Map counts to feeds and categories
   - Update models with counts
   - Write tests

9. **[Task] Article Stream Loading** (5 hours)
   - Implement getStreamContents API call
   - Add pagination support (continuation token)
   - Filter for unread only
   - Parse article response
   - Write tests

10. **[Task] Cache Service** (4 hours)
    - Implement in-memory cache
    - Add thread-safety with NSLock
    - Implement LRU eviction
    - Add cache size limits
    - Write cache tests

### 16.3 Sprint 2 (Week 2, Days 1-2): UI Implementation

**Sub-tasks:**

11. **[Task] Sidebar View** (6 hours)
    - Create SidebarView with List
    - Implement category disclosure groups
    - Display feeds within categories
    - Add unread count badges
    - Handle selection state
    - Apply macOS styling (SF Symbols)

12. **[Task] Article List View** (6 hours)
    - Create ArticleListView with LazyVStack
    - Display article metadata (title, author, date)
    - Add thumbnail image loading (AsyncImage)
    - Show read/unread indicator
    - Handle selection state
    - Implement smooth scrolling

13. **[Task] Article Detail View** (5 hours)
    - Create ArticleDetailView
    - Display article title and metadata
    - Render plain text content (strip HTML)
    - Add "Open in Safari" button
    - Implement link handling

14. **[Task] Main Window Layout** (4 hours)
    - Create NavigationSplitView structure
    - Configure 3-pane layout
    - Set minimum/ideal widths
    - Test responsive behavior
    - Apply window styling

### 16.4 Sprint 2 (Week 2, Days 3-4): Functionality & Polish

**Sub-tasks:**

15. **[Task] Mark as Read** (5 hours)
    - Implement markAsRead API call
    - Add automatic marking when article displayed
    - Update local cache immediately
    - Handle errors gracefully
    - Write tests

16. **[Task] Keyboard Navigation** (6 hours)
    - Implement KeyboardService
    - Add keyboard shortcuts (n, ↑, ↓, Enter, Space)
    - Wire up next unread navigation
    - Wire up list navigation
    - Wire up Safari opening
    - Test all shortcuts

17. **[Task] Refresh Logic** (4 hours)
    - Implement manual refresh
    - Add refresh button in toolbar
    - Implement auto-refresh timer (10 minutes)
    - Show loading indicators
    - Handle refresh errors

18. **[Task] Safari Integration** (2 hours)
    - Implement openInSafari method using NSWorkspace
    - Open links in background tabs
    - Handle missing links gracefully
    - Test with various link types

### 16.5 Sprint 2 (Week 2, Day 5): Testing & Bug Fixes

**Sub-tasks:**

19. **[Task] Error Handling Polish** (4 hours)
    - Review all error cases
    - Add user-friendly error messages
    - Implement error recovery UI
    - Test no internet scenario
    - Test token expiration scenario

20. **[Task] Performance Testing** (3 hours)
    - Profile with Instruments
    - Test with 25+ feeds
    - Test with 500+ articles
    - Optimize bottlenecks
    - Verify 60fps scrolling

21. **[Task] UI/UX Polish** (4 hours)
    - Review HIG compliance
    - Adjust spacing and alignment
    - Add loading states
    - Test dark mode (system default)
    - Fix visual bugs

22. **[Task] Integration Testing** (3 hours)
    - End-to-end authentication test
    - Full reading workflow test
    - Keyboard navigation test
    - Refresh flow test

23. **[Task] Documentation** (2 hours)
    - Write README.md
    - Document setup process
    - Add Feedly API registration instructions
    - Document known limitations
    - Create basic user guide

---

## 17. Open Questions & Decisions Needed

### 17.1 Immediate Questions

1. **Feedly API Access**
   - Does user have API credentials?
   - Action: Register at https://developer.feedly.com/
   - Need: Client ID and Client Secret

2. **OAuth Redirect URI**
   - Decision: Use custom URL scheme `feedlyreader://oauth/callback`
   - Alternative: Local server at `http://localhost:8080/callback`
   - Recommendation: Custom URL scheme (simpler, more native)

3. **Article Content Quality**
   - Question: Does Feedly API return full article content or summaries?
   - Action: Test during development
   - Fallback: Display summary if full content unavailable

4. **Rate Limiting**
   - Question: What are actual rate limits?
   - Action: Monitor during development
   - Mitigation: Implement rate limiter service

### 17.2 Design Decisions

5. **Auto-refresh Interval**
   - Default: 10 minutes
   - Question: Should this be configurable in v1?
   - Recommendation: Hardcode for MVP, add settings in v2

6. **Article Cache Size**
   - Proposal: 500 articles max
   - Question: Is this sufficient for 25 feeds?
   - Calculation: 25 feeds × 20 articles = 500 ✓

7. **Image Caching**
   - Option A: Use AsyncImage (no control)
   - Option B: Custom cache with NSCache
   - Recommendation: AsyncImage for MVP, custom in v2

### 17.3 Technical Decisions

8. **Pagination Strategy**
   - Load 50 articles initially
   - Load 50 more when scrolled to bottom
   - Use Feedly's continuation token

9. **Mark as Read Timing**
   - Immediately when article displayed
   - No delay or timer
   - Batch API calls (debounce 2 seconds)

10. **Error Recovery**
    - Fail hard on critical errors (no internet, auth failure)
    - Show inline errors for recoverable issues
    - Provide retry button where appropriate

---

## 18. Success Metrics

### 18.1 Technical Metrics

- **Unit Test Coverage**: ≥80%
- **API Call Latency**: <2 seconds average
- **Memory Usage**: <200MB with 500 articles
- **Scrolling Performance**: 60fps with 500 articles
- **Crash Rate**: <0.1%

### 18.2 Product Metrics

- **Daily Driver Viability**: Developer uses it daily for 2+ weeks
- **Keyboard Efficiency**: Can read 100 articles in <15 minutes
- **Sync Reliability**: Read states persist 100% of the time
- **Native Feel**: Indistinguishable from AppKit apps

---

## 19. Future Enhancements (Post-MVP)

### 19.1 Version 2 Features

- Article deduplication
- Search within articles
- Customizable keyboard shortcuts
- Dark mode explicit support (beyond system default)
- Settings panel (refresh interval, display options)
- Mark as read/unread toggle

### 19.2 Version 3+ Features

- Starred/saved articles
- Article tagging (if Feedly supports)
- Multiple account support
- Feed management (add/remove feeds)
- Smart folders and filters
- Article sharing

---

## 20. Appendix

### 20.1 Feedly API Resources

- **Developer Portal**: https://developer.feedly.com/
- **API Documentation**: https://developer.feedly.com/v3/
- **OAuth Guide**: https://developer.feedly.com/v3/auth/
- **Rate Limits**: https://developer.feedly.com/v3/limits/

### 20.2 macOS Development Resources

- **Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/macos
- **SwiftUI Documentation**: https://developer.apple.com/documentation/swiftui
- **Combine Framework**: https://developer.apple.com/documentation/combine

### 20.3 Architectural Patterns

- **MVVM in SwiftUI**: https://www.swiftbysundell.com/articles/mvvm-in-swiftui/
- **Protocol-Oriented Programming**: https://www.swiftbysundell.com/articles/protocol-oriented-programming/
- **Async/Await Best Practices**: https://www.swiftbysundell.com/articles/async-await-best-practices/

---

## Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-28 | Senior macOS Architect | Initial architecture document |

---

**Next Steps:**
1. Review and approve this architecture
2. Set up Feedly API developer account
3. Begin Sprint 1 implementation
4. Create GitHub issues for each sub-task
