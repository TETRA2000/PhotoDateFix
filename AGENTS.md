# Agent Instructions

Guidelines for AI agents (Claude Code, Xcode Copilot, etc.) working on this project.

## Keep README.md Up to Date

When making changes to the project, update `README.md` to reflect:

- New or removed source files in the **Project Structure** section
- Changes to supported iOS versions or Xcode requirements
- New frameworks added to the project (update **Key Frameworks**)
- Changes to core functionality described in **How It Works**

Do not update the README for minor internal refactors that don't affect the public-facing description.

## Code Style

- **Swift/SwiftUI** project targeting iOS
- Use `@Observable` for state management; avoid Combine
- Use Swift concurrency (`async`/`await`) instead of completion handler patterns where possible
- 4-space indentation
- PascalCase for types, camelCase for properties and methods
- Add comments only where logic is non-obvious

## Architecture

- `PhotoLibraryService` is the central service handling all PhotoKit and ImageIO interactions
- Views are kept thin — business logic belongs in the service layer
- No SwiftData or Core Data; the app operates directly on the photo library

## Testing

- Use the Swift Testing framework (`import Testing`) for unit tests
- Use XCUIAutomation for UI tests
- The app requires a real photo library, so most logic testing should focus on pure functions (e.g., EXIF date parsing, time difference formatting)
