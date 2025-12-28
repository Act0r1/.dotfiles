# ===================== базовые ENV =====================
source $HOME/.zshenv

export ZSH="$HOME/.oh-my-zsh"
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

#BUN
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/yea8er/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac


# Autocomplete
fpath+=~/.zfunc

# ========== плагины/темы только для интерактивного шелла ==========
if [[ $- == *i* ]] && [ -t 1 ]; then
  ZSH_THEME="robbyrussell"
  # plugins=(git z zsh-syntax-highlighting direnv zsh-autosuggestions)

  source $ZSH/oh-my-zsh.sh

  # fzf биндинги
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

  # keybindings
  bindkey "^N" history-beginning-search-forward
  bindkey "^P" history-beginning-search-backward

  # starship, zoxide и прочее UI
  export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
  eval "$(/opt/homebrew/bin/starship init zsh)"
  eval "$(zoxide init zsh)"

  # zle-функция для fzf_code_open
  zle -N fzf_code_open
  bindkey '^o' fzf_code_open
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
    echo "Created and successfully ✅"
  fi
}

if [[ -f ~/.zsh_private ]]; then
  source ~/.zsh_private
fi
# ===================== завершение =====================
eval "$(uv generate-shell-completion zsh)"
eval "$(batman --export-env)"

alias dl="docker ps --format '{{.ID}}\t{{.Image}}\t{{.Names}}' \
  | fzf --with-nth=2,3 --header 'Select container' \
  | awk '{print $1}' \
  | xargs -r docker logs -f
"
alias nf=" fd --type f --hidden --exclude .git \
    | fzf --preview 'bat --color=always --style=numbers --line-range :100 {}' \
    | xargs -r nvim"
alias kk="ps -ef | fzf --multi | awk '{print $2}' | xargs kill -9 "
alias n="nvim"
alias p="python3.14"
alias nz="nvim ~/.zshrc"
alias sz="exec zsh"
alias b="bat --theme=Dracula"
alias pi="pip3 install"
alias bi="brew install"
alias ls="eza --icons"
alias tpr="telepresence"
alias cd3="cd ../../.."
alias cd3="cd ../../../.."
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
alias nn="nvim ~/.config/nvim"

# opencode
export PATH=/Users/yea8er/.opencode/bin:$PATH

### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# Plugins with Turbo mode (async loading)
zinit ice wait lucid atload'bindkey "^ " autosuggest-accept'
zinit light zsh-users/zsh-autosuggestions

zinit ice wait lucid
zinit light zsh-users/zsh-syntax-highlighting

### End of Zinit's installer chunk
