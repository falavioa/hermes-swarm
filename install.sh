#!/usr/bin/env bash
#
# Hermes Swarm — one-command installer.
#
# Checks your machine, installs the swarm the best local way, and gets a
# provider configured — adopting an existing Hermes (~/.hermes) or a LiteLLM/
# OpenAI-compatible proxy if you already have one, otherwise launching
# `hermes setup`. Idempotent: safe to re-run.
#
# Usage:
#   bash install.sh [--no-setup] [--no-browser] [--yes]
#     --no-setup    don't launch `hermes setup` even if no provider is found
#     --no-browser  skip the Chromium download (browser tools won't work)
#     --yes, -y     non-interactive: never prompt (also skips the setup wizard)
#     --help, -h    show this help
#
# Prefer containers? Use Docker instead:  docker compose up --build
#
set -euo pipefail

usage() { sed -n '2,18p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

# ---- pretty output --------------------------------------------------------
if [ -t 1 ]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; X=$'\e[0m'; else B= G= Y= R= X=; fi
step() { printf '\n%s==>%s %s%s%s\n' "$B$G" "$X" "$B" "$1" "$X"; }
info() { printf '    %s\n' "$1"; }
warn() { printf '%s !! %s%s\n' "$Y" "$1" "$X"; }
die()  { printf '%s xx %s%s\n' "$R" "$1" "$X" >&2; exit 1; }

NO_SETUP=0; NO_BROWSER=0; ASSUME_YES=0
for a in "$@"; do case "$a" in
  --no-setup)   NO_SETUP=1 ;;
  --no-browser) NO_BROWSER=1 ;;
  --yes|-y)     ASSUME_YES=1 ;;
  -h|--help)    usage; exit 0 ;;
  *)            die "unknown option: $a  (try --help)" ;;
esac; done

cd "$(dirname "$0")"   # operate from the repo root (where this script lives)

# ---- 1. OS + Python 3.11+ -------------------------------------------------
step "Checking prerequisites"
case "$(uname -s)" in
  Linux|Darwin) : ;;
  *) warn "Untested OS '$(uname -s)' — proceeding, but Docker may be smoother." ;;
esac

find_python() {
  for c in python3.13 python3.12 python3.11 python3 python; do
    command -v "$c" >/dev/null 2>&1 || continue
    "$c" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] >= (3, 11) else 1)' 2>/dev/null \
      && { command -v "$c"; return 0; }
  done
  return 1
}
PYBIN="$(find_python)" || die "Python 3.11+ not found. Install it, or use Docker: docker compose up --build"
info "Python: $("$PYBIN" --version 2>&1)  ($PYBIN)"

# ---- 2. virtual environment ----------------------------------------------
step "Setting up the virtual environment"
if [ -n "${VIRTUAL_ENV:-}" ]; then
  VENV="$VIRTUAL_ENV"; info "Using the active venv: $VENV"
else
  VENV="$PWD/.venv"
  [ -d "$VENV" ] || "$PYBIN" -m venv "$VENV"
  info "venv: $VENV"
fi
PY="$VENV/bin/python"
[ -x "$PY" ] || die "venv python missing at $PY"

# ---- 3. install the package ----------------------------------------------
step "Installing hermes-swarm (+ hermes-agent) — this can take a few minutes"
"$PY" -m pip install --quiet --upgrade pip
if [ -f pyproject.toml ] && grep -q 'name *= *"hermes-swarm"' pyproject.toml; then
  info "Editable install from this repo (pip install -e .)"
  "$PY" -m pip install -e .          # editable → no stale shadow copy
else
  info "Installing from PyPI (pip install hermes-swarm)"
  "$PY" -m pip install hermes-swarm
fi
HV="$("$PY" -c 'from importlib.metadata import version; print(version("hermes-agent"))' 2>/dev/null || echo '?')"
info "hermes-agent $HV installed."

# ---- 4. browser for the publishing tools ---------------------------------
if [ "$NO_BROWSER" -eq 0 ]; then
  step "Browser (for the browser/publishing tools)"
  if "$PY" -c 'import sys; from swarm_server.browser_pool import _find_browser; sys.exit(0 if _find_browser() else 1)' 2>/dev/null; then
    info "Found a usable Chrome/Chromium — skipping the download."
  else
    info "No system Chrome found — downloading Playwright Chromium…"
    "$PY" -m playwright install chromium || warn "Chromium install failed; browser tools will be unavailable."
  fi
else
  warn "--no-browser: skipping Chromium (browser tools will be unavailable)."
fi

# ---- 5. provider / model (adopt existing, else set up) -------------------
step "Provider / model"
is_configured() { "$PY" -c 'import sys; from swarm_server.model_config import is_model_configured; sys.exit(0 if is_model_configured() else 1)' 2>/dev/null; }
if [ -n "${SWARM_LLM_BASE_URL:-}" ]; then
  info "SWARM_LLM_BASE_URL is set → using your OpenAI-compatible / LiteLLM proxy. Skipping hermes setup."
elif is_configured; then
  info "A provider is already configured (your ~/.hermes or a swarm default) — adopting it. Nothing to do."
elif [ "$NO_SETUP" -eq 1 ] || [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
  warn "No provider configured. Run it yourself when ready:  $VENV/bin/hermes setup"
else
  info "No provider configured — launching Hermes' setup wizard (40+ providers)…"
  "$VENV/bin/hermes" setup || warn "hermes setup didn't finish — rerun: $VENV/bin/hermes setup"
fi

# ---- 6. verify ------------------------------------------------------------
step "Verifying (hermes-swarm doctor)"
"$VENV/bin/hermes-swarm" doctor || warn "doctor flagged issues above — resolve them before 'hermes-swarm up'."

# ---- done -----------------------------------------------------------------
REL_VENV="${VENV#"$PWD"/}"
step "Done"
printf '    %sActivate:%s  source %s/bin/activate\n' "$B" "$X" "$REL_VENV"
printf '    %sScaffold:%s  hermes-swarm init        %s# starter team + coordinator%s\n' "$B" "$X" "$Y" "$X"
printf '    %sRun:     %s  hermes-swarm up          %s# dashboard → http://127.0.0.1:8000%s\n' "$B" "$X" "$Y" "$X"
