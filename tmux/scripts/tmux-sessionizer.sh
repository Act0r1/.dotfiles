#!/bin/bash

set -u

PROJECT_ROOTS=(
    "Personal:$HOME/Personal"
    "Developer:$HOME/Developer"
)

notify() {
    local message=$1

    if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
        tmux display-message "$message"
    else
        printf '%s\n' "$message" >&2
    fi
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        notify "Missing dependency: $1"
        exit 1
    fi
}

trim() {
    local value=$1

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s\n' "$value"
}

is_safe_relative_path() {
    local path=$1
    local part

    [ -n "$path" ] || return 1
    [[ "$path" != /* ]] || return 1

    IFS='/' read -r -a parts <<< "$path"

    for part in "${parts[@]}"; do
        [ -n "$part" ] || return 1
        [ "$part" != "." ] || return 1
        [ "$part" != ".." ] || return 1
    done
}

list_dirs() {
    zoxide query -ls 2>/dev/null | awk '
        {
            score = $1
            $1 = ""
            sub(/^ /, "")
            printf "%-8s\t%s\n", score, $0
        }
    '
}

choose_project() {
    list_dirs | fzf --reverse \
        --prompt="Project: " \
        --delimiter=$'\t' \
        --with-nth=2 \
        --expect='ctrl-]' \
        --header="enter: открыть | ctrl-]: создать | ctrl-x: удалить | ctrl-b: boost score" \
        --bind "ctrl-x:execute-silent(zoxide remove {2})+reload(bash -c list_dirs)" \
        --bind "ctrl-b:execute-silent(zoxide add {2})+reload(bash -c list_dirs)"
}

choose_root() {
    local option

    for option in "${PROJECT_ROOTS[@]}"; do
        printf '%s\t%s\n' "${option%%:*}" "${option#*:}"
    done | fzf --reverse \
        --prompt="Root: " \
        --delimiter=$'\t' \
        --with-nth=1 \
        --header="Выбери корневую папку для нового проекта"
}

session_name_for_path() {
    local path=$1
    local session_name
    local existing_path
    local checksum

    session_name=$(basename -- "$path")
    session_name=$(printf '%s\n' "$session_name" | sed 's#[^[:alnum:]_-]#_#g')
    session_name=${session_name:-home}

    if tmux has-session -t="$session_name" 2>/dev/null; then
        existing_path=$(tmux show-option -t "$session_name" -qv @session-path 2>/dev/null || true)

        if [ -n "$existing_path" ] && [ "$existing_path" != "$path" ]; then
            checksum=$(printf '%s' "$path" | cksum | awk '{print $1}')
            session_name="${session_name}_${checksum}"
        fi
    fi

    printf '%s\n' "$session_name"
}

open_session() {
    local selected=$1
    local session_name

    session_name=$(session_name_for_path "$selected")

    if ! tmux has-session -t="$session_name" 2>/dev/null; then
        tmux new-session -d -s "$session_name" -c "$selected"
        tmux set-option -t "$session_name" @session-path "$selected" >/dev/null
    fi

    if [ -n "${TMUX:-}" ]; then
        tmux switch-client -t "$session_name"
    else
        exec tmux attach-session -t "$session_name"
    fi
}

create_project_dir() {
    local root_line
    local root_name
    local root_path
    local project_input
    local target_path

    root_line=$(choose_root) || exit 0
    root_name=${root_line%%$'\t'*}
    root_path=${root_line#*$'\t'}

    printf 'New path in %s: ' "$root_name" >&2
    IFS= read -r project_input || exit 0

    project_input=$(trim "$project_input")

    if ! is_safe_relative_path "$project_input"; then
        notify "Use a relative path without empty, '.' or '..' segments"
        exit 1
    fi

    target_path="$root_path/$project_input"

    mkdir -p "$target_path"
    zoxide add "$target_path" >/dev/null 2>&1 || true

    printf '%s\n' "$target_path"
}

main() {
    local picker_output
    local key
    local selected_line
    local selected

    require_command fzf
    require_command tmux
    require_command zoxide

    export -f list_dirs

    picker_output=$(choose_project) || exit 0

    key=$(printf '%s\n' "$picker_output" | sed -n '1p')
    selected_line=$(printf '%s\n' "$picker_output" | sed -n '2p')

    if [ "$key" = "ctrl-]" ]; then
        selected=$(create_project_dir)
    else
        selected=$(printf '%s\n' "$selected_line" | cut -f2-)
    fi

    [ -n "$selected" ] || exit 0

    open_session "$selected"
}

main "$@"
