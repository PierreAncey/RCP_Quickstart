#!/usr/bin/env bash
# Install Claude Code, Codex and Antigravity in your NAS home. Run it once, inside a job:
#   dev                                            (on the jumphost)
#   bash "$NAS_HOME/RCP_tutorial/setup-agents.sh"  (inside the job)
#
# Assistants can't run on the jumphost. In jobs, your home folder is
# $NAS_HOME/.home, so the programs, logins and conversations stay there for later jobs.
set -euo pipefail
if [[ -z "${RCP_JOB:-}" ]]; then
    echo "Run this inside a job (start one with: dev), not on the jumphost." >&2
    exit 1
fi

# Official installers. All three install into ~/.local/bin.
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash
command -v codex >/dev/null || curl -fsSL https://chatgpt.com/codex/install.sh | sh
command -v agy >/dev/null || curl -fsSL https://antigravity.google/cli/install.sh | bash

path_line='export PATH="$HOME/.local/bin:$PATH"'
grep -qxF "$path_line" ~/.bashrc 2>/dev/null || printf '\n%s\n' "$path_line" >> ~/.bashrc

cat <<'EOF'

Done. Now log in once:
  claude                       Claude Code: follow the link it prints
  codex login --device-auth    Codex: enter the code it prints in your browser
  agy                          Antigravity: choose Google OAuth, open the link, paste the code back
EOF
