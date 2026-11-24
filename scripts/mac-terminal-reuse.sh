#!/usr/bin/env bash
# Run a command in the single existing Terminal.app tab (never open a new window).
# Usage: ./scripts/mac-terminal-reuse.sh 'cd "$ROOT" && SKIP_BUILD=1 ./scripts/run-macos.sh …'

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 '<shell command>'" >&2
  exit 2
fi

CMD=$1

osascript - "$CMD" <<'APPLESCRIPT'
on run argv
  set shellCmd to item 1 of argv
  tell application "Terminal"
    activate
    if (count of windows) is 0 then
      do script shellCmd
    else
      -- Reuse selected tab of front window — do NOT call bare `do script`
      do script shellCmd in selected tab of front window
    end if
  end tell
end run
APPLESCRIPT
