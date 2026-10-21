#!/usr/bin/env bash
# install.sh - one-shot bootstrap of the ai stack on this phone.
#
# Creates the one root folder, writes the default config, links `ai` onto the
# PATH and pulls every project from GitHub. Safe to run again.
set -uo pipefail

AI_ROOT="${AI_ROOT:-$HOME/ai}"
AI_PROJECTS="$AI_ROOT/projects"
GITHUB_USER="${GITHUB_USER:-muxd22-alt}"

say() { printf '  %s\n' "$*"; }

echo "==> root: $AI_ROOT"
mkdir -p "$AI_ROOT"/{bin,etc,models,build,logs,run,state,projects}
mkdir -p "$HOME/bin"

echo "==> config"
if [ ! -f "$AI_ROOT/etc/ai.env" ]; then
  cat > "$AI_ROOT/etc/ai.env" <<EOF
# ai stack configuration - one KEY=VALUE per line, sourced by the ai command.
AI_MODEL_FILE=$AI_ROOT/models/gemma-4-26B-A4B-it-UD-Q4_K_M.gguf
AI_HOST=0.0.0.0
AI_PORT=8765
AI_API_KEY=local
AI_SERVER_ARGS=--auto
AI_START_TIMEOUT=180
AI_REPO=unsloth/gemma-4-26B-A4B-it-GGUF
AI_MODEL_NAME=gemma-4-26B-A4B-it-UD-Q4_K_M.gguf
# The telegram bridge starts only when a token is set here.
AI_TELEGRAM_TOKEN=
AI_TELEGRAM_USER_ID=
EOF
  say "wrote $AI_ROOT/etc/ai.env"
else
  say "kept the existing $AI_ROOT/etc/ai.env"
fi

echo "==> projects"
for p in ai-control bmoe-termux telegram-agent; do
  d="$AI_PROJECTS/$p"
  if [ -d "$d/.git" ]; then
    say "$p: present, updating"
    ( cd "$d" && git pull --ff-only ) || say "$p: pull failed, leaving as is"
  else
    say "$p: cloning"
    git clone --depth 1 "https://github.com/$GITHUB_USER/$p.git" "$d" || say "$p: clone failed"
  fi
done

echo "==> link"
ln -sf "$AI_PROJECTS/ai-control/ai" "$AI_ROOT/bin/ai"
ln -sf "$AI_PROJECTS/ai-control/ai" "$HOME/bin/ai"
chmod 755 "$AI_PROJECTS/ai-control/ai" "$AI_PROJECTS/ai-control/model-download.sh" 2>/dev/null || true
say "ai -> $AI_PROJECTS/ai-control/ai"

echo "==> python packages for the telegram bridge"
if command -v pip >/dev/null 2>&1; then
  pip install --quiet --upgrade python-telegram-bot openai >/dev/null 2>&1 \
    && say "python-telegram-bot, openai installed" \
    || say "pip install failed - the telegram bridge will not start until it is fixed"
else
  say "pip not found - install python with: pkg install python"
fi

echo
echo "done. next:"
echo "  ai build    build the engine natively on this phone"
echo "  ai model    download the model"
echo "  ai go       start everything"
