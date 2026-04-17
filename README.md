<p align="center">
  <img src="assets/icon-rounded.png" width="120" />
</p>

<h1 align="center">Lumen</h1>

<p align="center">
  <strong>Your browser remembers what you read.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS_17+-000?style=flat&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/Swift_6.2.4-F05138?style=flat&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/On--Device_AI-FF9F0A?style=flat" />
  <img src="https://img.shields.io/badge/AGPL--3.0-blue?style=flat" />
  <img src="https://img.shields.io/badge/v1.3.0-E8E4DC?style=flat" />
</p>

<p align="center">
  <a href="#how-it-works">How It Works</a> •
  <a href="#knowledge-system">Knowledge</a> •
  <a href="#privacy">Privacy</a> •
  <a href="#stack">Stack</a> •
  <a href="#building">Building</a>
</p>

---

An iOS browser built from scratch in SwiftUI. Lumen silently reads what you read — extracting, summarizing, and organizing every page into a personal knowledge base — then lets you **ask questions about it** using a local LLM that never leaves your device.

No cloud. No accounts. No telemetry. Your reading, remembered.

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

You don't clip articles. You don't tag bookmarks. You just browse. Lumen does the rest.

<br/>

## Knowledge System

The knowledge panel has two modes:

<table>
<tr>
<td width="50%">

### ✦ &nbsp;AI Chat

Ask questions in natural language. Lumen retrieves relevant sources via semantic search, feeds them to a local Llama 3.2 1B model, and generates answers **grounded in your actual reading history**.

Sources are cited inline — you can see exactly which pages informed each answer.

</td>
<td width="50%">

### 📂 &nbsp;Folders

Your reading auto-organizes into a hierarchy:

**Topics** → **Websites** → **Pages**

Each level has LLM-generated summaries. Topics are classified automatically. Websites get synthesis summaries that describe your reading patterns across their pages.

</td>
</tr>
</table>

### What happens under the hood

| Step | What                  | How                                                                                              |
| :--: | --------------------- | ------------------------------------------------------------------------------------------------ |
|  📡  | **Detect engagement** | JavaScript reading signals track scroll depth, dwell time, and interaction — not just page loads |
|  📄  | **Extract content**   | HTML → clean text via `PageContentExtractor`, stripping nav, ads, boilerplate                    |
|  🧠  | **Summarize**         | Llama 3.2 1B generates one-sentence summaries via few-shot prompting                             |
|  🏷️  | **Classify**          | Same model assigns a topic label (Finance, Technology, AI, etc.)                                 |
|  🔢  | **Embed**             | Apple `NLEmbedding` generates sentence vectors for semantic similarity                           |
|  💾  | **Store**             | SQLite with FTS5 content tables for full-text search, embeddings for vector search               |

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
│  Network calls: zero.                   │
└─────────────────────────────────────────┘
```

<br/>

## Privacy

Lumen isn't private as a feature. It's private as architecture.

| Layer              | Protection                                                            |
| ------------------ | --------------------------------------------------------------------- |
| **Network**        | HTTPS-only upgrades, mixed-content blocking                           |
| **Cookies**        | Third-party cookies blocked by default                                |
| **Tracking**       | Built-in tracker database with threat classification                  |
| **Fingerprinting** | Fingerprint resistance via content security policies                  |
| **Data**           | All knowledge stays in local SQLite — no sync, no cloud, no API calls |
| **AI**             | LLM runs on-device via MLX — prompts never leave your phone           |

There is no server. There is no analytics endpoint. There is nothing to trust because there is nothing to send.

<br/>

## Stack

```
Swift 5.9 · SwiftUI · iOS 17+
│
├── 🧠  MLX Swift ──────── on-device Llama 3.2 1B inference
├── 🌐  WKWebView ──────── hardened browser engine
├── 💾  SQLite + FTS5 ──── full-text search & content tables
├── 🔢  NLEmbedding ────── Apple's sentence-level embeddings
├── 🛡️  ThreatDetector ─── tracker & fingerprint classification
├── 🎨  AppTheme ────────── warm dark/light with amber accent
│
└── Zero external dependencies beyond Apple + MLX
```

<br/>

## Building

```bash
# clone
git clone https://github.com/user/Lumen.git
cd Lumen

# open in Xcode 15+
open Lumen.xcodeproj

# run on physical device (⌘R)
# LLM requires Apple Silicon — simulator will gracefully degrade
```

That's it. No `pod install`. No `swift package resolve`. No config files. Open and run.

<br/>

## License

[AGPL-3.0](LICENSE) — free as in freedom, not as in free beer.

<br/>

---

<p align="center">
  <sub>Built on Apple Silicon. No cloud required.</sub>
</p>
