# Lacy Shell — Nushell keybindings
#
# Appends Lacy keybindings to $env.config.keybindings without clobbering
# existing user bindings.
#
# Bindings:
#   Alt+Enter   — send current buffer to AI agent (_lacy_send_to_agent)
#   Ctrl+Space  — cycle modes: auto → shell → agent → auto

def --env _lacy_toggle_mode [] {
    $env.LACY_SHELL_MODE = (match $env.LACY_SHELL_MODE {
        "auto"  => "shell"
        "shell" => "agent"
        _       => "auto"
    })
    match $env.LACY_SHELL_MODE {
        "shell" => { print $"\n\e[38;5;34m  ▌ SHELL mode\e[0m" }
        "agent" => { print $"\n\e[38;5;200m  ▌ AGENT mode\e[0m" }
        _       => { print $"\n\e[38;5;75m  ▌ AUTO mode\e[0m" }
    }
}

let _lacy_bindings = [
    {
        name: lacy_send_to_agent
        modifier: alt
        keycode: enter
        mode: [emacs vi_insert vi_normal]
        event: { send: executehostcommand cmd: "_lacy_send_to_agent" }
    }
    {
        name: lacy_toggle_mode
        modifier: control
        keycode: space
        mode: [emacs vi_insert vi_normal]
        event: { send: executehostcommand cmd: "_lacy_toggle_mode" }
    }
]

# Append to existing keybindings, preserving user config.
let _existing_kb = (try { $env.config.keybindings } catch { [] })
$env.config = ($env.config | upsert keybindings ($existing_kb | append $_lacy_bindings))
