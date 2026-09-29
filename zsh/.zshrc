# ─── NIX ────────────────────────────────────────────────────
# Sourced here rather than relying on /etc/zshrc: macOS updates overwrite
# that file and drop the block the Nix installer added.
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
# test
# ─── HOMEBREW ───────────────────────────────────────────────
eval "$(/opt/homebrew/bin/brew shellenv zsh)"
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"

# ─── 🛠️  LOCAL BIN ───────────────────────────────────────────
typeset -U path PATH
export PATH="$HOME/.local/bin:$PATH"

# ─── OH MY POSH ─────────────────────────────────────────────
eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/zash.omp.json)"

# ─── ✍️   EDITOR ─────────────────────────────────────────────
export EDITOR='nvim'
export VISUAL='nvim'
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT='-c'

# ─── ⌨️  LINE EDITING ────────────────────────────────────────
# emacs keymap, stated rather than inherited: zsh picks vi mode when $EDITOR
# matches *vi*, and "nvim" does. It reads EDITOR at startup, before this file,
# so the default holds today, but an EDITOR exported from a parent process
# would silently flip every Ctrl+A into a vi motion.
bindkey -e
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[U' redo
# empty WORDCHARS: Alt+B, Alt+F and Ctrl+W stop at / . - _ rather than treating
# a whole path as a single word
WORDCHARS=''

# ─── BASIC ALIASES ──────────────────────────────────────────
alias e='nvim'
alias g='git'
alias cl='clear'
alias py='python3.12'
alias python3='python3.12'
alias reload='source ~/.zshrc && echo "✅ Shell reloaded"'
alias back='cd -'
alias cce='set -a && source .env && claude'

function lg {
  local paint_green_blue=$'\e]4;2;#7aa2f7\a\e]4;10;#7aa2f7\a'
  local restore_green=$'\e]104;2;10\a'
  printf '%s' "$paint_green_blue"
  { lazygit "$@" } always { printf '%s' "$restore_green" }
}

# ─── 📝 CONFIG FILE SHORTCUTS ───────────────────────────────
# sourced, not executed: run as a script, sync.sh reloads its own subshell and
# dies with it, so this shell never sees the new aliases
alias sync-config='source ~/raph_config/sync.sh'
# every one of these opens the file in the REPO, never the copy under ~: the
# copies are overwritten on the next sync, so edits there are lost silently
alias config='nvim ~/raph_config/zsh/.zshrc'
alias gconfig='nvim ~/raph_config/git/.gitconfig'
alias confposh='nvim ~/raph_config/zsh/zash.omp.json'
alias confvim='nvim ~/raph_config/nvim'

# ─── 🔍 SEARCH & FIND ───────────────────────────────────────
# fd and rg read .gitignore, so no manual venv/.git/node_modules excludes
alias ff='fd'                    # ff <name>    file by name
alias fgrep='rg'                 # fgrep <txt>  search file contents

# ─── 🧭 NAVIGATION ──────────────────────────────────────────
# zoxide takes over `cd` entirely: `cd raph` jumps to ~/raph_config from
# anywhere, while `cd ..`, `cd -` and `cd /abs/path` keep their usual meaning.
# `cdi` opens an fzf picker over the ranked matches.
eval "$(zoxide init zsh --cmd cd)"
# one letter for the two that get typed all day
alias c='cd'
alias ci='cdi'

# yazi: `y` rather than `yazi`, so the shell lands in the directory you browsed
# to instead of the one you started from
y() {
      local tmp target
      tmp="$(mktemp -t yazi-cwd.XXXXXX)"
      yazi "$@" --cwd-file="$tmp"
      target="$(<"$tmp")"
      # builtin cd on purpose: the path is already absolute, no need to send it
      # through zoxide's matching. The chpwd hook records it either way.
      [ -n "$target" ] && [ "$target" != "$PWD" ] && builtin cd -- "$target"
      rm -f -- "$tmp"
}

# ─── 🌱 DIRENV ──────────────────────────────────────────────
# per-directory environments: an .envrc is loaded on entry, unloaded on exit.
# Must come after any prompt init, it hooks into precmd.
eval "$(direnv hook zsh)"

# ─── 🔎 FZF ─────────────────────────────────────────────────
# Ctrl+R history, Ctrl+T file paths, Alt+C cd into a subdirectory
eval "$(fzf --zsh)"

# fd rather than find: it reads .gitignore, skips .git, and is much faster.
# --hidden is on because dotfiles are exactly what this machine edits.
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# bg:-1 keeps the terminal background, so wezterm's opacity shows through
export FZF_DEFAULT_OPTS="
  --height 60% --layout reverse --border rounded --info inline
  --color fg:#c0caf5,bg:-1,hl:#7aa2f7
  --color fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff
  --color info:#7aa2f7,prompt:#7dcfff,pointer:#bb9af7
  --color marker:#9ece6a,spinner:#9ece6a,header:#565f89,border:#414868
  --bind 'ctrl-/:toggle-preview'
  --bind 'alt-up:preview-half-page-up,alt-down:preview-half-page-down'
"

# Ctrl+T: the file, syntax highlighted, first 200 lines
export FZF_CTRL_T_OPTS="
  --preview 'bat --color=always --style=numbers --line-range=:200 {}'
  --preview-window 'right,60%,border-left'
"

# Alt+C: the directory as a tree
export FZF_ALT_C_OPTS="
  --preview 'eza --tree --level=2 --color=always --group-directories-first {}'
  --preview-window 'right,50%,border-left'
"

# Ctrl+R: long commands wrap in the preview instead of being truncated.
# {2..} drops the history index fzf prefixes each line with.
export FZF_CTRL_R_OPTS="
  --preview 'echo {2..}' --preview-window 'down,3,wrap,border-top'
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --header 'ctrl-y: copy the command'
"

# ─── 🔎 FZF POWER TOOLS ─────────────────────────────────────
# frg [pattern]   live ripgrep over the project: the search reruns on every
# keystroke, the preview shows the hit in context, Enter opens nvim on the line
frg() {
  local rg_cmd="rg --column --line-number --no-heading --color=always --smart-case"
  local out file line
  out=$(
    FZF_DEFAULT_COMMAND="$rg_cmd ${(q)${1:-\"\"}}" \
      fzf --ansi --disabled --query "${1:-}" \
          --bind "change:reload:$rg_cmd {q} || true" \
          --delimiter : \
          --preview 'bat --color=always --style=numbers --highlight-line {2} {1}' \
          --preview-window 'right,60%,border-left,+{2}+3/3' \
          --header 'type to search across the project'
  ) || return
  file=${out%%:*}
  line=${${out#*:}%%:*}
  [ -n "$file" ] && nvim "+$line" -- "$file"
}

# fbr   switch branch, sorted by most recent commit, with its log as preview
fbr() {
  local branch
  branch=$(
    git branch --all --color=always --sort=-committerdate |
      grep -v head |
      fzf --ansi --header 'enter: switch to the branch' \
          --preview 'git log --oneline --graph --date=short --color=always \
                       --pretty="%c(auto)%cd %h%d %s" \
                       $(sed "s/^[* ]*//;s#^remotes/[^/]*/##" <<< {}) | head -50' |
      sed 's/^[* ]*//;s#^remotes/[^/]*/##' |
      awk '!seen[$0]++'
  ) || return
  [ -n "$branch" ] && git switch "$branch"
}

# fkill [signal]  pick processes (Tab for several) and signal them.
# Defaults to TERM, which lets the process clean up; `fkill 9` to force.
fkill() {
  local pids
  pids=$(
    ps -eo pid,ppid,%cpu,%mem,comm,args | sed 1d |
      fzf --multi --header 'tab: select several, enter: signal them' \
          --preview 'echo {}' --preview-window 'down,3,wrap,border-top' |
      awk '{print $1}'
  ) || return
  [ -z "$pids" ] && return
  echo "$pids" | xargs kill -"${1:-15}"
}

# flog  browse git log, preview each commit's diff, Enter copies the sha
flog() {
  local sha
  sha=$(
    git log --color=always --date=short \
        --format='%C(auto)%h %C(blue)%cd %C(green)%an%C(auto)%d %s' "$@" |
      fzf --ansi --no-sort --header 'enter: copy the sha' \
          --preview 'git show --color=always --stat --patch {1}' \
          --preview-window 'right,60%,border-left' |
      awk '{print $1}'
  ) || return
  [ -n "$sha" ] && print -n "$sha" | pbcopy && echo "📋 $sha copied"
}

# one letter, it is the most used of the four
alias f='fzf'

# ─── 🧰 MODERN CLI ──────────────────────────────────────────
alias ls='eza --group-directories-first'
alias ll='eza -lah --git --group-directories-first'
alias lt='eza --tree --level=2 --group-directories-first'
alias cat='bat -pp'              # plain, no pager; `bat <f>` for the full view
export BAT_THEME="TwoDark"

# ─── 🐍 PYTHON & POETRY ─────────────────────────────────────
alias po='poetry'
alias test='poetry run pytest'
alias linter='poetry run pre-commit run --all-files'
alias renv='rm -rf .venv && echo "✅ .venv deleted"'
alias dbtibf='/Users/arn/ibanfirst/dbt_ibf/.venv/bin/dbt'
pyvenv() {
  local py="${1:-python3.12}"
  if [ ! -d .venv ]; then
    "$py" -m venv .venv || return 1
  fi
  if [ ! -f .envrc ]; then
    command cat > .envrc <<'EOF'
export VIRTUAL_ENV="$PWD/.venv"
PATH_add "$VIRTUAL_ENV/bin"
dotenv_if_exists .env
EOF
    direnv allow
  fi
  source .venv/bin/activate
}

# ─── 💄 GITMOJI COMMIT ──────────────────────────────────────
gc() {
    if [[ "$1" =~ ^(fix|feat|docs|style|refactor|test|chore|config)$ && "$2" == :* ]]; then
        type=$1
        message="${*:2}"
        message="${message#:}"
        case $type in
            fix)      emoji="🐛 fix: " ;;
            feat)     emoji="✨ feat: " ;;
            docs)     emoji="📝 docs: " ;;
            style)    emoji="💄 style: " ;;
            refactor) emoji="♻️ refactor: " ;;
            test)     emoji="✅ test: " ;;
            chore)    emoji="🚀 chore: " ;;
            config)   emoji="🔧 config: " ;;
        esac
        git commit -m "$emoji$message"
    else
        git "$@"
    fi
}

# ─── 🐳 COLIMA ───────────────────────────────────────────────
alias cstart='colima start --disk 60 --memory 8 --cpu 4'
alias cstop='colima stop'
alias crestart='colima stop && colima start --disk 60 --memory 8 --cpu 4'
alias cstatus='colima status'
alias cdelete='colima delete'
alias clist='colima list'
alias cssh='colima ssh'

ccheck() {
    if ! colima status &>/dev/null; then
        echo "⚠️  Colima is not running. Starting..."
        colima start --disk 60 --memory 8 --cpu 4
    else
        echo "✅ Colima is active"
        colima status
    fi
}

cinfo() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🐳 COLIMA — 60GB | 8GB RAM | 4 CPUs"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    colima status
    echo ""
    echo "📦 CONTAINERS"
    docker ps
    echo ""
    echo "🖼️  IMAGES"
    docker images
}

creload() {
    echo "🔄 Restarting Colima..."
    colima stop && sleep 2
    colima start --disk 60 --memory 8 --cpu 4
    echo "✅ Colima restarted"
}

# ─── 🐳 DOCKER ──────────────────────────────────────────────
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dvol='docker volume ls'
alias dnet='docker network ls'
alias dlogs='docker logs -f'
alias dinspect='docker inspect'
alias dstats='docker stats'
alias dtop='docker top'
alias dstop='docker stop $(docker ps -q)'
alias dstopall='docker stop $(docker ps -aq)'
alias drm='docker rm $(docker ps -aq)'
alias drmiall='docker rmi $(docker images -q)'
alias dclean='docker system prune -af'
alias dcleanvol='docker volume prune -f'
alias dnuke='docker system prune -af --volumes'
alias drun='docker run -it --rm'
alias dexec='docker exec -it'
alias dcup='docker compose up -d'
alias dcdown='docker compose down'
alias dcrestart='docker compose restart'
alias dclogs='docker compose logs -f'
alias dcps='docker compose ps'
alias dcbuild='docker compose build'
alias dcpull='docker compose pull'
alias dcstop='docker compose stop'

dsh() {
    [ -z "$1" ] && echo "Usage: dsh <container>" && return 1
    docker exec -it "$1" sh -c '[ -x /bin/bash ] && /bin/bash || /bin/sh'
}

dlf() {
    [ -z "$1" ] && echo "Usage: dlf <container>" && return 1
    docker logs -f "$1"
}

dkill() {
    [ -z "$1" ] && echo "Usage: dkill <container>" && return 1
    docker stop "$1" && docker rm "$1"
}

drmi() {
    [ -z "$1" ] && echo "Usage: drmi <image>" && return 1
    docker rmi "$1"
}

dimgsize() {
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | sort -k 3 -h
}

# ─── ☕ JAVA ─────────────────────────────────────────────────
export JAVA_HOME="/opt/homebrew/opt/openjdk@21"
export PATH="$JAVA_HOME/bin:$PATH"


# ─── 🔮 AUTOCOMPLETION ──────────────────────────────────────
# Autosuggestions (grey hints from history)
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Syntax highlighting (commands in green/red)
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Extra completions
fpath[1,0]=$(brew --prefix)/share/zsh-completions

ZSH_DISABLE_COMPFIX=true
# Enable the completion system
autoload -Uz compinit && compinit -u

# Selection menu on Tab
zstyle ':completion:*' menu select
# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
alias fz='open /Applications/FileZilla.app'

alias db='open /Applications/DBeaver.app'
alias cc='claude'
alias mcpcc='set -a && source .env && claude --strict-mcp-config --mcp-config .mcp.json'
