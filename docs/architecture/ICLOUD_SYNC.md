# iCloud Sync - Technical Architecture
**Version:** 1.0
**Status:** In-Progress

---

## 1. System Overview

This document outlines the architectural changes required to integrate iCloud synchronization into the RSS Reader application. The primary goal is to sync user data—specifically feed subscriptions, folder structures, and article read/unread status—across multiple macOS devices signed into the same iCloud account.

The chosen technology is **Core Data with CloudKit (`NSPersistentCloudKitContainer`)**, as it is Apple's recommended solution for this use case. It provides a robust, out-of-the-box solution for mirroring a Core Data store to a private iCloud database.

The integration will involve:
- Refactoring the existing persistence controller to use `NSPersistentCloudKitContainer`.
- Updating the Core Data model and entity constraints to be compatible with CloudKit.
- Implementing UI elements to manage and display sync status.
- Devising a testing strategy for the new sync functionality.

---

## 2. Persistence Layer Refactoring

The current `PersistenceController` uses a standard `NSPersistentContainer`. This will be replaced with `NSPersistentCloudKitContainer`.

### 2.1. New `PersistenceController` Implementation
```swift
import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "RSSReader")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // Configure the container to sync to iCloud
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("###<FATAL>### Failed to retrieve a persistent store description.")
        }
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Enable CloudKit synchronization
        let cloudKitContainerIdentifier = "iCloud.com.yourcompany.RSSReader" // <-- NEEDS TO BE UPDATED
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerIdentifier)

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
```

### 2.2. Project Configuration
- **Capabilities:** The "iCloud" capability must be enabled in the project settings, with the "CloudKit" service checked.
- **Entitlements:** A new `.entitlements` file will be created, granting the app permission to use the specified iCloud container.
- **App ID:** The application's bundle identifier will need a corresponding App ID with iCloud capabilities configured in the Apple Developer portal.

---

## 3. Data Model & Schema Changes

CloudKit imposes certain constraints on the Core Data model.

### 3.1. Uniqueness Constraints

A critical issue is that CloudKit does not support the `uniqueConstraints` attribute used in Core Data entities. The `CDArticle` entity currently uses this to prevent duplicate articles from the same feed.

**Problem:** The current model defines `uniqueConstraints = [["id", "feed"]]`. This will cause the app to crash on launch when used with `NSPersistentCloudKitContainer`.

**Solution:**
1.  **Remove the unique constraint** from the `CDArticle` entity in the `.xcdatamodeld` file.
2.  **Implement a manual de-duplication process.** Before creating a new `CDArticle`, the application must first perform a fetch request to see if an article with the same `id` and `feed` relationship already exists.

```swift
// Example: De-duplication logic in ArticleCreationService
func createArticle(from parsedArticle: ParsedArticle, for feed: CDFeed, in context: NSManagedObjectContext) {
    let fetchRequest: NSFetchRequest<CDArticle> = CDArticle.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "id == %@ AND feed == %@", parsedArticle.id, feed)
    
    do {
        let existingArticles = try context.fetch(fetchRequest)
        if existingArticles.isEmpty {
            // No duplicate found, create new article
            let newArticle = CDArticle(context: context)
            // ... configure newArticle ...
        } else {
            // Duplicate found, do nothing or update existing
        }
    } catch {
        // Handle fetch error
    }
}
```

### 3.2. Syncing Article Status Only

The `CDArticle` entity contains several properties (`title`, `author`, `content`, `summary`, etc.). Syncing all of this data for every article across all feeds is inefficient and consumes unnecessary iCloud storage. The primary user need is to sync the *read/unread status*.

**Proposed Solution:**
- We will continue to sync the entire `CDArticle` object for now. CloudKit is delta-based, so it should only sync changed properties (like `isRead`).
- If performance or storage becomes an issue, a future optimization could be to split `CDArticle` into two entities: `CDArticle` (static content) and `CDArticleStatus` (`isRead`, `isStarred`, etc.). This would create a one-to-one relationship and only the `CDArticleStatus` object would be regularly updated and synced. For this epic, we will deem this as over-engineering and stick with the simpler model.

---

## 4. UI/UX Considerations

Users need to be aware of the sync status.

### 4.1. Settings View
A new section in the `SettingsView` will be added to display:
- **Sync Status:** (e.g., "Syncing...", "Up to date", "Error").
- **Last Sync Date:** The timestamp of the last successful sync.
- **Enable/Disable Switch:** A toggle to enable or disable iCloud sync. Disabling sync should revert the app to a purely local store.

This will require a new `SyncStatusViewModel` that can observe notifications from the `NSPersistentCloudKitContainer`.

---

## 5. Testing Strategy

Testing iCloud sync is complex.

- **Unit Tests:** The de-duplication logic must be thoroughly unit tested.
- **Integration Tests:**
    - A separate `inMemory` Core Data stack should be used for most tests to avoid iCloud dependencies.
    - A dedicated test suite will be needed for the iCloud functionality. This may involve:
        - Running tests on two separate devices/simulators.
        - Using a separate iCloud container identifier for the test target.
        - Pre-populating a test account with data and verifying it syncs correctly to a clean device.

---

## 6. Implementation Breakdown (Sub-tasks)

1.  **Project Configuration:**
    - Create a new App ID with iCloud capabilities in the Apple Developer portal.
    - Add the iCloud capability and a new container identifier in Xcode.
    - Generate and configure the `.entitlements` file.

2.  **Refactor Persistence Layer:**
    - Update `PersistenceController` to use `NSPersistentCloudKitContainer`.
    - Implement the necessary store description options for history tracking and remote change notifications.

3.  **Data Model Migration:**
    - Create a new version of the `.xcdatamodeld`.
    - Remove the `uniqueConstraints` attribute from the `CDArticle` entity.
    - Implement the manual de-duplication logic when fetching and creating new articles.

4.  **UI for Sync Status:**
    - Create a `SyncStatusViewModel` to monitor and report CloudKit sync status.
    - Add a new "iCloud Sync" section to the `SettingsView` to display the status and provide an on/off toggle.

5.  **Testing:**
    - Write unit tests for the article de-duplication logic.
    - Create an integration test plan for verifying end-to-end sync functionality. (Manual testing may be required here).

---

## 7. Open Questions

1.  **Schema Migration:** What is the best strategy for users who already have local data? Will enabling sync automatically upload their existing store, or do we need a manual migration path? (Answer: `NSPersistentCloudKitContainer` handles this automatically, but we need to verify this behavior).
2.  **Conflict Resolution:** The default merge policy is `NSMergeByPropertyObjectTrumpMergePolicy`. Is this sufficient for all cases? (e.g., if a user renames the same folder differently on two offline devices). (Answer: For this epic, we will accept the default "last-in-wins" policy, as it covers the vast majority of use cases).
