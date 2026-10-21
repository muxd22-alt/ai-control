#!/usr/bin/env bash
# model-download.sh - fetch the GGUF model into the stack, resumably.
#
# The file is written as .part and promoted only when its size matches the
# size the server reports, so a half-downloaded model is never handed to the
# engine.
set -uo pipefail

AI_ROOT="${AI_ROOT:-$HOME/ai}"
MODEL_DIR="$AI_ROOT/models"
LOG="$AI_ROOT/logs/model-download.log"
AI_MODEL_FILE=""
AI_REPO="unsloth/gemma-4-26B-A4B-it-GGUF"
AI_MODEL_NAME="gemma-4-26B-A4B-it-UD-Q4_K_M.gguf"
if [ -f "$AI_ROOT/etc/ai.env" ]; then
  # shellcheck disable=SC1090
  . "$AI_ROOT/etc/ai.env"
fi

mkdir -p "$MODEL_DIR" "$AI_ROOT/logs"
TARGET="$AI_MODEL_FILE"
[ -n "$TARGET" ] || TARGET="$MODEL_DIR/$AI_MODEL_NAME"
PART="$TARGET.part"
URL="https://huggingface.co/$AI_REPO/resolve/main/$AI_MODEL_NAME"

# One downloader at a time: two curls writing the same .part file would
# corrupt it.
exec 9>"$AI_ROOT/run/model-download.lock" 2>/dev/null || true
if command -v flock >/dev/null 2>&1; then
  if ! flock -n 9; then
    echo "another download is already running - nothing to do"
    exit 0
  fi
fi

log() { echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }

remote_size() {
  curl -sIL "$URL" | awk 'tolower($1)=="content-length:"{v=$2} END{gsub(/\r/,"",v); print v}'
}

log "target: $TARGET"
remote="$(remote_size)"
log "remote size: ${remote:-unknown}"

if [ -f "$TARGET" ] && [ -n "$remote" ] && [ "$(stat -c%s "$TARGET")" = "$remote" ]; then
  log "already complete"
  exit 0
fi

log "downloading (resumable)"
curl -L -C - --retry 30 --retry-delay 5 --retry-all-errors \
     --speed-time 180 --speed-limit 1024 \
     -o "$PART" "$URL" >>"$LOG" 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  log "curl failed rc=$rc - the partial file is kept, run it again to resume"
  exit $rc
fi

local_size="$(stat -c%s "$PART")"
log "downloaded $local_size bytes (remote ${remote:-unknown})"
if [ -n "$remote" ] && [ "$local_size" != "$remote" ]; then
  log "size mismatch - not promoting the file"
  exit 2
fi

mv -f "$PART" "$TARGET"
log "complete: $TARGET"
