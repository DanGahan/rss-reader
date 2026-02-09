Refactor: Resolve SwiftLint violations in SidebarView

This PR addresses and resolves several SwiftLint violations that were causing CI pipeline failures, primarily centered around the SidebarView.

Key changes include:

- **Refactored SidebarView:** The monolithic `SidebarView` struct has been broken down into smaller, more maintainable components:
    - `SidebarFoldersView`: Encapsulates the logic for displaying folders and their associated feeds, including drag-and-drop and context menu handling.
    - `SidebarUnfiledFeedsView`: Manages the display of unfiled feeds, including drag-and-drop and context menus.
  This refactoring resolves the `Type Body Length Violation` by significantly reducing the line count of the main `SidebarView`.

- **Addressed Line Length Violation:** A specific line length violation within `SidebarView` was resolved by reformatting the code for better readability and compliance with SwiftLint rules.

- **Cleaned up Trailing Whitespace and Newlines:** All identified `Trailing Newline Violation` and `Trailing Whitespace Violation` errors across `SidebarView.swift`, `SidebarFoldersView.swift`, and `SidebarUnfiledFeedsView.swift` have been corrected, ensuring cleaner code and adherence to style guidelines.

These changes improve code maintainability, readability, and ensure the CI pipeline passes without linting errors.
