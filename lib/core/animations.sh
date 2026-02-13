#!/usr/bin/env bash

# Braille Loading Animations for Lacy Shell
# 15 Unicode Braille animations for the agent spinner
# ALL frames are exactly 5 braille characters wide (pad with ⠀ U+2800)
# to prevent horizontal shifting when switching animations
#
# Braille dot layout:
#   1 4
#   2 5
#   3 6
#   7 8

# Available animation names
LACY_SPINNER_ANIMATIONS=(
    "braille" "orbit" "breathe" "snake" "fill_sweep"
    "pulse" "columns" "checkerboard" "scan" "rain"
    "cascade" "sparkle" "wave_rows" "helix" "diagonal_swipe"
)

# Set the active spinner animation frames
# Usage: lacy_set_spinner_animation "name"
# Sets LACY_SPINNER_ANIM array
lacy_set_spinner_animation() {
    local name="${1:-braille}"

    # "random" picks a random animation each time
    if [[ "$name" == "random" ]]; then
        local count=${#LACY_SPINNER_ANIMATIONS[@]}
        local arr_off=${_LACY_ARR_OFFSET:-0}
        if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
            name="${LACY_SPINNER_ANIMATIONS[$(( (RANDOM % count) + 1 ))]}"
        else
            name="${LACY_SPINNER_ANIMATIONS[$(( RANDOM % count ))]}"
        fi
    fi

    case "$name" in
        braille)
            # Classic rotating dots (1 cell + 4 padding)
            LACY_SPINNER_ANIM=("⠋⠀⠀⠀⠀" "⠙⠀⠀⠀⠀" "⠹⠀⠀⠀⠀" "⠸⠀⠀⠀⠀" "⠼⠀⠀⠀⠀" "⠴⠀⠀⠀⠀" "⠦⠀⠀⠀⠀" "⠧⠀⠀⠀⠀" "⠇⠀⠀⠀⠀" "⠏⠀⠀⠀⠀")
            ;;
        orbit)
            # Single dot circling clockwise (1 cell + 4 padding)
            LACY_SPINNER_ANIM=("⠁⠀⠀⠀⠀" "⠈⠀⠀⠀⠀" "⠐⠀⠀⠀⠀" "⠠⠀⠀⠀⠀" "⢀⠀⠀⠀⠀" "⡀⠀⠀⠀⠀" "⠄⠀⠀⠀⠀" "⠂⠀⠀⠀⠀")
            ;;
        breathe)
            # Expand from center, contract back (1 cell + 4 padding)
            LACY_SPINNER_ANIM=("⠀⠀⠀⠀⠀" "⠁⠀⠀⠀⠀" "⠉⠀⠀⠀⠀" "⠛⠀⠀⠀⠀" "⣛⠀⠀⠀⠀" "⣿⠀⠀⠀⠀" "⣛⠀⠀⠀⠀" "⠛⠀⠀⠀⠀" "⠉⠀⠀⠀⠀" "⠁⠀⠀⠀⠀")
            ;;
        snake)
            # Diagonal wave across 3 cells (3 cells + 2 padding)
            LACY_SPINNER_ANIM=("⠁⠂⠄⠀⠀" "⠂⠄⡀⠀⠀" "⠄⡀⢀⠀⠀" "⡀⢀⠠⠀⠀" "⢀⠠⠐⠀⠀" "⠠⠐⠈⠀⠀" "⠐⠈⠁⠀⠀" "⠈⠁⠂⠀⠀")
            ;;
        fill_sweep)
            # Fill rows left-to-right, clear left-to-right (2 cells + 3 padding)
            LACY_SPINNER_ANIM=(
                "⠀⠀⠀⠀⠀" "⠉⠀⠀⠀⠀" "⠛⠀⠀⠀⠀" "⠿⠀⠀⠀⠀" "⣿⠀⠀⠀⠀" "⣿⠉⠀⠀⠀" "⣿⠛⠀⠀⠀" "⣿⠿⠀⠀⠀"
                "⣿⣿⠀⠀⠀" "⣶⣿⠀⠀⠀" "⣤⣿⠀⠀⠀" "⣀⣿⠀⠀⠀" "⠀⣿⠀⠀⠀" "⠀⣶⠀⠀⠀" "⠀⣤⠀⠀⠀" "⠀⣀⠀⠀⠀"
            )
            ;;
        pulse)
            # Two cells pulsing in antiphase (2 cells + 3 padding)
            LACY_SPINNER_ANIM=("⣿⠀⠀⠀⠀" "⠛⠁⠀⠀⠀" "⠉⠉⠀⠀⠀" "⠁⠛⠀⠀⠀" "⠀⣿⠀⠀⠀" "⠁⠛⠀⠀⠀" "⠉⠉⠀⠀⠀" "⠛⠁⠀⠀⠀")
            ;;
        columns)
            # Vertical bars appearing one at a time (3 cells + 2 padding)
            LACY_SPINNER_ANIM=("⠀⠀⠀⠀⠀" "⡇⠀⠀⠀⠀" "⡇⡇⠀⠀⠀" "⡇⡇⡇⠀⠀" "⠀⡇⡇⠀⠀" "⠀⠀⡇⠀⠀")
            ;;
        checkerboard)
            # Alternating dot patterns (3 cells + 2 padding)
            LACY_SPINNER_ANIM=("⢕⡪⢕⠀⠀" "⣿⣿⣿⠀⠀" "⡪⢕⡪⠀⠀" "⣿⣿⣿⠀⠀")
            ;;
        scan)
            # Lit column scanning back and forth (3 cells + 2 padding)
            LACY_SPINNER_ANIM=("⡇⠀⠀⠀⠀" "⠀⡇⠀⠀⠀" "⠀⠀⡇⠀⠀" "⠀⡇⠀⠀⠀")
            ;;
        rain)
            # Dots falling at staggered heights (4 cells + 1 padding)
            LACY_SPINNER_ANIM=("⠁⠐⠄⢀⠀" "⠂⠠⡀⠈⠀" "⠄⢀⠁⠐⠀" "⡀⠈⠂⠠⠀")
            ;;
        cascade)
            # Waterfall filling and draining columns (2 cells + 3 padding)
            LACY_SPINNER_ANIM=(
                "⠀⠀⠀⠀⠀" "⠁⠀⠀⠀⠀" "⠃⠀⠀⠀⠀" "⠇⠀⠀⠀⠀" "⡇⠁⠀⠀⠀" "⡇⠃⠀⠀⠀" "⡇⠇⠀⠀⠀"
                "⡇⡇⠀⠀⠀" "⠆⡇⠀⠀⠀" "⠄⡇⠀⠀⠀" "⠀⡇⠀⠀⠀" "⠀⠆⠀⠀⠀" "⠀⠄⠀⠀⠀"
            )
            ;;
        sparkle)
            # Pseudo-random twinkling dots (3 cells + 2 padding)
            LACY_SPINNER_ANIM=("⠐⡀⠂⠀⠀" "⢁⠠⠈⠀⠀" "⠀⢄⡁⠀⠀" "⠈⠂⠐⠀⠀" "⡀⠁⠄⠀⠀" "⠂⡈⠐⠀⠀" "⢈⠐⡂⠀⠀" "⠄⢂⠁⠀⠀")
            ;;
        wave_rows)
            # Traveling sine wave across 5 cells
            LACY_SPINNER_ANIM=("⠁⠂⠄⡀⠄" "⠂⠄⡀⠄⠂" "⠄⡀⠄⠂⠁" "⡀⠄⠂⠁⠂" "⠄⠂⠁⠂⠄" "⠂⠁⠂⠄⡀")
            ;;
        helix)
            # Double helix — two strands crossing
            LACY_SPINNER_ANIM=("⢁⠢⠔⡈⠔" "⠢⠔⡈⠔⠢" "⠔⡈⠔⠢⢁" "⡈⠔⠢⢁⠢" "⠔⠢⢁⠢⠔" "⠢⢁⠢⠔⡈")
            ;;
        diagonal_swipe)
            # Diagonal fill and clear (2 cells + 3 padding)
            LACY_SPINNER_ANIM=("⠀⠀⠀⠀⠀" "⠉⠀⠀⠀⠀" "⠛⠉⠀⠀⠀" "⠿⠛⠀⠀⠀" "⣿⠿⠀⠀⠀" "⣿⣿⠀⠀⠀" "⣶⣿⠀⠀⠀" "⣤⣶⠀⠀⠀" "⣀⣤⠀⠀⠀" "⠀⣀⠀⠀⠀")
            ;;
        *)
            # Unknown — fall back to braille
            LACY_SPINNER_ANIM=("⠋⠀⠀⠀⠀" "⠙⠀⠀⠀⠀" "⠹⠀⠀⠀⠀" "⠸⠀⠀⠀⠀" "⠼⠀⠀⠀⠀" "⠴⠀⠀⠀⠀" "⠦⠀⠀⠀⠀" "⠧⠀⠀⠀⠀" "⠇⠀⠀⠀⠀" "⠏⠀⠀⠀⠀")
            ;;
    esac
}

# List available animations
lacy_list_spinner_animations() {
    local current="${LACY_SPINNER_STYLE:-braille}"
    local name
    for name in "${LACY_SPINNER_ANIMATIONS[@]}"; do
        if [[ "$name" == "$current" ]]; then
            lacy_print_color "$LACY_COLOR_AGENT" "  ● $name (active)"
        else
            lacy_print_color "$LACY_COLOR_NEUTRAL" "  ○ $name"
        fi
    done
    if [[ "$current" == "random" ]]; then
        lacy_print_color "$LACY_COLOR_AGENT" "  ● random (active)"
    else
        lacy_print_color "$LACY_COLOR_NEUTRAL" "  ○ random"
    fi
}
