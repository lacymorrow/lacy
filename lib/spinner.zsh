#!/usr/bin/env zsh

# Spinner with shimmer text effect for Lacy Shell
# Displays a braille spinner + "Thinking" with a sweeping brightness pulse

LACY_SPINNER_PID=""

lacy_start_spinner() {
    # Guard against double-start
    if [[ -n "$LACY_SPINNER_PID" ]]; then
        lacy_stop_spinner
    fi

    # Suppress job control messages
    set +m

    {
        trap 'printf "\e[2K\r\e[?25h"' EXIT
        trap 'exit 0' TERM INT HUP

        # Hide cursor
        printf '\e[?25l'

        local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        local text='Thinking'
        local text_len=${#text}
        local frame_num=0
        local -a shimmer_colors=(255 219 213 200 141)
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
            printf "\e[2K\r \e[38;5;200m%s\e[0m %b\e[38;5;238m%s\e[0m" \
                "$spinner_char" "$shimmer" "$dots"

            frame_num=$(( frame_num + 1 ))

            # ~12.5fps using zsh builtin read timeout
            read -t 0.08 -r 2>/dev/null || true
        done
    } &

    LACY_SPINNER_PID=$!
}

lacy_stop_spinner() {
    if [[ -z "$LACY_SPINNER_PID" ]]; then
        return
    fi

    # Kill if still running
    if kill -0 "$LACY_SPINNER_PID" 2>/dev/null; then
        kill "$LACY_SPINNER_PID" 2>/dev/null
        wait "$LACY_SPINNER_PID" 2>/dev/null
    fi

    # Clean up terminal
    printf '\e[2K\r'
    printf '\e[?25h'

    LACY_SPINNER_PID=""
}
