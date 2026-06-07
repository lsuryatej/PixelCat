<p align="center">
  <img src="docs/banner.png" width="640" alt="PixelCat">
</p>

<p align="center">
  <a href="https://github.com/lsuryatej/PixelCat/releases/latest">
    <img src="https://img.shields.io/github/v/release/lsuryatej/PixelCat?style=flat-square&color=e9a96a" alt="latest release">
  </a>
  <img src="https://img.shields.io/badge/macOS-14%2B-555?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/SwiftUI%20%2B%20AppKit-fff5e6?style=flat-square" alt="SwiftUI + AppKit">
</p>

A tiny pixel-art cat that lives at the bottom of your screen. Menu-bar only
(no Dock icon), floating transparent window, always on top. Built with
SwiftUI + AppKit, drawn procedurally (no image assets).

**[⬇︎ Download the latest release](https://github.com/lsuryatej/PixelCat/releases/latest)** — unzip, drag to Applications, then right-click → Open the first time.

## Build & run

Requires Xcode 26+. No paid Apple Developer account needed — it builds with
free local (ad-hoc) signing.

```bash
cd ~/PixelCat
xcodebuild -project PixelCat.xcodeproj -target PixelCat \
  -configuration Debug CONFIGURATION_BUILD_DIR="$PWD/build" build
open ~/PixelCat/build/PixelCat.app
```

Or just open `PixelCat.xcodeproj` in Xcode and hit Run.

## Permissions

Some tricks need **Accessibility** permission (to see global keyboard/scroll
events and to peek at the Claude Desktop window):

- Keyboard kneading + overheat
- Paper unroll on scroll
- The experimental Claude Desktop "thinking/done" watcher

On first launch the app asks for it. Grant it in
**System Settings → Privacy & Security → Accessibility** (toggle PixelCat on).

Everything else — idle, walking, click, eye-follow, mochi drag, petting/purr,
stretch reminders, the file-based agent bridge, pinned notes — works **without**
any permission.

> **Rebuild note:** with local ad-hoc signing, the binary signature can change
> between builds, which sometimes makes macOS forget the Accessibility grant.
> If the keyboard/scroll tricks go quiet after a rebuild, toggle PixelCat off
> and on again in that Accessibility list.

## Menu (right-click the paw in the menu bar)

- **Hide / Show** — also the left-click action on the menu-bar paw
- **Sleep / Wake** — curl up 💤 / resume
- **Stretch Now** — trigger a stretch immediately
- **Set Name…** — the cat calls you by name in reminders and agent "done"
- **Pin Note… / Edit Note… / Clear Note** — a note bubble above its head
- **Stretch Interval…** — minutes between stretch reminders (default 30)
- **Quit**

## What it does

Idle (breathe/blink/tail), random walking, click → happy hop, **eye-follow**,
**mochi drag** (lift to stretch; shake to wobble), **mouse hunt** (move the
cursor fast and it chases), **petting** (hover its head → purr + hearts),
**keyboard kneading** (it kneads while you type), **overheat** (type too fast →
turns red with steam), **stretch reminders**, **paper unroll** on scroll,
**pinned notes**, and **AI-agent awareness**.

## Driving the agent reactions

The cat reads `~/.pixelcat/state.json`. Write a `status` of `thinking`, `done`,
or `idle` and it reacts (thinking face / happy hop + meow / back to normal).
Anything that can write a file can drive it:

```bash
echo '{"status":"thinking"}' > ~/.pixelcat/state.json   # puts on a thinking face
echo '{"status":"done"}'     > ~/.pixelcat/state.json   # happy hop + meow
echo '{"status":"idle"}'     > ~/.pixelcat/state.json   # back to normal
```

### Claude Code hooks

Add to `~/.claude/settings.json` so the cat thinks while a tool runs and cheers
when Claude stops:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "*", "hooks": [
        { "type": "command", "command": "echo '{\"status\":\"thinking\"}' > ~/.pixelcat/state.json" }
      ] }
    ],
    "Stop": [
      { "hooks": [
        { "type": "command", "command": "echo '{\"status\":\"done\"}' > ~/.pixelcat/state.json" }
      ] }
    ]
  }
}
```

### Claude Desktop (experimental)

There's no official Claude Desktop signal, so PixelCat infers it by watching the
desktop window's Accessibility tree for the "stop generating" control. It needs
the Accessibility permission and is **best-effort** — if Anthropic restyles the
desktop UI it may need re-tuning (see `appearsThinking(in:)` in
`Features/ClaudeDesktopWatcher.swift`).

## Project layout

```
PixelCat/
  PixelCatApp.swift            @main, accessory app
  AppDelegate.swift            panel + status item + monitors + menu
  Window/CatPanel.swift        borderless floating NSPanel
  State/CatState.swift         @Observable state
  State/Settings.swift         UserDefaults persistence
  View/CatView.swift           SwiftUI Canvas + note bubble
  View/CatSprite.swift         procedural pixel-art renderer
  View/CatHostingView.swift    AppKit mouse handling (drag/click/hover)
  Input/AccessibilityPermission.swift
  Input/GlobalEventMonitor.swift   global keyDown + scrollWheel
  Features/CatController.swift  the brain: moods, physics, behaviors
  Features/SoundSynth.swift     procedural meow + purr
  Features/AgentBridge.swift    ~/.pixelcat/state.json watcher
  Features/ClaudeDesktopWatcher.swift  experimental AX watcher
```

## Pomodoro timer

A pixel timer shelf that sits **below the cat** (the cat stands on it). Toggle it
from the menu bar: **Pomodoro Timer ▸ Show Timer**, then **Start**. It runs
focus → break loops; the bar stretches down as time runs out and the cat meows +
shows a name-aware bubble ("focus, <name>!" / "break time, <name>!") at each
switch. Set **Focus Length** / **Break Length** in the same submenu (defaults
25m / 5m). The panel grows taller while the timer is shown.

## Sharing / installing

The app is **not signed with a paid Apple Developer ID** (it's ad-hoc signed for
local use), so macOS Gatekeeper will warn whoever opens it. That's expected for a
personal app — they just need to allow it once.

**Build a shareable zip:**

```bash
cd ~/PixelCat
xcodebuild -project PixelCat.xcodeproj -target PixelCat -configuration Release \
  CONFIGURATION_BUILD_DIR="$PWD/release" build
cd release && ditto -c -k --sequesterRsrc --keepParent PixelCat.app ~/Desktop/PixelCat.zip
```

**For whoever receives it:** unzip, drag `PixelCat.app` to `/Applications`, then
the first time **right-click the app → Open → Open** (a plain double-click is
blocked for unsigned apps). If macOS still refuses ("damaged / can't be
checked"), clear the download quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/PixelCat.app
```

Then grant Accessibility (System Settings → Privacy & Security → Accessibility)
if they want the keyboard/scroll tricks.

> The only way to remove the Gatekeeper prompt entirely is a paid Apple Developer
> account (to sign + notarize). For sharing with friends, the right-click-Open
> step is the normal workaround.

## Roadmap (next)

Appearance customization — pick a cat color + coat pattern from the menu. (Done.)
