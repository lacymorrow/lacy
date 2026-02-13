#!/usr/bin/env bash

# Spinner with shimmer text effect for Lacy Shell
# Displays a braille spinner + "Thinking" with a sweeping brightness pulse
# Shared across Bash 4+ and ZSH

LACY_SPINNER_PID=""
LACY_SPINNER_MONITOR_WAS_SET=""
LACY_SPINNER_NOTIFY_WAS_SET=""

lacy_start_spinner() {
    # Guard against double-start
    if [[ -n "$LACY_SPINNER_PID" ]]; then
        lacy_stop_spinner
    fi

    # Save and suppress job control messages (must persist until lacy_stop_spinner)
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        if [[ -o monitor ]]; then
            LACY_SPINNER_MONITOR_WAS_SET=1
            setopt NO_MONITOR
        else
            LACY_SPINNER_MONITOR_WAS_SET=""
        fi
        if [[ -o notify ]]; then
            LACY_SPINNER_NOTIFY_WAS_SET=1
            setopt NO_NOTIFY
        else
            LACY_SPINNER_NOTIFY_WAS_SET=""
        fi
    else
        # Bash
        LACY_SPINNER_MONITOR_WAS_SET=""
        case "$-" in *m*) LACY_SPINNER_MONITOR_WAS_SET=1 ;; esac
        set +m 2>/dev/null
        LACY_SPINNER_NOTIFY_WAS_SET=""
    fi

    # Initialize animation frames (global array, inherited by forked subshell)
    lacy_set_spinner_animation "${LACY_SPINNER_STYLE:-braille}"
    # Guard: if animation failed to load, use hardcoded fallback
    if [[ ${#LACY_SPINNER_ANIM[@]} -eq 0 ]]; then
        LACY_SPINNER_ANIM=("⠋⠀⠀⠀⠀" "⠙⠀⠀⠀⠀" "⠹⠀⠀⠀⠀" "⠸⠀⠀⠀⠀" "⠼⠀⠀⠀⠀" "⠴⠀⠀⠀⠀" "⠦⠀⠀⠀⠀" "⠧⠀⠀⠀⠀" "⠇⠀⠀⠀⠀" "⠏⠀⠀⠀⠀")
    fi

    {
        trap 'printf "\e[?25h"' EXIT
        trap 'exit 0' TERM INT HUP

        # Hide cursor
        printf '\e[?25l'

        local num_frames=${#LACY_SPINNER_ANIM[@]}

        local text="$LACY_SPINNER_TEXT"
        local text_len=${#text}
        local frame_num=0
        local -a shimmer_colors=("${LACY_COLOR_SHIMMER[@]}")
        local num_colors=${#shimmer_colors[@]}
        local arr_off=${_LACY_ARR_OFFSET:-0}
        local spinner_idx spinner_char shimmer center i char dist color_idx color dots_phase dots

        while true; do
            if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
                spinner_idx=$(( (frame_num % num_frames) + 1 ))
            else
                spinner_idx=$(( frame_num % num_frames ))
            fi
            spinner_char="${LACY_SPINNER_ANIM[$spinner_idx]}"

            # Build shimmer text
            shimmer=""
            center=$(( frame_num % (text_len + 4) ))

            for (( i = 0; i < text_len; i++ )); do
                if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
                    char="${text[$((i + 1))]}"
                else
                    char="${text:$i:1}"
                fi
                dist=$(( center - i ))
                if (( dist < 0 )); then
                    dist=$(( -dist ))
                fi

                if (( dist < num_colors )); then
                    color_idx=$(( dist + arr_off ))
                    color=${shimmer_colors[$color_idx]}
                else
                    color_idx=$(( num_colors - 1 + arr_off ))
                    color=${shimmer_colors[$color_idx]}
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

            sleep "$LACY_SPINNER_FRAME_DELAY"
        done
    } &

    LACY_SPINNER_PID=$!

    # In Bash, disown the spinner so it won't print "[N] Done ..." with
    # the entire subshell body when the job exits.
    if [[ "$LACY_SHELL_TYPE" != "zsh" ]]; then
        disown "$LACY_SPINNER_PID" 2>/dev/null
    fi
}

lacy_stop_spinner() {
    # Unconditional terminal state restore
    printf '\e[?25h'   # Cursor visible
    printf '\e[?7h'    # Line wrapping enabled

    if [[ -z "$LACY_SPINNER_PID" ]]; then
        _lacy_spinner_restore_jobctl
        return
    fi

    # Kill if still running
    if kill -0 "$LACY_SPINNER_PID" 2>/dev/null; then
        kill "$LACY_SPINNER_PID" 2>/dev/null
        # In ZSH we can wait; in Bash the process is disowned so just sleep
        if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
            wait "$LACY_SPINNER_PID" 2>/dev/null
        fi
        sleep "$LACY_TERMINAL_FLUSH_DELAY"
        printf '\e[2K\r'
    fi

    LACY_SPINNER_PID=""

    _lacy_spinner_restore_jobctl
}

# Restore job control after spinner
_lacy_spinner_restore_jobctl() {
    if [[ -n "$LACY_SPINNER_MONITOR_WAS_SET" ]]; then
        if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
            setopt MONITOR
        else
            set -m 2>/dev/null
        fi
        LACY_SPINNER_MONITOR_WAS_SET=""
    fi
    if [[ -n "$LACY_SPINNER_NOTIFY_WAS_SET" ]]; then
        if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
            setopt NOTIFY
        fi
        LACY_SPINNER_NOTIFY_WAS_SET=""
    fi
}
