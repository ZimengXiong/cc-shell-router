if status is-interactive
    if not set -q codex_shell_router_enable
        set -g codex_shell_router_enable 1
    end

    if test "$codex_shell_router_enable" != 0
        bind --user --mode default enter __codex_shell_router_execute
        bind --user --mode insert enter __codex_shell_router_execute 2>/dev/null
    end
end
