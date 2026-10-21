#!/usr/bin/env bash
# keepalive-download.sh - keep the model download alive until the model is there.
#
# Android kills Termux when it wants the memory back, and a 17 GB download
# that dies at 90% is a bad afternoon. This loop restarts the download
# whenever it stops, and the download itself resumes where it stopped.
set -uo pipefail

AI_ROOT="${AI_ROOT:-$HOME/ai}"
AI_MODEL_FILE=""
AI_REPO="unsloth/gemma-4-26B-A4B-it-GGUF"
AI_MODEL_NAME="gemma-4-26B-A4B-it-UD-Q4_K_M.gguf"
if [ -f "$AI_ROOT/etc/ai.env" ]; then
  # shellcheck disable=SC1090
  . "$AI_ROOT/etc/ai.env"
fi
MODEL="${AI_MODEL_FILE:-$AI_ROOT/models/$AI_MODEL_NAME}"
LOG="$AI_ROOT/logs/model-download.log"

mkdir -p "$AI_ROOT/logs" "$AI_ROOT/run"

while [ ! -f "$MODEL" ]; do
  bash "$AI_ROOT/projects/ai-control/model-download.sh"
  if [ -f "$MODEL" ]; then
    break
  fi
  sleep 20
done

echo "[$(date -u +%FT%TZ)] model complete: $MODEL" >>"$LOG"
