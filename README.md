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
  <img src="https://img.shields.io/badge/AGPL--3.0-blue?style=flat" />
  <img src="https://img.shields.io/badge/v1.2.2-E8E4DC?style=flat" />
</p>

<p align="center">
  <a href="#how-it-works">How It Works</a> •
  <a href="#knowledge-system">Knowledge</a> •
  <a href="#privacy">Privacy</a> •
  <a href="#stack">Stack</a> •
  <a href="#building">Building</a>
</p>

---

An iOS browser built from scratch in SwiftUI. Lumen reads along with you — extracting, summarizing, and organizing every page you actually engage with into a personal knowledge base. Then you can ask questions about it, answered by a local LLM that never leaves your device.

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

All you have to do is browse. Lumen does the rest.

<br/>

## Knowledge System

The knowledge panel has two modes:

<table>
<tr>
<td width="50%">

### ✦ &nbsp;AI Chat

Ask questions in natural language. Lumen pulls relevant pages via semantic search, feeds them to a local Llama 3.2 1B model, and returns answers grounded in **your actual reading history** and not the whole internet.

Every answer cites its sources, so you can trace exactly where each response came from.

</td>
<td width="50%">

### 📂 &nbsp;Folders

Your reading auto-organizes into a hierarchy:

**Topics** → **Websites** → **Pages**

Each level gets its own LLM-generated summary. Topics are classified automatically. Websites get synthesis summaries built from your reading patterns across their pages.

</td>
</tr>
</table>

```
┌─────────────────────────────────────────┐
│  EVERYTHING RUNS ON-DEVICE              │
│                                         │
│  LLM inference    ████████  MLX Swift   │
│  Embeddings       ████████  NLEmbedding │
│  Full-text search ████████  FTS5        │
│  Vector search    ████████  Cosine sim  │
│  Storage          ████████  SQLite      │
│                                         │
│  No networking.                         │
└─────────────────────────────────────────┘
```

<br/>

## Privacy

Lumen has no server, meaning there's nothing to send.

| Layer              | Protection                                                            |
| ------------------ | --------------------------------------------------------------------- |
| **Network**        | HTTPS-only upgrades, mixed-content blocking                           |
| **Cookies**        | Third-party cookies blocked by default                                |
| **Tracking**       | Built-in tracker database with threat classification                  |
| **Fingerprinting** | Fingerprint resistance via content security policies                  |
| **Data**           | All knowledge stays in local SQLite — no sync, no cloud, no API calls |
| **AI**             | LLM runs on-device via MLX — prompts never leave your phone           |

<br/>

## Stack

```
Swift 6.2 · SwiftUI · iOS 18+ · Xcode 26.2+
│
├── 🧠  MLX Swift ──────── on-device Llama 3.2 1B inference
├── 🌐  WKWebView ──────── hardened browser engine
├── 💾  SQLite + FTS5 ──── full-text search & content tables
├── 🔢  NLEmbedding ────── Apple's sentence-level embeddings
├── 🛡️  ThreatDetector ─── tracker & fingerprint classification
│
└── Zero external dependencies beyond Apple + MLX
```

<br/>

## Building

### Requirements

- macOS with **Xcode 26.2** or newer
- **iOS 18** or newer device or simulator (Apple Silicon Mac required for the simulator — MLX needs an ARM GPU)
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

In Xcode:

1. Select the **Lumen** target → **Signing & Capabilities**.
2. Replace the bundled team (`XF6K537DNY`) with your own, and change the bundle identifier from `com.luxsoftworks.Lumen` to something unique to you (e.g. `com.yourname.Lumen`). Do the same for the `LumenTests` and `LumenUITests` targets.
3. Swift Package Manager will resolve the MLX Swift dependencies automatically on first open — wait for it to finish.
4. Pick a destination (iOS 18+ device or iOS 18+ simulator on Apple Silicon) and hit **⌘R**.

### First launch

The first time you open the knowledge panel, Lumen downloads the `mlx-community/Llama-3.2-1B-Instruct-4bit` weights (~700 MB) from Hugging Face and caches them on-device. After that, everything runs fully offline.

<br/>

## License and Contributing

[AGPL-3.0](LICENSE) — if you build on this, share it back.

If you would like to contribute to the browser, please make a branch and follow all rulesets + conventions. Thanks for helping improve our community and software!
