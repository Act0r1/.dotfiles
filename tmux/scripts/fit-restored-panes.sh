#!/usr/bin/env bash
set -euo pipefail

tmux list-panes -a -F '#{window_id} #{window_panes} #{window_zoomed_flag} #{pane_width} #{pane_height} #{window_width} #{window_height} #{pane-border-status}' |
    while read -r window panes zoomed pane_width pane_height window_width window_height border_status; do
        if [[ "$panes" == 1 && "$zoomed" == 0 && "$border_status" == off ]] &&
            (( pane_width != window_width || pane_height != window_height )); then
            (
                policy=$(tmux show-options -wqv -t "$window" window-size)
                restore_policy() {
                    if [[ -n "$policy" ]]; then
                        tmux set-option -w -t "$window" window-size "$policy"
                    else
                        tmux set-option -wu -t "$window" window-size
                    fi
                }
                trap restore_policy EXIT
                tmux resize-window -t "$window" -y "$((window_height + 1))"
                tmux resize-window -t "$window" -x "$window_width" -y "$window_height"
            )
        fi
    done
