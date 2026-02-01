#!/bin/bash
# Изменяет базовый путь текущей tmux сессии

current_path=$(tmux show-option -qv @session-path)
[ -z "$current_path" ] && current_path=$(tmux display-message -p '#{pane_current_path}')

echo "Current: $current_path"
echo ""
read -p "New path: " new_path

# Раскрываем ~ в полный путь
new_path="${new_path/#\~/$HOME}"

if [ -n "$new_path" ] && [ -d "$new_path" ]; then
    tmux set-option @session-path "$new_path"
    tmux display-message "Session path: $new_path"
elif [ -n "$new_path" ]; then
    echo "Directory not found: $new_path"
    read -p "Press enter..."
fi
