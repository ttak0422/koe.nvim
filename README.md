# koe.nvim

`koe.nvim` brings Japanese dictation to Neovim using the on-device
SpeechAnalyzer and SpeechTranscriber APIs in macOS.

The plugin has two small components:

- `cli/` contains a Swift helper that streams microphone input and writes
  recognition events to standard output as NDJSON.
- `lua/koe/` starts the helper as a Neovim job, previews volatile results with
  an inline extmark, and inserts final results into the buffer.

Each final recognition result is inserted on its own line. While the helper is
listening, an inline `● Listening…` extmark remains visible at the cursor; the
current volatile result is shown beside it.

Because results are written at the cursor, dictation only runs in insert or
terminal mode. Starting it from normal mode enters insert mode first, and
leaving insert or terminal mode stops it.

## Requirements

- macOS 26 or later on Apple silicon
- Neovim 0.10 or later
- Microphone access for the application that runs Neovim (terminal or GUI)

Recognition runs entirely on device and has no server-side duration limit.

### Neovide on macOS

Use an official [nightly](https://github.com/neovide/neovide/releases/tag/nightly)
that includes [neovide#3585](https://github.com/neovide/neovide/pull/3585)
(merged 2026-10-09), or a later stable release containing that fix.
As of 2026-10-30, the latest stable release, **0.16.2**, lacks the
`com.apple.security.device.audio-input` signing entitlement required for this
microphone input path. Microphone permission in macOS System Settings →
Privacy & Security → Microphone is still required.

## Installation

Install the repository with your preferred Neovim plugin manager. The
macOS 26 / Apple silicon helper is bundled, so no separate build step is
required.

> [!NOTE]
> The prebuilt helper is committed as a temporary measure until nixpkgs
> provides a Swift 6 toolchain compatible with the macOS 26 Speech SDK.

## Setup

```lua
local koe = require("koe")

koe.setup({
  locale = "ja-JP",
  -- listening_text = "● Listening…",
  -- hl = "Comment",
})

vim.keymap.set({ "i", "t" }, "<M-t>", koe.toggle, {
  desc = "Toggle koe dictation",
})
```

Dictation never starts automatically. Invoke the mapping once to start and
again to stop, or leave insert mode. The utterance in progress is still
finalized and inserted after the stop. Run `:checkhealth koe` to verify the
local environment.

## Helper protocol

The helper writes one JSON object per line:

```json
{"e":"ready"}
{"e":"volatile","text":"..."}
{"e":"final","text":"..."}
{"e":"error","message":"..."}
```

Neovim stops the helper by closing its standard input. The helper then stops
capturing audio, finalizes the current recognition result, and exits normally.
The same cleanup runs when Neovim exits or the helper receives `SIGINT`,
`SIGTERM`, or `SIGHUP`.

## Status

This project is an early MVP. Completion sources for cmp and blink, voice
commands, multiple recognition backends, and macOS 15 support are outside the
current scope.
