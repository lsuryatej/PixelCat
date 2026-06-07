<p align="center">
  <img src="docs/banner.png" width="800" alt="PixelCat">
</p>

<p align="center">
  <a href="https://github.com/lsuryatej/PixelCat/releases/latest">
    <img src="https://img.shields.io/github/v/release/lsuryatej/PixelCat?style=flat-square&color=e9a96a" alt="latest release">
  </a>
  <img src="https://img.shields.io/badge/macOS-14%2B-555?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/SwiftUI%20%2B%20AppKit-fff5e6?style=flat-square" alt="SwiftUI + AppKit">
  <img src="https://img.shields.io/badge/license-MIT-c8e6c9?style=flat-square" alt="MIT license">
</p>

A tiny pixel-art cat that lives at the bottom of your screen. It breathes, blinks, walks around, purrs when you pet it, and meows when your AI agent finishes a task.

**[⬇ Download v1.0](https://github.com/lsuryatej/PixelCat/releases/latest)** — unzip, right-click → Open the first time (macOS will warn you — it's a personal unsigned app, that's expected).

---

## What it does

| | |
|---|---|
| Idle | breathes, blinks, flicks its tail |
| Walks | wanders at the bottom of your screen |
| Eye-follow | pupils track your cursor |
| Mochi drag | pick it up and fling it — it stretches and wobbles back |
| Mouse hunt | move fast and it chases you |
| Petting | hover over its head → purr + floating hearts |
| Overheat | type too fast → turns red with steam puffs |
| Paper unroll | scroll → it unrolls a little paper scroll |
| Stretch reminders | meows at you every 30 min (configurable) |
| Pomodoro timer | a pixel shelf below the cat; coffee mug in focus mode, poop piles on break |
| Appearance | pick a coat color and pattern from Settings |

## Controls

- **Left-click the menu-bar paw** — show / hide the cat
- **Right-click the menu-bar paw** — Sleep, Wake, Quit
- **Right-click the cat** — open Settings (colors, patterns, timer, your name)

> Some tricks (keyboard kneading, paper unroll, the Claude Desktop watcher) need **Accessibility** permission. Grant it in System Settings → Privacy & Security → Accessibility when the app asks.

## AI agent reactions

The cat reads `~/.pixelcat/state.json`. Write to it from any agent, script, or tool:

```bash
echo '{"status":"thinking"}' > ~/.pixelcat/state.json   # thinking face
echo '{"status":"done"}'     > ~/.pixelcat/state.json   # happy hop + meow
echo '{"status":"idle"}'     > ~/.pixelcat/state.json   # back to normal
```

**Claude Code hook** — add to `~/.claude/settings.json` so the cat reacts while tools run:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "*", "hooks": [
        { "type": "command", "command": "echo '{\"status\":\"thinking\"}' > ~/.pixelcat/state.json" }
      ]}
    ],
    "Stop": [
      { "hooks": [
        { "type": "command", "command": "echo '{\"status\":\"done\"}' > ~/.pixelcat/state.json" }
      ]}
    ]
  }
}
```

There's also an experimental Claude Desktop watcher that infers thinking/done state by watching its window — it needs Accessibility permission and may need re-tuning if Anthropic updates the desktop app UI.

---

<details>
<summary>Build from source</summary>

Requires Xcode 26+. No paid Apple Developer account needed — builds with free local (ad-hoc) signing.

```bash
cd ~/PixelCat
xcodebuild -project PixelCat.xcodeproj -target PixelCat \
  -configuration Debug CONFIGURATION_BUILD_DIR="$PWD/build" build
open ~/PixelCat/build/PixelCat.app
```

Or open `PixelCat.xcodeproj` in Xcode and hit Run.

**Note:** with ad-hoc signing the binary signature can change between rebuilds, which sometimes resets the Accessibility grant. If keyboard/scroll tricks go quiet after a rebuild, toggle PixelCat off and on in the Accessibility list.

</details>

<details>
<summary>Sending it to someone else</summary>

The app isn't signed with a paid Apple Developer ID, so Gatekeeper will warn whoever opens it. They just need to do this once:

1. Unzip → right-click `PixelCat.app` → **Open** → **Open**
2. If macOS still blocks it: `xattr -dr com.apple.quarantine /Applications/PixelCat.app`

AirDrop is friendlier than a download link — files from AirDrop pick up fewer quarantine flags.

</details>

---

## License

[MIT](LICENSE)
