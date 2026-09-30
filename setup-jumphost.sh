#!/usr/bin/env bash
# One-time jumphost setup. Run it over SSH with VS Code closed.
#
# It creates $NAS_HOME/.home, your home folder inside jobs, and moves your jumphost
# settings there (shell startup files, VS Code server, Run:AI login, caches, Git
# identity, ~/.local). Your jumphost home then only contains links to it, and
# the jumphost and your jobs share the same settings.
#
# Your NAS folder is /mnt/cvlab/scratch/cvlab/home/<username>. If yours has another
# name, give it: NAS_HOME=/mnt/cvlab/scratch/cvlab/home/FOLDER bash setup-jumphost.sh
# It is safe to run again. It never overwrites existing files.
set -euo pipefail
umask 077
tutorial_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

step=0
start() { step=$((step + 1)); printf '\n[%d/5] %s\n' "$step" "$1"; }
finish() { printf '      Done.\n'; }
trap 'status=$?; if (( status != 0 )); then printf "\nSetup stopped at step %d. Fix the problem above, then run it again.\n" "$step" >&2; fi' EXIT

nas_home=${NAS_HOME:-/mnt/cvlab/scratch/cvlab/home/$(id -un)}
state=$nas_home/.home

start "Checking your NAS folder: $nas_home"
if [[ ! -d "$nas_home" ]]; then
    echo "Your NAS folder is missing: $nas_home" >&2
    exit 1
fi
# Earlier versions of this tutorial used $NAS_HOME/home or $NAS_HOME/jumphost.
for old_state in "$nas_home/home" "$nas_home/jumphost"; do
    if [[ -d "$old_state" && ! -L "$old_state" && ! -e "$state" ]]; then
        mv -- "$old_state" "$state"
        echo "      Renamed $old_state to $state"
    fi
done
mkdir -p "$state/.kube" "$nas_home/datasets" "$nas_home/outputs"
# Stops Ubuntu's sudo hint in jobs, which prints "groups: cannot find name for group ID".
touch "$state/.hushlogin"
echo "      Your settings will be kept in $state"
finish

# Move the contents of folder $1 into folder $2, without overwriting anything.
merge_into() {
    local src=$1 dst=$2 entry name
    for entry in "$src"/* "$src"/.[!.]* "$src"/..?*; do
        [[ -e "$entry" || -L "$entry" ]] || continue
        name=${entry##*/}
        if [[ ! -e "$dst/$name" && ! -L "$dst/$name" ]]; then
            mv -- "$entry" "$dst/$name"
        elif [[ -d "$entry" && ! -L "$entry" && -d "$dst/$name" && ! -L "$dst/$name" ]]; then
            merge_into "$entry" "$dst/$name"
        else
            echo "Both $entry and $dst/$name exist. Keep one, then run this again." >&2
            exit 1
        fi
    done
    rmdir -- "$src"
}

# Move an existing file or folder to the NAS, then leave a link in its place.
link_to_nas() {
    local name=$1 kind=${2:-dir}
    local original=$HOME/$name target=$state/$name
    if [[ -L "$original" && "$(readlink "$original")" == "$target" ]]; then
        echo "      ~/$name: already on the NAS"
        return
    fi
    if [[ -L "$original" ]]; then
        # A link made by an earlier run of this script, to another NAS folder:
        # move what it points to here, then relink.
        local old
        old=$(readlink "$original")
        local made_by_us=0
        case "$old" in
            /mnt/cvlab/scratch/cvlab/home/*/.home/* | /mnt/cvlab/scratch/cvlab/home/*/home/* | \
            /mnt/cvlab/scratch/cvlab/home/*/jumphost/*) made_by_us=1 ;;
        esac
        # Its folder was renamed to $state above: just point the link there.
        if (( made_by_us )) && [[ ! -e "$old" && -e "$target" ]]; then
            rm -- "$original"
            ln -s -- "$target" "$original"
            echo "      ~/$name: link updated"
            return
        fi
        if (( made_by_us )) && [[ -e "$old" ]]; then
            rm -- "$original"
            if [[ ! -e "$target" ]]; then
                mv -- "$old" "$target"
            elif [[ -d "$old" && -d "$target" ]]; then
                merge_into "$old" "$target"
            else
                echo "Both $old and $target exist. Keep one, then run this again." >&2
                ln -s -- "$old" "$original"
                exit 1
            fi
            ln -s -- "$target" "$original"
            echo "      ~/$name: moved from $old"
            return
        fi
        echo "$original is a link to somewhere else. Remove or move it, then run this again." >&2
        exit 1
    fi
    local what
    if [[ -e "$original" && -e "$target" ]]; then
        if [[ -d "$original" && -d "$target" ]]; then
            merge_into "$original" "$target"
            what="merged into the NAS copy"
        else
            echo "Both $original and $target exist. Keep one, then run this again." >&2
            exit 1
        fi
    elif [[ -e "$original" ]]; then
        mv -- "$original" "$target"
        what="moved to the NAS"
    elif [[ -e "$target" ]]; then
        what="linked to the existing NAS copy"
    else
        if [[ $kind == dir ]]; then mkdir -p "$target"; else touch "$target"; fi
        what="created on the NAS"
    fi
    ln -s -- "$target" "$original"
    echo "      ~/$name: $what"
}

start "Moving your tool settings to the NAS (your jumphost home keeps links to them)"
for name in .vscode .vscode-server .runai .config .cache .local .npm; do
    link_to_nas "$name"
done
link_to_nas .gitconfig file
mkdir -p "$state/.local/bin"
finish

start "Writing the settings loaded by every terminal, and adding the dev, train, windows and rcp-init commands: $state/env.sh"
cat > "$state/env.sh" <<ENV
export GASPAR_USERNAME=$(id -un)
export NAS_HOME=$nas_home
export KUBECONFIG=$state/.kube/rcp-config
export HISTFILE=$state/.bash_history
export npm_config_prefix=$state/.local
export SUPPRESS_DEPRECATION_MESSAGE=true   # hides runai's "CLI v1 is now deprecated" notice
case ":\$PATH:" in *":$state/.local/bin:"*) ;; *) export PATH="\$PATH:$state/.local/bin" ;; esac
# The tutorial's commands: dev, train, windows and rcp-init. Run with bash, so file permissions don't matter.
dev() { bash "$tutorial_dir/bin/dev" "\$@"; }
train() { bash "$tutorial_dir/bin/train" "\$@"; }
windows() { bash "$tutorial_dir/bin/windows" "\$@"; }
rcp-init() { bash "$tutorial_dir/bin/rcp-init" "\$@"; }
# In a job, your user ID has no name in the container: show your username and the job instead
# of "I have no name!".
if [[ -n "\${RCP_JOB:-}" ]]; then
    PS1='\${GASPAR_USERNAME}@\${RCP_JOB}:\\w\\$ '
fi
# In a job, open the shell in the folder where you typed dev (left there by rcp/interactive.sh).
if [[ -n "\${RCP_JOB:-}" && -f "$state/.rcp-cd" ]]; then
    cd "\$(cat "$state/.rcp-cd")" 2>/dev/null || true
    rm -f "$state/.rcp-cd"
fi
ENV

# tmux settings for coding assistants (used by `windows`). Missing lines are added, yours are kept.
tmux_lines=(
    'set -gq focus-events on      # apps know when their pane is active'
    'set -gq mouse on             # click a pane to select it, scroll with the wheel'
    'set -gq escape-time 10       # Esc reacts immediately'
    'set -gq extended-keys on     # Shift+Enter and similar keys reach the apps'
    'set -gq history-limit 50000  # more scrollback'
)
touch "$state/.tmux.conf"
for line in "${tmux_lines[@]}"; do
    name=$(awk '{print $3}' <<<"$line")
    grep -qE "^[[:space:]]*set(-option)?[[:space:]].*[[:space:]]$name([[:space:]]|$)" "$state/.tmux.conf" \
        || printf '%s\n' "$line" >> "$state/.tmux.conf"
done
echo "      tmux settings: $state/.tmux.conf"
finish

# Shell startup files also live on the NAS. In jobs, HOME is $state, so jobs
# read the same files. If both copies exist, the jumphost one is appended.
login_profile=.profile
for name in .bash_profile .bash_login; do
    if [[ -e "$HOME/$name" || -e "$state/$name" ]]; then login_profile=$name; break; fi
done
load_line="test ! -f $state/env.sh || source $state/env.sh"
start "Moving your shell startup files (~/.bashrc, ~/$login_profile) to the NAS"
for profile in .bashrc "$login_profile"; do
    if [[ -f "$HOME/$profile" && ! -L "$HOME/$profile" && -f "$state/$profile" ]]; then
        { printf '\n# From the jumphost %s\n' "$profile"; cat -- "$HOME/$profile"; } >> "$state/$profile"
        rm -- "$HOME/$profile"
        echo "      ~/$profile: added to the end of the NAS copy"
    fi
    link_to_nas "$profile" file
    grep -qxF "$load_line" "$state/$profile" || printf '\n%s\n' "$load_line" >> "$state/$profile"
done
finish

start "Configuring Run:AI for the RCP cluster"
if [[ ! -f "$state/.kube/rcp-config" ]]; then
    echo "      Downloading the cluster configuration from the RCP wiki"
    curl -fsSL https://wiki.rcp.epfl.ch/public/files/kube-config.yaml -o "$state/.kube/rcp-config"
else
    echo "      Cluster configuration already present"
fi
KUBECONFIG=$state/.kube/rcp-config runai config cluster rcp-caas-prod >/dev/null
finish

printf '\nSetup complete. Open a new terminal (or run: source %s), then run: runai login\n' "$state/env.sh"
