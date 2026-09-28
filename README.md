<p align="center">
  <img src="assets/icon-rounded.png" width="120" />
</p>

<h1 align="center">Lumen</h1>

<p align="center">
  <strong>Browse. Remember. Ask. No cloud required.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS_18+-000?style=flat&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/Swift_6.2-F05138?style=flat&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/Xcode_26.2+-147EFB?style=flat&logo=xcode&logoColor=white" />
  <img src="https://img.shields.io/badge/On--Device_AI-FF9F0A?style=flat" />
  <img src="https://img.shields.io/badge/v1.4.1-E8E4DC?style=flat" />
</p>

<p align="center">
  <a href="#demo">Demo</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#knowledge-system">Knowledge</a> •
  <a href="#privacy">Privacy</a> •
  <a href="#stack">Stack</a> •
  <a href="#building">Building</a>
</p>

---

I kept reading great stuff online and then completely blanking on where I saw it, and so I built a browser that remembers for me.

Lumen reads along as you browse. It grabs the good parts of every page you actually spend time on, summarizing them, and filing them into a knowledge base that lives entirely on your phone. You can ask about any of it later. A local LLM answers from _your_ reading, not the whole internet, and nothing you read or ask leaves the phone.

Runs on iPhone with iOS 18 or later. No account, no server, no "sign in to continue." You browse like normal and it does the rest.

<br/>

## Demo

<p align="center">
  <img src="assets/home.png" width="23%" />
  &nbsp;
  <img src="assets/library-folders.png" width="23%" />
  &nbsp;
  <img src="assets/ask-answered.png" width="23%" />
  &nbsp;
  <img src="assets/privacy-menu.png" width="23%" />
</p>

<br/>

## How It Works

```
  You browse the web
         │
         ▼
┌─────────────────┐      reading signals detect
│   Lumen reads   │ ◀─── when you actually engage
│   along with    │      with a page, not just
│   you           │      open it
└────────┬────────┘
         │
         ▼
┌─────────────────┐      content extracted,
│  Knowledge DB   │ ◀─── embedded, summarized,
│  SQLite + FTS5  │      classified — all on-device
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
 📂 Browse  ✦ Ask
 Topics →   "What did I
 Sites →     read about
 Pages       closures?"
```

<br/>

## Knowledge System

The knowledge system has two tabs:

<table>
<tr>
<td width="50%">

### ✦ &nbsp;AI Chat

Ask like you'd text a friend. Lumen finds the pages that matter, hands them to a local Llama 3.2 1B, and answers from **what you read online** instead of internet surfing.

Every answer lists the pages it drew from, and tapping one opens that page in a new tab.

</td>
<td width="50%">

### 📂 &nbsp;Folders

Everything you read sorts itself into folders:

**Topics** → **Websites** → **Pages**

Sites sort themselves into topics automatically, and each site gets a synthesis of everything you read there. You can move a site to another topic or delete a site or page from its long-press menu.

</td>
</tr>
</table>

```
┌─────────────────────────────────────────┐
│  EVERYTHING RUNS LOCALLY                │
│                                         │
│  LLM inference    ████████  MLX Swift   │
│  Embeddings       ████████  NLEmbedding │
│  Full-text search ████████  FTS5        │
│  Vector search    ████████  Cosine sim  │
│  Storage          ████████  SQLite      │
│                                         │
│  Nothing you read leaves the device.    │
└─────────────────────────────────────────┘
```

<br/>

## Privacy

There's no server that we send anything to. That's kind of the whole point :)

| Layer          | Protection                                                                  |
| -------------- | --------------------------------------------------------------------------- |
| **Network**    | Pages upgraded to HTTPS, and HTTP resources on a page loaded over HTTPS     |
| **Tracking**   | Trackers on the Disconnect list blocked, on by default, per site or global  |
| **Cookies**    | Third-party cookies blocked whenever tracker blocking is on                 |
| **Data**       | Knowledge stays in a local SQLite file, excluded from device backups        |
| **AI**         | LLM runs on-device via MLX                                                  |

Lumen does talk to the network in three places, and none of them carry your library:

- **Model download.** The first time it's needed, Lumen fetches the model weights from Hugging Face, once.
- **Search suggestions.** As you type, your chosen search engine sees the text. Turn it off under **Settings → Search Suggestions**; incognito tabs never ask.
- **Site icons.** Each icon comes from the site itself, never a third party.

<br/>

## Stack

```
Swift 6.2 · SwiftUI / iOS 18+ · Xcode 26.2+
│
├── 🧠  MLX Swift ──────── on-device Llama 3.2 1B inference
├── 🌐  WKWebView ──────── hardened browser engine
├── 💾  SQLite + FTS5 ──── full-text search & content tables
├── 🔢  NLEmbedding ────── Apple's sentence-level embeddings
├── 🛡️  WKContentRuleList ─ tracker & third-party cookie blocking
├── 📰  swift-readability, SwiftSoup ── article extraction
│
└── Swift packages: mlx-swift, mlx-swift-lm, swift-readability, SwiftSoup
```

<br/>

## Building

### Requirements

- macOS with **Xcode 26.2** or newer
- **iOS 18** or newer iPhone or simulator (Apple Silicon Mac required for the simulator)
- Apple Developer account for code signing
- Network access on first launch (the LLM weights are pulled from Hugging Face)

### Steps

```bash
# clone
git clone https://github.com/Lux-Softworks/Lumen.git
cd Lumen

# open in Xcode
open Lumen.xcodeproj
```

1. To run on your own iPhone, sign with your own Apple team. Copy `Configuration/Signing.local.example.xcconfig` to `Configuration/Signing.local.xcconfig` (git ignores it), then set `DEVELOPMENT_TEAM` to your team ID and `LUMEN_BUNDLE_ID_PREFIX` to something unique to you (e.g. `com.yourname`). All three targets pick it up; there are no project settings to edit.
2. Swift Package Manager will resolve the MLX Swift dependencies automatically on first open.
3. Pick a destination (iOS 18+ iPhone or iOS 18+ simulator on Apple Silicon) and hit **⌘R**.

To run the tests from the terminal, use `scripts/test.sh` (see [Contributing → Test](https://www.lumen-browser.app/docs/contributing#test)).

### First launch

The first time Lumen needs the model (when it files your first page, or when you open the knowledge panel), it downloads the `mlx-community/Llama-3.2-1B-Instruct-4bit` weights (~700 MB) from Hugging Face and caches them on-device. After that, everything runs fully offline.

### Deployment

Lumen is a client-only iOS app. "Deploying" means getting the build onto a device:

- **Run on your own device** — connect an iPhone (iOS 18+), select it as the destination, and **⌘R**. Trust the developer profile under **Settings → General → VPN & Device Management** on first run.
- **Share via TestFlight** — in Xcode, **Product → Archive**, then distribute the archive to App Store Connect and invite testers through TestFlight.
- **App Store release** — submit the same archive for App Store review. Distribution through Apple's App Store is explicitly permitted by the license exception below.

<br/>

## License

[AGPL-3.0 with an Apple App Store distribution exception](LICENSE) — if you build on this, share it back.

The exception (added as additional permission under GNU AGPL version 3 section 7) authorizes distribution of this software through Apple's App Store under Apple's terms. All other distribution remains governed by the AGPL-3.0.

## Contributing

Want to help? Awesome — here's the process:

1. **Fork** the repository and create a feature branch off `main` (`git checkout -b your-feature`).
2. **Match the conventions** — this codebase contains self-explanatory code (meaning no comments), and `swiftlint --strict` must pass, the same check CI runs. Build with ⌘R in Xcode; run tests with ⌘U or `scripts/test.sh`. [AGENTS.md](AGENTS.md) and the [docs](https://www.lumen-browser.app/docs) map the codebase.
3. **Test on a physical device** for anything AI-related. The on-device LLM does not run in the Simulator.
4. **Open a pull request** against `main` with a clear description of what changed and why.

Thanks for helping improve our community and software!

## AI Declaration

Lumen was built entirely by me as a solo developer. I used AI tools (primarily Claude) throughout development for brainstorming architecture decisions, debugging, generating boilerplate, and writing code. All design decisions, system architecture, and feature direction are my own. I reviewed and understand every line of code in the project.
