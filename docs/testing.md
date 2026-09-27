# Testing

## Running tests

Agents build and test only through `scripts/test.sh`. It builds into `build/DerivedData` (gitignored), so it never touches Xcode's own build folder.

```bash
scripts/test.sh                 # unit tests (LumenTests), the default
scripts/test.sh ui              # UI tests (LumenUITests)
scripts/test.sh all             # every test target
scripts/test.sh unit -only-testing:LumenTests/TopicVoteTests
```

It ends by printing `result=… passedTests=… failedTests=… skippedTests=…` and the path of the `.xcresult` bundle (Xcode's saved test report). The exit code is `xcodebuild`'s own, so any failure is non-zero.

**Picking an Xcode.** The script uses whichever Xcode `xcode-select` points to. If that Xcode reports "Unable to find a destination", its iOS platform is probably not installed (Xcode › Settings › Components). You can also point the script at a different Xcode for one run:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer scripts/test.sh
```

**Picking a simulator.** The default is iPhone 17 Pro on iOS 26.2. Override it with `LUMEN_TEST_DESTINATION`, for example `'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'`.

Humans can still run tests with ⌘U in Xcode.

## Targets

| Target         | Framework                                                                           | Covers                                                                                                                          |
| -------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `LumenTests`   | Swift Testing (`import Testing`, `@Test`, `#expect`), with `@testable import Lumen` | pure logic: vector math, retrieval gates and scoring, topic votes, URL and HTTPS rules, tracker lists, prompt budgeting, stores |
| `LumenUITests` | XCTest                                                                              | app launch, search flow, settings flow                                                                                          |

## What the Simulator cannot test

The on-device LLM is stubbed out in the Simulator (`#if targetEnvironment(simulator)` in `LocalKnowledgeProvider`). Real summaries, topic picks, intent classification, and streamed answers only run on a physical device. For AI changes:

- Unit-test the logic around the model: prompt building, answer parsing, relevance gates, and scoring. These are plain functions.
- State plainly that the model's own behavior still needs a device check.

## Writing a test

- New unit tests use Swift Testing, to match the existing 24 files.
- Name the test after the behavior, so a failure explains itself (`identicalVectorsYieldOne`).
- Before trusting a new test, watch it fail: break the code, run just that test with `-only-testing:`, confirm it fails for the right reason, then restore the code.
- `KnowledgeStorage` cannot yet be tested directly. It is a singleton with a private `init()` and a fixed file path (`knowledge.sqlite` in Application Support). Existing tests work around this by running its SQL against an in-memory SQLite database (`RootSlashMigrationTests`), or by testing the pure functions it calls (`TopicVote`, `VectorMath`). Giving it an initializer that takes a database path would open up the storage layer to tests.
