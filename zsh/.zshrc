# ===================== базовые ENV =====================
source $HOME/.zshenv

export EDITOR="nvim"
export LANG="en_US.UTF-8"
export NO_PROXY="localhost,127.0.0.1,::1"
export HTTPS_PROXY="http://127.0.0.1:10808"
export HTTP_PROXY="http://127.0.0.1:10808"

# Пути
[ -f "/Users/yea8er/.ghcup/env" ] && . "/Users/yea8er/.ghcup/env"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
. "$HOME/.local/bin/env"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/yea8er/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# opencode
export PATH=/Users/yea8er/.opencode/bin:$PATH

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
_cache_completion() {
  local file=~/.zfunc/_$1
  [[ -s $file ]] || eval "$2" > $file 2>/dev/null
}

mkdir -p ~/.zfunc
_cache_completion uv "uv generate-shell-completion zsh"
_cache_completion fnm "fnm completions --shell zsh"
_cache_completion docker "docker completion zsh"

fpath=(~/.zfunc /opt/homebrew/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit

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

  # fzf
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

  # starship & zoxide
  export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
  eval "$(/opt/homebrew/bin/starship init zsh)"
  eval "$(zoxide init zsh)"

  # plugins (brew prefix кэшируем)
  _brew_prefix="/opt/homebrew"
  source $_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  source $_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  bindkey '^ ' autosuggest-accept

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

fi

# ===================== функции =====================
function field() {
  awk -F "${2:- }" "{print \$${1:-1} }"
}

function fzf_ctrl_r_opts () {
  export FZF_CTRL_R_OPTS="
    --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
    --color header:italic
    --header 'Press CTRL-Y to copy command into clipboard'"
  export FZF_ALT_C_OPTS="
    --walker-skip .git,node_modules,target
    --preview 'tree -C {}'"
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

# ===================== env =====================
eval "$(batman --export-env)"
eval "$(direnv hook zsh)"

# ===================== aliases =====================
alias dl="docker ps --format '{{.ID}}\t{{.Image}}\t{{.Names}}' | fzf --with-nth=2,3 --header 'Select container' | awk '{print \$1}' | xargs -r docker logs -f"
alias nf="fd --type f --hidden --exclude .git | fzf --preview 'bat --color=always --style=numbers --line-range :100 {}' | xargs -r nvim"
alias kk="ps -ef | fzf --multi | awk '{print \$2}' | xargs kill -9"
alias n="nvim"
alias p="python3.14"
alias nz="nvim ~/.dotfiles/zsh/.zshrc"
alias sz="exec zsh"
alias b="bat --theme=Dracula"
alias pi="pip3 install"
alias bi="brew install"
alias ls="eza --icons"
alias tpr="telepresence"
alias cd3="cd ../../.."
alias cd4="cd ../../../.."
alias rn="rg --no-ignore --hidden"
alias pir="pip3 install -r requirements.txt"
alias hl="rg -i --passthru"
alias dcf="docker compose up --build"
alias dcl="docker compose logs"
alias dcd="docker compose down"
alias dcp="docker compose ps -a"
alias vimdiff="nvim -d"
alias lg="lazygit"
alias bws="~/.config/bin/bw.sh"
alias y="yazi"
alias man="batman"
alias csh="~/.config/scripts/check_hash.sh"
alias lst="lsof -i -P -n | grep LISTEN"
alias ll="ls -lah"
alias pbp='pwd | pbcopy'
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

# global aliases
alias -g J='| jq'
alias -g G='| grep'
alias -g L='| less'
alias -g H='| head'
alias -g T='| tail'

bindkey ' ' magic-space
