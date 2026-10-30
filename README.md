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

`koe.nvim` records through its Swift helper and inserts results with
`nvim_paste`; it does not use macOS system Dictation. The system Dictation
issue [neovide#3541](https://github.com/neovide/neovide/issues/3541) is separate.

Official macOS releases through **0.16.2** lack the
`com.apple.security.device.audio-input` signing entitlement, which prevents
microphone access in those hardened runtime builds. Neovide fixed its release
and nightly signing pipelines in
[neovide#3585](https://github.com/neovide/neovide/pull/3585), merged on
2026-10-09. As of 2026-10-30, the latest stable release is still
[0.16.2](https://github.com/neovide/neovide/releases/tag/0.16.2); the current
[nightly](https://github.com/neovide/neovide/releases/tag/nightly) source
includes the fix. A nightly or custom version string alone does not prove
that a particular app was signed with the entitlement.

For a hardened runtime build, verify the installed binary's entitlements
(adjust the path to match your installation):

```sh
codesign -d --entitlements - /Applications/Neovide.app/Contents/MacOS/neovide
```

Look for `com.apple.security.device.audio-input` set to `true`. A correctly
signed build still needs microphone permission in macOS System Settings →
Privacy & Security → Microphone. `:checkhealth koe` warns about affected stable
versions and provides signing guidance for other builds; it does not test or
request microphone access.

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
