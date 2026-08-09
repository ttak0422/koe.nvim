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

## Requirements

- macOS 26 or later on Apple silicon
- Neovim 0.10 or later
- Apple Command Line Tools; Xcode is not required
- Microphone access for the terminal application that runs Neovim

Recognition runs entirely on device and has no server-side duration limit.

## Installation

Add the repository with your preferred Neovim plugin manager, then build the
helper from the plugin directory:

```sh
make build
```

## Setup

```lua
local koe = require("koe")

koe.setup({
  locale = "ja-JP",
  -- listening_text = "● Listening…",
  -- hl = "Comment",
})

vim.keymap.set({ "n", "i" }, "<M-v>", koe.toggle, {
  desc = "Toggle koe dictation",
})
```

Dictation never starts automatically. Invoke the mapping once to start and
again to stop. Run `:checkhealth koe` to verify the local environment.

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
