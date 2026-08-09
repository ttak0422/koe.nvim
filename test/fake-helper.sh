#!/bin/sh
# Fake helper for the smoke test; just replays the NDJSON contract.
printf '{"e":"ready"}\n'
printf '{"e":"volatile","text":"こんに"}\n'
printf '{"e":"volatile","text":"こんにちは、せ"}\n'
printf '{"e":"final","text":"こんにちは、世界。"}\n'
printf '{"e":"volatile","text":"次の行"}\n'
printf '{"e":"final","text":"次の行です。"}\n'

# Keep listening until Neovim closes stdin, matching the real helper.
while IFS= read -r _; do :; done
