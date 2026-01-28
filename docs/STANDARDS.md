# Coding Standards

## Architecture
- MVVM pattern: Views → ViewModels → Models
- SwiftUI for all UI
- Combine for reactive bindings
- Protocol-oriented design

## Code Style
- SwiftLint enforced (see .swiftlint.yml)
- 100 character line limit
- 4 spaces indentation
- Descriptive variable names (no single letters except loop indices)

## Testing
- Minimum 80% code coverage
- Unit tests for all business logic
- UI tests for critical user flows
- Test file naming: [FileName]Tests.swift

## Dependencies
- Swift Package Manager only
- Minimize external dependencies
- Document why each dependency is needed

## Git Workflow
- Branch naming: feature/issue-X-short-description
- Commit messages: "[#X] Descriptive message"
- PRs must reference issue: "Closes #X"
- Squash merge to main
