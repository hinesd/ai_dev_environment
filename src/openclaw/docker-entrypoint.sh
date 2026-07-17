#!/bin/sh
set -e

MODE="${MODE:-local}"

echo "Applying patches..."
for f in /etc/openclaw/patches/*.json5; do
  [ -f "$f" ] && cat "$f" | node dist/index.js config patch --stdin
done

echo "Applying network patch for mode: $MODE..."
cat "/etc/openclaw/patches/network/${MODE}.json5" | node dist/index.js config patch --stdin

exec node openclaw.mjs gateway
