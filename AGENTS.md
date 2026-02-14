# Agent Guidelines

## Code Changes

- Follow existing code style and patterns
- Use `BrowserEngine` for all WebKit configuration
- Keep privacy-focused defaults in `PrivacyPolicy`
- Add unit tests for new functionality

## Pull Requests

- Batch related changes into a single PR
- Do not create PRs for individual file refactors — wait until the feature is complete
- Include test output in PR description if tests don't pass yet
- Reference any related issues

## Architecture

```
ContentView → HardenedWebView → BrowserEngine → WKWebView
```

- **ContentView**: Screen-level UI composition
- **HardenedWebView**: SwiftUI ↔ UIKit bridge
- **BrowserEngine**: WebKit configuration factory
- **HTTPSUpgradeLogic**: Testable policy decisions

## Testing

- Unit tests go in `KratosTests/`
- Use `@testable import Kratos` for internal access
- Test policy logic via `HTTPSUpgradeLogic.decidePolicy(for:httpsOnly:)`
