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
    git -C "$d" config core.fileMode false
    ( cd "$d" && git pull --ff-only ) || say "$p: pull failed, leaving as is"
  else
    say "$p: cloning"
    tmp="$d.tmp"
    rm -rf "$tmp"
    if git clone --depth 1 "https://github.com/$GITHUB_USER/$p.git" "$tmp"; then
      if [ -d "$d" ]; then
        # The folder is not empty (an upstream clone lives there): keep what is
        # already there and add the project files on top of it.
        cp -a "$tmp/.git" "$d/.git"
        ( cd "$tmp" && git archive HEAD ) | tar -x -C "$d"
        rm -rf "$tmp"
      else
        mv "$tmp" "$d"
      fi
      git -C "$d" config core.fileMode false
    else
      say "$p: clone failed"
      rm -rf "$tmp"
    fi
  fi
done

echo "==> link"
ln -sf "$AI_PROJECTS/ai-control/ai" "$AI_ROOT/bin/ai"
ln -sf "$AI_PROJECTS/ai-control/ai" "$HOME/bin/ai"
# $PREFIX/bin is on every PATH Termux builds, so the command works in any
# shell, however that shell was started.
ln -sf "$AI_PROJECTS/ai-control/ai" "$PREFIX/bin/ai"
chmod 755 "$AI_PROJECTS/ai-control/ai" "$AI_PROJECTS/ai-control/model-download.sh" \
         "$AI_PROJECTS/ai-control/keepalive-download.sh" 2>/dev/null || true
say "ai -> $AI_PROJECTS/ai-control/ai"
# and $HOME/bin for shells that only know about that one
if ! grep -q 'HOME/bin' "$HOME/.bashrc" 2>/dev/null; then
  printf '\nexport PATH="$HOME/bin:$PATH"\n' >>"$HOME/.bashrc"
  say "added \$HOME/bin to the PATH in ~/.bashrc"
fi

echo "==> python packages for the telegram bridge"
if command -v pip >/dev/null 2>&1; then
  # python-telegram-bot only: the openai package needs a Rust toolchain to
  # build on Termux, and the bridge talks to the local server with the
  # standard library instead.
  if python -c 'import telegram' >/dev/null 2>&1; then
    say "python-telegram-bot present"
  elif pip install --quiet python-telegram-bot >/dev/null 2>&1; then
    say "python-telegram-bot installed"
  else
    say "pip install failed - the telegram bridge will not start until it is fixed"
  fi
else
  say "pip not found - install python with: pkg install python"
fi

echo
echo "done. next:"
echo "  ai build    build the engine natively on this phone"
echo "  ai model    download the model"
echo "  ai go       start everything"
