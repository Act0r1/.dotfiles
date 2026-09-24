yay() {
    local blacklist="/etc/pacman.d/package-blacklist.txt"
    if [[ -r "$blacklist" ]]; then
        local hits=()
        local arg
        for arg in "$@"; do
            [[ "$arg" == -* ]] && continue
            if grep -qFx -- "$arg" "$blacklist"; then
                hits+=("$arg")
            fi
        done
        if (( ${#hits[@]} > 0 )); then
            print -u2 "==> ОТКЛОНЕНО (blacklist):"
            printf '      - %s\n' "${hits[@]}" >&2
            print -u2 "==> Список: $blacklist"
            return 1
        fi
    fi
    command yay "$@"
}
