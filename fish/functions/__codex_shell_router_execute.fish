function __codex_shell_router_execute --description 'Route prose-like missing commands to Codex'
    set -l line (commandline --current-buffer)

    if __codex_shell_router_should_route "$line"
        set -l prompt (string trim -- "$line")
        set -l command_prefix (__codex_shell_router_command_prefix)

        if set -q codex_shell_router_command
            set command_prefix "$codex_shell_router_command"
        end

        commandline --replace -- "$command_prefix "(string escape -- "$prompt")
        commandline --function execute
        return
    end

    commandline --function execute
end

function __codex_shell_router_command_prefix --description 'Print the configured CC command prefix'
    set -l agent codex

    if set -q CC_SHELL_ROUTER_AGENT
        set agent (string lower -- "$CC_SHELL_ROUTER_AGENT")
    end

    if set -q codex_shell_router_agent
        set agent (string lower -- "$codex_shell_router_agent")
    end

    switch "$agent"
        case claude
            echo 'claude --dangerously-skip-permissions'
        case pi
            echo 'pi'
        case codex '*'
            echo 'codex --yolo'
    end
end
