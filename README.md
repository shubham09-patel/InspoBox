![Uploading Screenshot 2026-10-07 at 11.28.50 PM.png…]()
![Uploading Screenshot 2026-10-07 at 11.28.44 PM.png…]()
<p align="center">
  <img src="docs/icon.png" width="120" alt="InspoBox icon" />
</p>

<h1 align="center">InspoBox</h1>

<p align="center">
  A glassy macOS menu bar + desktop app to collect animation references and track your reel production — all stored locally.
</p>

<p align="center">
  <img src="docs/screenshot-board.png" width="780" alt="Inspiration board" />
</p>

## Why I built this

I make animation, and my references were scattered everywhere: images saved from Pinterest, reels and stories liked on Instagram, random folders on my Desktop. Finding "that one sad pose" took forever.

InspoBox puts everything in one place — save a reference in seconds, filter it later by genre or tag, and keep track of which phase each reel is in.

I built it for myself. If it helps you, feel free to **clone it, tweak it and make it your own**.

## Features

**Inspiration board**
- Pinterest-style masonry grid with search and genre filters
- Save **images, videos and links** by paste (⌘ clipboard), drag & drop, or the Paste button
- Paste a Pinterest pin link → the original image is fetched automatically
- Instagram / YouTube / TikTok links are saved as link cards (opens in your browser)
- Each reference asks for: **name · genre · tags** (Comedy, Sad, Funny, Random, Action, Romance, Horror, Fantasy… or your own)
- Delete = **moves the file to the Bin**
- Menu bar popup for quick saves + a full desktop window for drag & drop

**Animation project tracker**
- Phases: Script → Asset Collection → Rough Sketching → Sketching → Colouring → Detailing → Uploaded
- Phase history, notes and upload date
- Link references to a project and view only that reel's refs on the board
- Deadlines with local notifications (1 day before + at the deadline)

**Local-first**
- Everything lives on your Mac in `~/Library/Application Support/InspoBox/` (`library.json` + `Images/`). No account, no cloud.

## Tech

SwiftUI · AppKit · Combine · AVFoundation (video thumbnails) · UserNotifications · `MenuBarExtra` · Open Graph scraping with `URLSession`

## Getting started

Requirements: macOS 14+ and Xcode 15+.

```bash
git clone https://github.com/shubham09-patel/InspoBox.git
cd InspoBox
open InspoBox.xcodeproj
```

Press **⌘R** in Xcode. To keep it, copy `InspoBox.app` from the build folder into `/Applications`.

> If macOS blocks the app: right-click → **Open**.
> If you enable App Sandbox, turn on *Outgoing Connections (Client)* and *User Selected File → Read Only*.

## How it works

| Piece | File |
|---|---|
| App entry (window + menu bar) | `InspoBoxApp.swift` |
| Data models (items, projects, phases) | `Models.swift` |
| Storage, paste/drop ingest, video + web fetching | `Store.swift`, `StoreRefs.swift` |
| Board, masonry grid, save form | `ContentView.swift` |
| Project tracker, reference picker | `ProjectsView.swift` |
| Deadline reminders | `Notifier.swift` |

Flow: **paste / drop → `Store.ingest` → `Pending` → save form → `Store.commit` → `library.json` + file copy**.

## Known limits

- Instagram/YouTube/TikTok videos can't be downloaded — those are saved as links.
- `.webm` / `.mkv` videos are saved without a thumbnail.
- Videos are copied into the app folder, so they use disk space.

## Roadmap

- [ ] Edit name / genre / tags after saving
- [ ] Global keyboard shortcut to open InspoBox from anywhere
- [ ] Colour palette extraction from images
- [ ] Export / backup
- [ ] Unit tests for `Store`

## Built with AI assistance

I built this with help from an AI assistant (Claude) and learned the architecture along the way.

## License

MIT — see [LICENSE](LICENSE).
