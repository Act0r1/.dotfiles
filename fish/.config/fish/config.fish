# ===================== Homebrew (critical!) =====================
# Must be first. This ensures PATH is correct for ALL tools.
eval (/opt/homebrew/bin/brew shellenv)
fish_add_path ~/.local/bin

# ===================== Locale / Env =====================
set -gx EDITOR nvim
set -gx LANG en_US.UTF-8
set -gx NO_PROXY localhost,127.0.0.1,::1
set -gx HTTPS_PROXY http://127.0.0.1:10808
set -gx HTTP_PROXY http://127.0.0.1:10808



# ===================== Paths =====================
# Solana
fish_add_path $HOME/.local/share/solana/install/active_release/bin
fish_add_path $HOME/.foundry/bin
fish_add_path $HOME/.cargo/bin
fish_add_path $HOME/go/bin
fish_add_path $HOME/.flutter/flutter/bin



# Bun
set -gx BUN_INSTALL $HOME/.bun
fish_add_path $BUN_INSTALL/bin

# pnpm
set -gx PNPM_HOME $HOME/Library/pnpm
fish_add_path $PNPM_HOME

# opencode
fish_add_path $HOME/.opencode/bin

# ===================== Interactive Shell =====================
if status is-interactive

    # Prompt
    set -gx STARSHIP_CONFIG $HOME/.config/starship/starship.toml
    starship init fish | source

    # zoxide
    zoxide init fish | source

    # direnv
    direnv hook fish | source

    # uv
    uv generate-shell-completion fish | source

    # fzf keybindings
    # if test -f ~/.config/fish/functions/fzf_key_bindings.fish
    #     source ~/.config/fish/functions/fzf_key_bindings.fish
    #     fzf_key_bindings
    # end

    # Batman
    batman --export-env | source

    # Dracula theme
    fish_config theme choose "Dracula Official"

    # Keybinds
    bind \cN history-prefix-search-forward
    bind \cP history-prefix-search-backward

end

# ===================== Functions =====================
function field
    set sep " "
    if test (count $argv) -ge 2
        set sep $argv[2]
    end
    set num 1
    if test (count $argv) -ge 1
        set num $argv[1]
    end
    awk -F "$sep" "{print \$$num}"
end

function fzf_code_open
    set file (find . -type f | fzf --preview "bat {}")
    if test -n "$file"
        nvim "$file"
    end
end

function mi
    if test (count $argv) -eq 0
        echo "Usage: mi <directory_name>" >&2
        return 1
    else if test (count $argv) -eq 1
        mkdir -p $argv[1]; and touch $argv[1]/__init__.py
        echo "Done"
    else
        for f in $argv
            mkdir -p $f; and touch $f/__init__.py
        end
        echo "Done"
    end
end

function de
    if test -e ./.envrc
        echo "File .envrc already exists"
    else
        echo '# .envrc
if [ -d .venv ]; then
  source .venv/bin/activate
elif [ -d venv ]; then
  source venv/bin/activate
fi' > .envrc
        direnv allow .
        echo "Created and successfully ✅"
    end
end
bind ctrl-space accept-autosuggestion

# ===================== Aliases =====================
alias n="nvim"
alias p="python3.14"
alias nz="nvim ~/.config/fish/config.fish"
alias sz="exec fish"
alias b="bat --theme=Dracula"
alias pi="pip3 install"
alias bi="brew install"
alias ls="eza --icons"
alias ll="eza -lah --icons"
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
alias bws="$HOME/.config/bin/bw.sh"
alias y="yazi"
alias man="batman"
alias csh="$HOME/.config/scripts/check_hash.sh"
alias lst="lsof -i -P -n | grep LISTEN"
alias pbp="pwd | pbcopy"
alias glc="git clone"
alias nn="nvim ~/.config/nvim"

function fports
    lsof -iTCP -sTCP:LISTEN -nP 2>/dev/null \
    | awk '{print $9, $1, $2}' \
    | sed 's/.*://g' \
    | while read port cmd pid
        echo "$port  USED  $cmd  (pid:$pid)"
      end \
    | fzf --prompt="port> " --query="$argv"
end

alias pp="fports"
# ===================== Private =====================
if test -f ~/.zsh_private
    source ~/.zsh_private
end

fzf_configure_bindings --directory=\cf 

source ~/.orbstack/shell/init2.fish 2>/dev/null || :
