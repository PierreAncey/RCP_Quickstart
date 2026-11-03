#!/usr/bin/env bash
# Install Claude Code, Codex and Antigravity in your NAS home. Run it once, inside a job:
#   dev                                            (on the jumphost)
#   bash "$NAS_HOME/RCP_tutorial/setup-agents.sh"  (inside the job)
#
# Assistants can't run on the jumphost. In jobs, your home folder is
# $NAS_HOME/.home, so the programs, logins and conversations stay there for later jobs.
set -euo pipefail
rcp=$(cd "$(dirname "${BASH_SOURCE[0]}")/rcp" && pwd)
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

# Rules for Codex and Antigravity, which only read them from your home folder.
# Claude Code gets its rules per project, from rcp-init.
mkdir -p ~/.codex/rules ~/.gemini/antigravity-cli
cp "$rcp/codex.rules" ~/.codex/rules/rcp.rules
python3 - "$rcp/antigravity-settings.json" ~/.gemini/antigravity-cli/settings.json <<'PY' \
    || echo "Could not update ~/.gemini/antigravity-cli/settings.json (not valid JSON?). Merge rcp/antigravity-settings.json by hand." >&2
import json, os, sys
ours, path = json.load(open(sys.argv[1])), sys.argv[2]
theirs = json.load(open(path)) if os.path.exists(path) else {}
perms = theirs.setdefault("permissions", {})
ours["permissions"]["deny"].append(f"write_file({os.environ['NAS_HOME']}/datasets/)")
for key, rules in ours["permissions"].items():
    have = perms.setdefault(key, [])
    have.extend(rule for rule in rules if rule not in have)
with open(path, "w") as f:
    json.dump(theirs, f, indent=2)
    f.write("\n")
PY

cat <<'EOF'

Done. Now log in once:
  claude                       Claude Code: follow the link it prints
  codex login --device-auth    Codex: enter the code it prints in your browser
  agy                          Antigravity: choose Google OAuth, open the link, paste the code back
EOF
