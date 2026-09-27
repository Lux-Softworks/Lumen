# Lumen

On-device, no-backend iOS browser (SwiftUI + WKWebView). It reads along as the user browses, files pages they engage with into a local knowledge base, and answers questions about it with an on-device LLM. Inference, embeddings, search, and storage are all local.

This file is the map. Depth lives in [`docs/`](docs/index.md).

## Golden rules

1. **No comments in Swift code.** None: not explanatory, not banner, not `// why`. Use clear names and small functions instead.
2. **Verify with `scripts/test.sh`; the human runs the app.** Agents may build and run tests from the terminal only through that script. Launching or driving the app is done by the human in Xcode (⌘R). See [docs/testing.md](docs/testing.md).
3. **`swiftlint --strict` must pass.** CI runs it before anything else. No `print()`: use `KnowledgeLogger` or `Logger`, and give every logger interpolation a `privacy:` level.
4. **The LLM never runs in the Simulator.** Every `LocalKnowledgeProvider` entry point returns canned stubs under `#if targetEnvironment(simulator)`. Anything touching AI answers, summaries, or topic picks must be confirmed on a physical device.
5. **Prompt text lives only in `KnowledgePrompts`.** Tune the model's behavior there, not by swapping the model. It is tiny: constrain it with clean context, low temperature, and short positive prompts rather than long instructions.
6. **Respect actor isolation.** `KnowledgeStorage` and `LocalKnowledgeProvider` are `actor`s; view models are `@MainActor`. Swift 6.2 strict concurrency is on.
7. **No capture in incognito, or when `BrowserSettings.collectKnowledge` is off.** Both are checked at the top of `KnowledgeCaptureService.capture`.
8. **Nothing the user reads leaves the device.** The only network calls are the one-time model download, search suggestions, and favicons fetched from the site itself.
9. **New dependencies need justification.** The set is deliberately small: `mlx-swift`, `mlx-swift-lm`, `swift-transformers`, `swift-readability`/`SwiftSoup`, `swift-crypto`.

## Project tree

```
Lumen/
  App/                 LumenApp (@main), AppBootstrap, lifecycle hooks
  Core/                settings, privacy policy, URL normalizing, logging, small utilities
  Features/Browser/    tabs, web view engine, reading signals, the capture pipeline
    Knowledge/         capture → extract → classify → KnowledgeStorage (SQLite)
    Web/               BrowserEngine (hardened WKWebView config), injected scripts
  Features/Export/     Markdown vault and JSON export of the library
  Knowledge/           LLM provider, prompts, prompt budgeting, answer scoring
  Services/            tracker blocking, HTTPS upgrade, threat detection
  UI/                  SwiftUI views: bottom bar, settings, knowledge panel, theme
LumenTests/            unit tests (Swift Testing)
LumenUITests/          UI tests (XCTest)
Configuration/         signing settings (Signing.xcconfig + a gitignored local override)
scripts/test.sh        build + run tests on a Simulator
```

## Where to look

| Question                                                                    | Read                                                 |
| --------------------------------------------------------------------------- | ---------------------------------------------------- |
| How capture and asking work end to end                                      | [docs/architecture.md](docs/architecture.md)         |
| How to run tests, write new ones, and what can't be tested in the Simulator | [docs/testing.md](docs/testing.md)                   |
| Product overview, privacy promises, manual build steps                      | [README.md](README.md)                               |
| Lint rules                                                                  | [.swiftlint.yml](.swiftlint.yml)                     |
| What CI checks                                                              | [.github/workflows/ci.yml](.github/workflows/ci.yml) |

## Gotchas

- **SourceKit reports false "Cannot find type 'X' in scope"** for cross-module symbols (`EmbeddingService`, `ChatMessage`, `PageContent`, `URLNormalizer`, …). That is editor noise; `scripts/test.sh` is the real check.
- **Bumping `EmbeddingService.embeddingVersion` clears and re-embeds everything** in the user's library.
- **Keep new retrieval scoring on the existing scale.** Retrieval blends FTS keyword hits, semantic cosine, and `rankPagesByVector` (the max of best-chunk and page-embedding similarity); `rerankByRelevance` re-scores candidates on that same scale.
- **Signing lives in `Configuration/Signing.xcconfig`**, not in the project file. To sign with another team, copy `Configuration/Signing.local.example.xcconfig` to `Configuration/Signing.local.xcconfig` (gitignored) and fill it in. Never put `DEVELOPMENT_TEAM` or a literal bundle id back into `project.pbxproj`.
