#!/bin/sh
# Fake helper for the smoke test; just replays the NDJSON contract.
printf '{"e":"ready"}\n'
printf '{"e":"volatile","text":"こんに"}\n'
printf '{"e":"volatile","text":"こんにちは、せ"}\n'
printf '{"e":"final","text":"こんにちは、世界。"}\n'
