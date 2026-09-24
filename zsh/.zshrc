# ===================== базовые ENV =====================
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

export EDITOR="nvim"
export LANG="en_US.UTF-8"
ZSH_CONFIG_DIR="${${(%):-%N}:A:h}"
# export NO_PROXY="localhost,127.0.0.1,::1"
# export HTTPS_PROXY="http://127.0.0.1:10808"
# export HTTP_PROXY="http://127.0.0.1:10808"

# Пути
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
[[ -d /opt/cuda ]] && export CUDA_HOME=/opt/cuda
# ===================== oh-my-zsh =====================
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
fpath=("$HOME/.local/share/zsh/site-functions" $fpath)
ZSH_THEME=""  # используем starship

plugins=(
  git
  fzf
)

[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

for plugin_file in \
  "${ZSH_AUTOSUGGESTIONS:-}" \
  "$ZSH/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  if [[ -n "$plugin_file" && -r "$plugin_file" ]]; then
    source "$plugin_file"
    break
  fi
done

# ===================== zsh options =====================
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt EXTENDED_GLOB
setopt NO_BEEP

# history
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY

# ===================== completions =====================
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ===================== интерактивный шелл =====================
if [[ $- == *i* ]] && [ -t 1 ]; then
  # keybindings
  bindkey -e
  bindkey "^N" history-beginning-search-forward
  bindkey "^P" history-beginning-search-backward
  bindkey "^[[A" history-beginning-search-backward
  bindkey "^[[B" history-beginning-search-forward

  # edit command in nvim
  autoload -Uz edit-command-line
  zle -N edit-command-line
  bindkey '^x^e' edit-command-line

  # autosuggest accept
  (( ${+widgets[autosuggest-accept]} )) && bindkey '^ ' autosuggest-accept

  # starship & zoxide
  export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
  command -v starship >/dev/null && eval "$(starship init zsh)"
  command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
  # zle widgets
  zle -N fzf_code_open
  bindkey '^o' fzf_code_open

  # Strip leading/trailing whitespace from pasted text only
  bracketed-paste() {
    zle .bracketed-paste
    BUFFER="${BUFFER#"${BUFFER%%[![:space:]]*}"}"  # strip leading
    BUFFER="${BUFFER%"${BUFFER##*[![:space:]]}"}"  # strip trailing
  }
  zle -N bracketed-paste

  bindkey ' ' magic-space
fi

# ===================== функции =====================
function pi() {
  if [[ ! -t 0 || ! -t 1 ]]; then
    command pi "$@"
    return $?
  fi

  printf '\033[?1049h\033[H'
  command pi "$@"
  local exit_code=$?
  printf '\033[?1049l'
  return $exit_code
}

function field() {
  awk -F "${2:- }" "{print \$${1:-1} }"
}

function fzf_code_open() {
  local file
  file=$(find . -type f | fzf --preview "bat {}")
  [[ -n "$file" ]] && nvim "$file"
}

function mi() {
  if [ "$#" -eq 0 ]; then
    echo "Usage: mi <directory_name>" >&2
  elif [ "$#" -eq 1 ]; then
    mkdir -p "$1" && touch "$1/__init__.py"
    echo "Done"
  else
    for f in "$@"; do
      mkdir -p "$f" && touch "$f/__init__.py"
    done
    echo "Done"
  fi
}

function de() {
  if [ -e "./.envrc" ]; then
    echo "File .envrc already exists"
  else
    cat > .envrc <<'EOF'
# .envrc
if [ -d .venv ]; then
  source .venv/bin/activate
elif [ -d venv ]; then
  source venv/bin/activate
fi
EOF
    direnv allow .
    echo "Created and successfully"
  fi
}

[[ -f ~/.zsh_private ]] && source ~/.zsh_private

# ===================== env tools =====================
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# ===================== aliases =====================
alias dcc="docker compose"
alias dl='docker_logs_follow'
alias nf='fzf_code_open'
alias kk="ps -ef | fzf --multi | awk '{print \$2}' | xargs kill -9"
alias n="nvim"
alias nz="nvim ~/.dotfiles/zsh/.zshrc"
alias sz="exec zsh"
alias b="bat --theme=Dracula"
alias ls="eza --icons"
alias cd3="cd ../../.."
alias cd4="cd ../../../.."
alias rn="rg --no-ignore --hidden"
alias hl="rg -i --passthru"
alias dcf="docker compose up --build"
alias dcl="docker compose logs"
alias dcd="docker compose down"
alias dcp="docker compose ps -a"
alias vimdiff="nvim -d"
alias lg="lazygit"
alias y="yazi"
alias lst="lsof -i -P -n | grep LISTEN"
alias ll="ls -lah"
alias glc="git clone"
alias nn="cd ~/.dotfiles/nvim/.config && nvim ."
alias g="git"
alias ga="git add"
alias gaa="git add --all"
alias gc="git commit"
alias gcm="git commit -m"
alias gco="git checkout"
alias gd="git diff"
alias gst="git status"
alias gp="git push"
alias gl="git pull"
alias glog="git log --oneline --graph"
alias cl="claude"
#alias swit='ssh -p ${MY_PORT} -f -N -L 7596:localhost:30555 ${MY_USER}@${MY_IP} -i ${MY_PATH}'
alias p="python3"
# global aliases
alias -g J='| jq'
alias -g G='| grep'
alias -g L='| less'
alias -g H='| head'
alias -g T='| tail'
alias oc="opencode"
alias glo='brave "$(git remote get-url origin | sed "s|git@||;s|\.git$||;s|:|/|")"'
alias glm='brave "https://$(git remote get-url origin | sed "s|git@||;s|\.git$||;s|:|/|")/-/merge_requests/new?merge_request%5Bsource_branch%5D=$(git branch --show-current)"'
alias code="vscodium"
alias gpw="rbw list | fzf | xargs rbw get W"
alias csx="codex -s danger-full-access"

function docker_logs_follow() {
  local container
  container=$(docker ps --format '{{.ID}}\t{{.Image}}\t{{.Names}}' \
    | fzf --with-nth=2,3 --header 'Select container' \
    | awk '{print $1}')
  [[ -n "$container" ]] && docker logs -f "$container"
}

if [[ "$OSTYPE" == darwin* ]]; then
  alias pbp='pwd | pbcopy'
  alias -g W='| pbcopy'
else
  alias pbp='pwd | wl-copy'
  alias open='xdg-open'
  alias -g W='| wl-copy'
  alias rm='rm -I --preserve-root'
  alias chmod='chmod --preserve-root'
  alias chown='chown --preserve-root'
fi


# fnm
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env)"
fi

LOCAL_JDK_HOME="$HOME/.local/opt/jdk-26.0.1"
if [[ -d "$LOCAL_JDK_HOME/bin" ]]; then
  export JAVA_HOME="$LOCAL_JDK_HOME"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
unset LOCAL_JDK_HOME

# pnpm
if [[ "$OSTYPE" == darwin* ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="$HOME/.local/share/pnpm"
fi
for pnpm_path in "$PNPM_HOME/bin" "$PNPM_HOME"; do
  case ":$PATH:" in
    *":$pnpm_path:"*) ;;
    *) export PATH="$pnpm_path:$PATH" ;;
  esac
done
unset pnpm_path
# pnpm end

export INIR_VENV="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/.venv"
export ILLOGICAL_IMPULSE_VIRTUAL_ENV="$INIR_VENV"
if [[ -o interactive && -t 1 && -r "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/terminal/sequences.txt" ]]; then
  cat "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/terminal/sequences.txt"
fi


# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
[[ ! -r "$HOME/.opam/opam-init/init.zsh" ]] || source "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null
# END opam configuration

# blacklist-обёртка для yay
if [[ "$OSTYPE" == linux* && -r "$ZSH_CONFIG_DIR/yay-blacklist.zsh" ]]; then
  source "$ZSH_CONFIG_DIR/yay-blacklist.zsh"
fi

# dcg: warn if hook was silently removed from Claude Code settings
if command -v dcg &>/dev/null && command -v jq &>/dev/null; then
  if [ -f "$HOME/.claude/settings.json" ] && \
     ! jq -e '.hooks.PreToolUse[]? | select(.hooks[]?.command | test("dcg$"))' \
       "$HOME/.claude/settings.json" &>/dev/null; then
    printf '\033[1;33m[dcg] Hook missing from ~/.claude/settings.json — run: dcg install\033[0m\n'
  fi
fi

for plugin_file in \
  "${ZSH_SYNTAX_HIGHLIGHTING:-}" \
  "$ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  if [[ -n "$plugin_file" && -r "$plugin_file" ]]; then
    source "$plugin_file"
    break
  fi
done
