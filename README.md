# koe.nvim

macOS のオンデバイス音声認識(SpeechAnalyzer / SpeechTranscriber)で Neovim に日本語をディクテーションするプラグイン。

track と同じ「CLI が本体、エディタは薄い」構成:

- `cli/` — Swift ヘルパー。マイク入力をストリーミング認識し NDJSON を stdout に流す
- `lua/koe/` — Neovim プラグイン。jobstart でヘルパーを起動し、volatile 結果を inline ghost text、final 結果を `nvim_paste` で挿入

## NDJSON contract

```
{"e":"ready"}
{"e":"volatile","text":"..."}
{"e":"final","text":"..."}
{"e":"error","message":"..."}
```

停止はヘルパーの stdin を閉じる(finalize して exit 0)。

## Requirements

- macOS 26+(Apple Silicon)。認識は完全オンデバイス・無制限
- Command Line Tools のみでビルド可(Xcode 不要): `make build`
- マイクの TCC 許可は**親のターミナルアプリに帰属**する(CLI 側では制御不可)

## Usage

```lua
require("koe").setup({ locale = "ja-JP" })
vim.keymap.set({ "n", "i" }, "<M-v>", require("koe").toggle, { desc = "koe: dictation toggle" })
```

自動起動はしない。明示キーマップで開始/停止する。`:checkhealth koe` で環境診断。

## Status

MVP 開発中。調査ノート: track `neovim音声入力プラグイン調査`

やらないこと: cmp/blink 補完ソース、音声コマンド、マルチバックエンド抽象化。
macOS 15 対応は [hear](https://github.com/sveinbjornt/hear) ラッパで可能だが未実装。
