#!/usr/bin/env bash

# Braille Loading Animations for Lacy Shell
# 18 Unicode Braille animations for the agent spinner
# Sourced from https://github.com/gunnargray-dev/unicode-animations
# ALL frames are exactly 4 braille characters wide (pad with ⠀ U+2800)
# to prevent horizontal shifting when switching animations
#
# Braille dot layout (2×4 grid per char):
#   dot1 (0x01)  dot4 (0x08)
#   dot2 (0x02)  dot5 (0x10)
#   dot3 (0x04)  dot6 (0x20)
#   dot7 (0x40)  dot8 (0x80)

# Available animation names
LACY_SPINNER_ANIMATIONS=(
    "braille" "braillewave" "dna" "scan" "rain" "scanline"
    "pulse" "snake" "sparkle" "cascade" "columns" "orbit"
    "breathe" "waverows" "checkerboard" "helix" "fillsweep" "diagswipe"
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
            # Classic rotating dots
            LACY_SPINNER_ANIM=("⠋⠀⠀⠀" "⠙⠀⠀⠀" "⠹⠀⠀⠀" "⠸⠀⠀⠀" "⠼⠀⠀⠀" "⠴⠀⠀⠀"
                "⠦⠀⠀⠀" "⠧⠀⠀⠀" "⠇⠀⠀⠀" "⠏⠀⠀⠀")
            ;;
        braillewave)
            # Traveling dot wave
            LACY_SPINNER_ANIM=("⠁⠂⠄⡀" "⠂⠄⡀⢀" "⠄⡀⢀⠠" "⡀⢀⠠⠐" "⢀⠠⠐⠈" "⠠⠐⠈⠁"
                "⠐⠈⠁⠂" "⠈⠁⠂⠄")
            ;;
        dna)
            # DNA helix strand
            LACY_SPINNER_ANIM=("⠋⠉⠙⠚" "⠉⠙⠚⠒" "⠙⠚⠒⠂" "⠚⠒⠂⠂" "⠒⠂⠂⠒" "⠂⠂⠒⠲"
                "⠂⠒⠲⠴" "⠒⠲⠴⠤" "⠲⠴⠤⠄" "⠴⠤⠄⠋" "⠤⠄⠋⠉" "⠄⠋⠉⠙")
            ;;
        scan)
            # Lit column scanning across (8×4 grid)
            LACY_SPINNER_ANIM=("⠀⠀⠀⠀" "⡇⠀⠀⠀" "⣿⠀⠀⠀" "⢸⡇⠀⠀" "⠀⣿⠀⠀" "⠀⢸⡇⠀"
                "⠀⠀⣿⠀" "⠀⠀⢸⡇" "⠀⠀⠀⣿" "⠀⠀⠀⢸")
            ;;
        rain)
            # Dots falling at staggered heights (8×4 grid)
            LACY_SPINNER_ANIM=("⢁⠂⠔⠈" "⠂⠌⡠⠐" "⠄⡐⢀⠡" "⡈⠠⠀⢂" "⠐⢀⠁⠄" "⠠⠁⠊⡀"
                "⢁⠂⠔⠈" "⠂⠌⡠⠐" "⠄⡐⢀⠡" "⡈⠠⠀⢂" "⠐⢀⠁⠄" "⠠⠁⠊⡀")
            ;;
        scanline)
            # Horizontal line bouncing up and down (6×4 grid)
            LACY_SPINNER_ANIM=("⠉⠉⠉⠀" "⠓⠓⠓⠀" "⠦⠦⠦⠀" "⣄⣄⣄⠀" "⠦⠦⠦⠀" "⠓⠓⠓⠀")
            ;;
        pulse)
            # Expanding/contracting ring (6×4 grid)
            LACY_SPINNER_ANIM=("⠀⠶⠀⠀" "⠰⣿⠆⠀" "⢾⣉⡷⠀" "⣏⠀⣹⠀" "⡁⠀⢈⠀")
            ;;
        snake)
            # Snake traversing a 4×4 grid
            LACY_SPINNER_ANIM=("⣁⡀⠀⠀" "⣉⠀⠀⠀" "⡉⠁⠀⠀" "⠉⠉⠀⠀" "⠈⠙⠀⠀" "⠀⠛⠀⠀"
                "⠐⠚⠀⠀" "⠒⠒⠀⠀" "⠖⠂⠀⠀" "⠶⠀⠀⠀" "⠦⠄⠀⠀" "⠤⠤⠀⠀"
                "⠠⢤⠀⠀" "⠀⣤⠀⠀" "⢀⣠⠀⠀" "⣀⣀⠀⠀")
            ;;
        sparkle)
            # Pseudo-random twinkling dots (8×4 grid)
            LACY_SPINNER_ANIM=("⡡⠊⢔⠡" "⠊⡰⡡⡘" "⢔⢅⠈⢢" "⡁⢂⠆⡍" "⢔⠨⢑⢐" "⠨⡑⡠⠊")
            ;;
        cascade)
            # Diagonal wave sweeping across (8×4 grid)
            LACY_SPINNER_ANIM=("⠀⠀⠀⠀" "⠀⠀⠀⠀" "⠁⠀⠀⠀" "⠋⠀⠀⠀" "⠞⠁⠀⠀" "⡴⠋⠀⠀"
                "⣠⠞⠁⠀" "⢀⡴⠋⠀" "⠀⣠⠞⠁" "⠀⢀⡴⠋" "⠀⠀⣠⠞" "⠀⠀⢀⡴"
                "⠀⠀⠀⣠" "⠀⠀⠀⢀")
            ;;
        columns)
            # Columns filling left to right (6×4 grid)
            LACY_SPINNER_ANIM=("⡀⠀⠀⠀" "⡄⠀⠀⠀" "⡆⠀⠀⠀" "⡇⠀⠀⠀" "⣇⠀⠀⠀" "⣧⠀⠀⠀"
                "⣷⠀⠀⠀" "⣿⠀⠀⠀" "⣿⡀⠀⠀" "⣿⡄⠀⠀" "⣿⡆⠀⠀" "⣿⡇⠀⠀"
                "⣿⣇⠀⠀" "⣿⣧⠀⠀" "⣿⣷⠀⠀" "⣿⣿⠀⠀" "⣿⣿⡀⠀" "⣿⣿⡄⠀"
                "⣿⣿⡆⠀" "⣿⣿⡇⠀" "⣿⣿⣇⠀" "⣿⣿⣧⠀" "⣿⣿⣷⠀" "⣿⣿⣿⠀"
                "⣿⣿⣿⠀" "⠀⠀⠀⠀")
            ;;
        orbit)
            # Two dots circling a 2×4 cell
            LACY_SPINNER_ANIM=("⠃⠀⠀⠀" "⠉⠀⠀⠀" "⠘⠀⠀⠀" "⠰⠀⠀⠀" "⢠⠀⠀⠀" "⣀⠀⠀⠀"
                "⡄⠀⠀⠀" "⠆⠀⠀⠀")
            ;;
        breathe)
            # Dots filling and draining diagonally
            LACY_SPINNER_ANIM=("⠀⠀⠀⠀" "⠂⠀⠀⠀" "⠌⠀⠀⠀" "⡑⠀⠀⠀" "⢕⠀⠀⠀" "⢝⠀⠀⠀"
                "⣫⠀⠀⠀" "⣟⠀⠀⠀" "⣿⠀⠀⠀" "⣟⠀⠀⠀" "⣫⠀⠀⠀" "⢝⠀⠀⠀"
                "⢕⠀⠀⠀" "⡑⠀⠀⠀" "⠌⠀⠀⠀" "⠂⠀⠀⠀" "⠀⠀⠀⠀")
            ;;
        waverows)
            # Sine wave traveling across (8×4 grid)
            LACY_SPINNER_ANIM=("⠖⠉⠉⠑" "⡠⠖⠉⠉" "⣠⡠⠖⠉" "⣄⣠⡠⠖" "⠢⣄⣠⡠" "⠙⠢⣄⣠"
                "⠉⠙⠢⣄" "⠊⠉⠙⠢" "⠜⠊⠉⠙" "⡤⠜⠊⠉" "⣀⡤⠜⠊" "⢤⣀⡤⠜"
                "⠣⢤⣀⡤" "⠑⠣⢤⣀" "⠉⠑⠣⢤" "⠋⠉⠑⠣")
            ;;
        checkerboard)
            # Alternating patterns (6×4 grid)
            LACY_SPINNER_ANIM=("⢕⢕⢕⠀" "⡪⡪⡪⠀" "⢊⠔⡡⠀" "⡡⢊⠔⠀")
            ;;
        helix)
            # Double helix — two sine strands crossing (8×4 grid)
            LACY_SPINNER_ANIM=("⢌⣉⢎⣉" "⣉⡱⣉⡱" "⣉⢎⣉⢎" "⡱⣉⡱⣉" "⢎⣉⢎⣉" "⣉⡱⣉⡱"
                "⣉⢎⣉⢎" "⡱⣉⡱⣉" "⢎⣉⢎⣉" "⣉⡱⣉⡱" "⣉⢎⣉⢎" "⡱⣉⡱⣉"
                "⢎⣉⢎⣉" "⣉⡱⣉⡱" "⣉⢎⣉⢎" "⡱⣉⡱⣉")
            ;;
        fillsweep)
            # Rows filling then draining (4×4 grid)
            LACY_SPINNER_ANIM=("⣀⣀⠀⠀" "⣤⣤⠀⠀" "⣶⣶⠀⠀" "⣿⣿⠀⠀" "⣿⣿⠀⠀" "⣿⣿⠀⠀"
                "⣶⣶⠀⠀" "⣤⣤⠀⠀" "⣀⣀⠀⠀" "⠀⠀⠀⠀" "⠀⠀⠀⠀")
            ;;
        diagswipe)
            # Diagonal fill and clear (4×4 grid)
            LACY_SPINNER_ANIM=("⠁⠀⠀⠀" "⠋⠀⠀⠀" "⠟⠁⠀⠀" "⡿⠋⠀⠀" "⣿⠟⠀⠀" "⣿⡿⠀⠀"
                "⣿⣿⠀⠀" "⣿⣿⠀⠀" "⣾⣿⠀⠀" "⣴⣿⠀⠀" "⣠⣾⠀⠀" "⢀⣴⠀⠀"
                "⠀⣠⠀⠀" "⠀⢀⠀⠀" "⠀⠀⠀⠀" "⠀⠀⠀⠀")
            ;;
        *)
            # Unknown — fall back to braille
            LACY_SPINNER_ANIM=("⠋⠀⠀⠀" "⠙⠀⠀⠀" "⠹⠀⠀⠀" "⠸⠀⠀⠀" "⠼⠀⠀⠀" "⠴⠀⠀⠀"
                "⠦⠀⠀⠀" "⠧⠀⠀⠀" "⠇⠀⠀⠀" "⠏⠀⠀⠀")
            ;;
    esac
}

# Preview all animations simultaneously
# Each animation shown on its own line with its name as the shimmer label
lacy_preview_all_spinners() {
    local duration="${1:-4}"
    local delay="${LACY_SPINNER_FRAME_DELAY:-0.05}"
    local num_anims=${#LACY_SPINNER_ANIMATIONS[@]}
    local arr_off=${_LACY_ARR_OFFSET:-0}

    # Shimmer colors — ZSH doesn't word-split $var, use ${=var}
    local -a shimmer_colors
    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        shimmer_colors=("${LACY_COLOR_SHIMMER[@]}")
    else
        shimmer_colors=("${LACY_COLOR_SHIMMER[@]}")
    fi
    local num_colors=${#shimmer_colors[@]}

    # Declare ALL loop variables here — ZSH's local/typeset prints values
    # when re-declared inside a loop, causing garbage output
    local _n _a _name _nf _fidx _spinner _text_len _shimmer _center
    local _i _char _dist _cidx _color _dots_phase _dots
    local _loop_start _loop_end
    local frame_num=0
    local start=$SECONDS

    # Hide cursor
    printf '\e[?25l'

    # Print initial blank lines
    for ((_n = 0; _n < num_anims; _n++)); do
        printf '\n'
    done

    if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
        _loop_start=1; _loop_end=$num_anims
    else
        _loop_start=0; _loop_end=$((num_anims - 1))
    fi

    while (( SECONDS - start < duration )); do
        # Move cursor up to first line
        printf '\e[%dA' "$num_anims"

        for ((_a = _loop_start; _a <= _loop_end; _a++)); do
            _name="${LACY_SPINNER_ANIMATIONS[$_a]}"

            # Load this animation's frames
            lacy_set_spinner_animation "$_name"
            _nf=${#LACY_SPINNER_ANIM[@]}

            if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
                _fidx=$(( (frame_num % _nf) + 1 ))
            else
                _fidx=$(( frame_num % _nf ))
            fi
            _spinner="${LACY_SPINNER_ANIM[$_fidx]}"

            # Build shimmer text for the animation name
            _text_len=${#_name}
            _shimmer=""
            _center=$(( frame_num % (_text_len + 4) ))

            for ((_i = 0; _i < _text_len; _i++)); do
                if [[ "$LACY_SHELL_TYPE" == "zsh" ]]; then
                    _char="${_name[$((_i + 1))]}"
                else
                    _char="${_name:$_i:1}"
                fi
                _dist=$(( _center - _i ))
                (( _dist < 0 )) && _dist=$(( -_dist ))

                if (( _dist < num_colors )); then
                    _cidx=$(( _dist + arr_off ))
                else
                    _cidx=$(( num_colors - 1 + arr_off ))
                fi
                _color=${shimmer_colors[$_cidx]}
                _shimmer+="\e[38;5;${_color}m${_char}"
            done
            _shimmer+="\e[0m"

            # Cycling dots
            _dots_phase=$(( (frame_num / 3) % 4 ))
            _dots=""
            case $_dots_phase in
                1) _dots="." ;; 2) _dots=".." ;; 3) _dots="..." ;;
            esac

            printf "\e[2K\r \e[38;5;${LACY_COLOR_AGENT}m%s\e[0m %b\e[38;5;${LACY_COLOR_NEUTRAL}m%s\e[0m\n" \
                "$_spinner" "$_shimmer" "$_dots"
        done

        frame_num=$((frame_num + 1))
        sleep "$delay"
    done

    # Show cursor
    printf '\e[?25h'

    # Restore active spinner
    lacy_set_spinner_animation "${LACY_SPINNER_STYLE:-braille}"
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
