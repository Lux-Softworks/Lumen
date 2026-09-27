# Architecture

Lumen has three moving parts: a hardened browser, a capture pipeline that quietly files pages the user actually reads, and an ask flow that answers questions from those pages with a local LLM. All of it runs on the device.

## Startup

`LumenApp` (`App/LumenApp.swift`, the `@main` entry) calls `AppBootstrap.shared.start()` and shows `BrowserView`. The bootstrap opens the knowledge database (`KnowledgeStorage.shared.initialize()`) and loads the tracker list (`TrackerDatabase`) in parallel. It exposes its progress as a state (`pending` → `initializing` → `ready` or `failed`); `retry()` starts it again after a failure.

## Browser layer

`Features/Browser/`

- `TabManager` owns the open tabs. Each `Tab` has a `BrowserViewModel` and one `WKWebView`.
- `BrowserEngine` (`Web/Engine/BrowserEngine.swift`) builds each web view's configuration from a `PrivacyPolicy`. It installs the tracker-blocking rule lists and injects the page scripts: safe-area insets, fingerprinting detection, tracker scan, reading signal, and annotation capture.
- Incognito is a flag stored on the web view itself, read back with `BrowserEngine.isIncognito(webView)`.
- `Services/` holds the privacy machinery: `ContentBlockingRules` and `TrackerBlockList` (built from the Disconnect list), HTTPS upgrade logic, `NetworkInterceptor`, and `ThreatDetector`.

## Capture pipeline: page → knowledge base

The pipeline starts when a page is actually read, not merely opened.

1. **Reading signal.** `ReadingSignalScript` runs in the page and reports reading time and scroll depth. Once they cross the thresholds in `ReadingSignalConfig`, it posts a `readingSignal` message.
2. **Handler.** `ReadingSignalHandler` receives the message, drops excluded URLs, and calls `KnowledgeCaptureService.shared.handleSignal(...)`. A later update message calls `handleUpdateSignal` instead.
3. **Gates.** `KnowledgeCaptureService.capture` (`Features/Browser/Knowledge/KnowledgeCapture.swift`) returns early when collection is off, the tab is incognito, or the web view has left the screen. It re-checks that the web view is still on screen after every `await`.
4. **Extract.** It grabs the page's HTML, and `PageContentExtractor` (using swift-readability and SwiftSoup) pulls out the article text, title, author, and site name.
5. **Quality check.** `CaptureQuality.evaluate` scores the page on word count, reading time, scroll depth, and whether it has article metadata. It also rejects blocked paths such as `/billing` and `/payment`. The result decides whether the page is saved, and whether a new website entry may be created.
6. **Classify.** `SemanticTopicClassifier` picks a provisional topic by comparing embeddings. The topic row is fetched, or created with a color from `TopicColorPalette`.
7. **Save.** The website row is created or updated, and `KnowledgeStorage.save(...)` writes the page. A website's topic is the majority topic of its pages (`TopicVote.majority`, applied by `recomputeWebsiteTopic`). A `.knowledgeCaptured` notification tells the UI to refresh.
8. **Enrich in the background.** A detached background task runs these in order: page embedding, entities, chunks, an LLM summary, topic refinement by the LLM (`pickTopic` over the classifier's candidates), and, for a new site, a site summary. When it finishes it posts `.knowledgeCaptured` again with `stage: enrichment`. A memory warning cancels these tasks.

## Storage

`KnowledgeStorage` (`Features/Browser/Knowledge/KnowledgeStorage.swift`) is an `actor` that wraps one SQLite file, `knowledge.sqlite`, in Application Support. The main tables:

| Table                            | Holds                                                                         |
| -------------------------------- | ----------------------------------------------------------------------------- |
| `topics`                         | topic name and color                                                          |
| `websites`                       | one row per domain: display name, summary, topic, page and word counts        |
| `pages`                          | extracted page content, summary, reading metrics, topic                       |
| `pages_fts`                      | full-text search index over pages (FTS5, SQLite's full-text search extension) |
| `page_embeddings`, `page_chunks` | vectors for semantic search, per page and per chunk                           |
| `page_entities`                  | extracted named entities                                                      |
| `annotations`                    | user highlights                                                               |

Embeddings come from `EmbeddingService`, which wraps Apple's `NLContextualEmbedding`. Changing `EmbeddingService.embeddingVersion` wipes every stored vector and re-embeds the whole library.

## Ask flow: question → answer

`KnowledgeAIViewModel.send()` (`UI/Knowledge/KnowledgeAIViewModel.swift`):

1. **Correct typos** in the question (`QueryCorrector`).
2. **Date-scoped questions** such as "what did I read last week" are parsed by `DateQueryParser`. They search only pages from that date range.
3. **All other questions** gather candidate pages from three places: semantic search (`searchSemanticScored`), keyword search (`searchPages` over FTS), and the sources behind the previous answer. `rerankByRelevance` then re-scores every candidate on one shared scale, and `relevanceGated` drops anything below the score floor.
4. **Answer.** The surviving pages go to `LocalKnowledgeProvider.answerStreamFromKnowledge`, which streams the reply. The view model then scores the finished answer against its sources (`AnswerValidityScorer`). Every answer lists the pages it drew from.

## LLM

`LocalKnowledgeProvider` (`Knowledge/LocalKnowledgeProvider.swift`) is an `actor` running Llama 3.2 1B Instruct (4-bit) through MLX. It downloads the weights on first use, unloads the model when idle or under memory pressure, and serves summaries, topic picks, intent classification, and streamed answers. All prompt text lives in `KnowledgePrompts`. `PromptBudgeter` trims the context to fit the prompt window.

In the Simulator every entry point returns canned stubs, so none of this is exercised there.
