# ===================== базовые ENV =====================
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

export EDITOR="nvim"
export LANG="en_US.UTF-8"
# export NO_PROXY="localhost,127.0.0.1,::1"
# export HTTPS_PROXY="http://127.0.0.1:10808"
# export HTTP_PROXY="http://127.0.0.1:10808"

# Пути
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# ===================== oh-my-zsh =====================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # используем starship

plugins=(
  git
  fzf
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

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
  bindkey '^ ' autosuggest-accept

  # starship & zoxide
  export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
  eval "$(starship init zsh)"
  eval "$(zoxide init zsh)"

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
eval "$(direnv hook zsh)"
eval "$(batman --export-env)"

# ===================== aliases =====================
alias dl="docker ps --format '{{.ID}}\t{{.Image}}\t{{.Names}}' | fzf --with-nth=2,3 --header 'Select container' | awk '{print \$1}' | xargs -r docker logs -f"
alias nf="fd --type f --hidden --exclude .git | fzf --preview 'bat --color=always --style=numbers --line-range :100 {}' | xargs -r nvim"
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
alias man="batman"
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
alias pbp='pwd | wl-copy'
alias open="xdg-open"
alias swit='ssh -p ${MY_PORT} -f -N -L 7596:localhost:30555 ${MY_USER}@${MY_IP} -i ${MY_PATH}'
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


# pnpm
export PNPM_HOME="/home/yea8er/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# fnm
FNM_PATH="/home/yea8er/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi
