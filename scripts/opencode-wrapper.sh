#!/bin/bash
BUN="${BUN:-$HOME/.bun/bin/bun}"
OPENCODE_DIR="${OPENCODE_DIR:-$HOME/.local/share/opencode}"
OPENCODE_VERSION=$("$BUN" -e "console.log(require('${OPENCODE_DIR}/packages/opencode/package.json').version)")
exec "$BUN" run \
  --cwd "${OPENCODE_DIR}/packages/opencode" \
  --define OPENCODE_VERSION:"\"${OPENCODE_VERSION}\"" \
  --conditions=browser ./src/index.ts "$@"
