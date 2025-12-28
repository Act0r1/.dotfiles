function tmux-session-switch
    # Get list of tmux sessions, excluding current one if inside tmux
    set sessions (tmux list-sessions -F "#{session_name}" 2>/dev/null)

    if test -z "$sessions"
        echo "No tmux sessions found"
        return 1
    end

    # Use fzf to select a session
    set selected (echo $sessions | tr ' ' '\n' | fzf --reverse --prompt="Select tmux session: ")

    if test -n "$selected"
        # Check if we're already in a tmux session
        if set -q TMUX
            # Switch to the selected session
            tmux switch-client -t $selected
        else
            # Attach to the selected session
            tmux attach-session -t $selected
        end
    end
end
