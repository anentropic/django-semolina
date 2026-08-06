#!/bin/bash
#
# SessionStart hook for Claude Code on the web.
#
# Brings a fresh remote container up to the state DEVELOP.md assumes:
# a current uv, a final (non-rc) Python 3.14, synced dev dependencies,
# and prek for the quality gates.
#
# Safe to re-run: every step is a no-op once satisfied.
set -euo pipefail

# Local machines are already set up by their owner — this is web-session only.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BIN_DIR="$HOME/.local/bin"
export PATH="$BIN_DIR:$PATH"

cd "$PROJECT_DIR"

# --- uv -------------------------------------------------------------------
# The container image can ship a uv whose bundled python-build-standalone
# manifest predates Python 3.14's final release, in which case `uv python
# install 3.14` silently lands on 3.14.0rc2 — where pydantic (via semolina)
# fails to import, because it passes a typing kwarg that was renamed between
# rc2 and 3.14.0. Test for that capability directly rather than pinning a uv
# version: a final build is `3.14.<digits>-`, an rc is `3.14.0rc2-`.
if ! uv python list --all-versions 2>/dev/null | grep -qE 'cpython-3\.14\.[0-9]+-'; then
  echo "==> uv $(uv --version 2>/dev/null | awk '{print $2}') has no final 3.14; upgrading uv"
  # Deliberately not `uv self update`: that hits the GitHub API, which is
  # rate-limited for anonymous callers and fails hard in shared CI ranges.
  # PyPI serves the same binary and is already a trusted path here.
  tmp_env="$(mktemp -d)"
  trap 'rm -rf "$tmp_env"' EXIT
  # Pin to the system interpreter: an unpinned `uv venv` honours
  # .python-version and would have the *old* uv fetch 3.14 — i.e. the rc.
  uv venv --python "$(command -v python3 || echo 3)" "$tmp_env" >/dev/null
  uv pip install --python "$tmp_env/bin/python" --quiet uv
  install -m 0755 "$tmp_env/bin/uv" "$BIN_DIR/uv"
  install -m 0755 "$tmp_env/bin/uvx" "$BIN_DIR/uvx"
  hash -r
  echo "==> uv now $(uv --version | awk '{print $2}')"
fi

# --- Python ---------------------------------------------------------------
# Matches .python-version. requires-python is >=3.11, so the 3.11 floor is a
# CI concern; local dev tracks the version the project pins.
echo "==> Installing Python 3.14"
uv python install 3.14

# --- Dependencies ---------------------------------------------------------
# Plain `sync` rather than `--locked` so a lock refresh mid-session doesn't
# hard-fail startup; CI is where lock drift should be caught.
echo "==> Syncing dev dependencies"
uv sync --dev

# --- Quality gate runner --------------------------------------------------
echo "==> Installing prek"
uv tool install --quiet prek || true
# Wires .git/hooks/pre-commit so commits run the same gates as CI.
prek install >/dev/null 2>&1 || true

# Keep ~/.local/bin (uv, uvx, prek) on PATH for the rest of the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

echo "==> Ready: $(uv run python -V), Django $(uv run python -c 'import django; print(django.get_version())')"
