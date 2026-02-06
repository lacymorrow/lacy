#!/usr/bin/env zsh

# Spinner with shimmer text effect for Lacy Shell
# Displays a braille spinner + "Thinking" with a sweeping brightness pulse

LACY_SPINNER_PID=""
LACY_SPINNER_MONITOR_WAS_SET=""
LACY_SPINNER_NOTIFY_WAS_SET=""

lacy_start_spinner() {
    # Guard against double-start
    if [[ -n "$LACY_SPINNER_PID" ]]; then
        lacy_stop_spinner
    fi

    # Save and suppress job control messages (must persist until lacy_stop_spinner)
    if [[ -o monitor ]]; then
        LACY_SPINNER_MONITOR_WAS_SET=1
        setopt NO_MONITOR
    else
        LACY_SPINNER_MONITOR_WAS_SET=""
    fi
    # Also suppress async completion notifications
    if [[ -o notify ]]; then
        LACY_SPINNER_NOTIFY_WAS_SET=1
        setopt NO_NOTIFY
    else
        LACY_SPINNER_NOTIFY_WAS_SET=""
    fi

    {
        # Only show cursor on exit - don't clear line (caller handles that to avoid race)
        trap 'printf "\e[?25h"' EXIT
        trap 'exit 0' TERM INT HUP

        # Hide cursor
        printf '\e[?25l'

        local frames="$LACY_SPINNER_FRAMES"
        local text="$LACY_SPINNER_TEXT"
        local text_len=${#text}
        local frame_num=0
        local -a shimmer_colors=("${LACY_COLOR_SHIMMER[@]}")
        local spinner_idx spinner_char shimmer center i char dist color dots_phase dots

        while true; do
            spinner_idx=$(( (frame_num % ${#frames}) + 1 ))
            spinner_char="${frames[$spinner_idx]}"

            # Build shimmer text
            shimmer=""
            center=$(( frame_num % (text_len + 4) ))

            for (( i = 1; i <= text_len; i++ )); do
                char="${text[$i]}"
                dist=$(( center - (i - 1) ))
                if (( dist < 0 )); then
                    dist=$(( -dist ))
                fi

                if (( dist < ${#shimmer_colors} )); then
                    color=${shimmer_colors[$((dist + 1))]}
                else
                    color=${shimmer_colors[${#shimmer_colors}]}
                fi

                shimmer+="\e[38;5;${color}m${char}"
            done
            shimmer+="\e[0m"

            # Cycling dots (change every 3 frames)
            dots_phase=$(( (frame_num / 3) % 4 ))
            dots=""
            case $dots_phase in
                0) dots="" ;;
                1) dots="." ;;
                2) dots=".." ;;
                3) dots="..." ;;
            esac

            # Render: clear line, carriage return, draw
            printf "\e[2K\r \e[38;5;${LACY_COLOR_AGENT}m%s\e[0m %b\e[38;5;${LACY_COLOR_NEUTRAL}m%s\e[0m" \
                "$spinner_char" "$shimmer" "$dots"

            frame_num=$(( frame_num + 1 ))

            # ~4fps using zsh builtin read timeout
            read -t "$LACY_SPINNER_FRAME_DELAY" -r 2>/dev/null || true
        done
    } &

    LACY_SPINNER_PID=$!
}

lacy_stop_spinner() {
    # Unconditional terminal state restore — safety net even if PID is empty (e.g. Ctrl+C race)
    printf '\e[?25h'   # Cursor visible
    printf '\e[?7h'    # Line wrapping enabled (agent tools may disable it)

    if [[ -z "$LACY_SPINNER_PID" ]]; then
        # Restore job control if it was previously enabled (even if spinner already dead)
        if [[ -n "$LACY_SPINNER_MONITOR_WAS_SET" ]]; then
            setopt MONITOR
            LACY_SPINNER_MONITOR_WAS_SET=""
        fi
        if [[ -n "$LACY_SPINNER_NOTIFY_WAS_SET" ]]; then
            setopt NOTIFY
            LACY_SPINNER_NOTIFY_WAS_SET=""
        fi
        return
    fi

    # Kill if still running — only clear line if we actually kill it
    # This prevents clearing output when spinner was already killed elsewhere
    if kill -0 "$LACY_SPINNER_PID" 2>/dev/null; then
        kill "$LACY_SPINNER_PID" 2>/dev/null
        wait "$LACY_SPINNER_PID" 2>/dev/null
        # Brief delay to ensure spinner's final terminal output is flushed
        # (prevents race where spinner's \e[2K clears our output)
        sleep "$LACY_TERMINAL_FLUSH_DELAY"
        # Only clear line when we're the ones stopping the spinner
        printf '\e[2K\r'
    fi

    LACY_SPINNER_PID=""

    # Restore job control if it was previously enabled
    if [[ -n "$LACY_SPINNER_MONITOR_WAS_SET" ]]; then
        setopt MONITOR
        LACY_SPINNER_MONITOR_WAS_SET=""
    fi
    if [[ -n "$LACY_SPINNER_NOTIFY_WAS_SET" ]]; then
        setopt NOTIFY
        LACY_SPINNER_NOTIFY_WAS_SET=""
    fi
}
