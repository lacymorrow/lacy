#!/usr/bin/env bash

# Spinner animations for Lacy Shell
# Two styles: braille (default) and ascii (terminals without Unicode).
# Every frame is exactly 4 columns wide so the "Thinking" text never shifts.

LACY_SPINNER_ANIMATIONS=("braille" "ascii")

# Set LACY_SPINNER_ANIM to the frames for a style. Unknown names use braille.
# Usage: lacy_set_spinner_animation "name"
lacy_set_spinner_animation() {
    case "${1:-braille}" in
        ascii)
            LACY_SPINNER_ANIM=("|   " "/   " "-   " "\\   ")
            ;;
        *)
            LACY_SPINNER_ANIM=("⠋⠀⠀⠀" "⠙⠀⠀⠀" "⠹⠀⠀⠀" "⠸⠀⠀⠀" "⠼⠀⠀⠀" "⠴⠀⠀⠀"
                "⠦⠀⠀⠀" "⠧⠀⠀⠀" "⠇⠀⠀⠀" "⠏⠀⠀⠀")
            ;;
    esac
}
