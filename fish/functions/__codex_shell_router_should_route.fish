function __codex_shell_router_should_route --argument-names line --description 'Return true if a line should start Codex'
    set -l trimmed (string trim -- "$line")

    test -n "$trimmed"; or return 1

    set -l min_words 3
    set -l min_chars 18
    set -l min_alpha_words 3

    string match --quiet --regex '\n' -- "$trimmed"; and return 1
    string match --quiet --regex '^[[:space:]]*[\./~\$!#-]' -- "$trimmed"; and return 1
    string match --quiet --regex '(\|\||&&|`)' -- "$trimmed"; and return 1
    string match --quiet --regex '(^|[[:space:]])[|<>&;]([[:space:]]|$)' -- "$trimmed"; and return 1

    set -l normalized (string replace --all --regex '[[:space:]]+' ' ' -- "$trimmed")
    set -l words (string split --no-empty ' ' -- "$normalized")
    set -l first $words[1]

    test -n "$first"; or return 1

    string match --quiet --regex '[-_=:/@.]' -- "$first"; and return 1
    string match --quiet --regex '^[0-9]+$' -- "$first"; and return 1

    set -l lower_first (string lower -- "$first")
    set -l lower_second (__codex_shell_router_lower_word 2 $words)

    set -l prompt_starters please pls can could would should why how what when where fix add write update upgrade create make debug review run check explain summarize copy
    set -l command_phrase_route 1

    if type --query -- "$first"; and not contains -- "$lower_first" $prompt_starters
        if not __codex_shell_router_command_phrase_should_route $words
            return 1
        end

        set command_phrase_route 0
    end

    if test "$lower_first" = make; and not contains -- "$lower_second" me it this
        return 1
    end

    if test "$command_phrase_route" -ne 0; and not contains -- "$lower_first" $prompt_starters
        if __codex_shell_router_looks_like_command "$first"
            return 1
        end
    end

    if contains -- "$lower_first" fix add write update upgrade create debug review run check explain summarize copy
        set min_words 2
        set min_alpha_words 2
    end

    if contains -- "$lower_first" why how what when where
        set min_words 2
        set min_chars 10
        set min_alpha_words 2
    end

    set -l word_count (count $words)
    set -l char_count (string length -- "$trimmed")

    if test "$word_count" -le 4
        if not contains -- "$lower_first" $prompt_starters
            if contains -- "$lower_second" add apply build check clean clone commit create delete deploy get init install list login logout push pull remove run serve start status stop test update upgrade
                return 1
            end
        end
    end

    if test "$word_count" -lt "$min_words"; and test "$char_count" -lt "$min_chars"
        return 1
    end

    set -l alpha_words 0
    for word in $words
        if string match --quiet --regex '[[:alpha:]]' -- "$word"
            set alpha_words (math "$alpha_words + 1")
        end
    end

    test "$alpha_words" -ge "$min_alpha_words"; or return 1

    return 0
end

function __codex_shell_router_command_phrase_should_route --description 'Return true for natural-language phrases that start with a real command name'
    set -l words $argv
    set -l lower_first (__codex_shell_router_lower_word 1 $words)
    set -l lower_second (__codex_shell_router_lower_word 2 $words)
    set -l lower_third (__codex_shell_router_lower_word 3 $words)

    if test "$lower_first" = make; and test "$lower_second" = me
        return 0
    end

    if contains -- "$lower_second" it this
        return 0
    end

    if test "$lower_first" = ssh
        and contains -- "$lower_second" copy add install setup set
        and contains -- "$lower_third" id key keys ssh-key ssh-keys pubkey public-key
        return 0
    end

    return 1
end

function __codex_shell_router_lower_word --argument-names index --description 'Print a lowercased argv word by 1-based index'
    set -l word_index (math "$index + 1")
    set -q argv[$word_index]; and string lower -- "$argv[$word_index]"
end

function __codex_shell_router_looks_like_command --argument-names token --description 'Return true for common command names'
    set -l needle (string lower -- "$token")

    string match --quiet --regex '^[[:alnum:]_+-]+$' -- "$needle"; or return 1

    set -l common_commands \
        git gh ls cd pwd cp mv rm mkdir rmdir touch cat less more head tail \
        grep rg find sed awk xargs sort uniq cut tr wc chmod chown ln tar zip unzip \
        curl wget ssh scp rsync open man vim nvim emacs code nano \
        npm npx pnpm yarn bun node deno python python3 py pip pip3 pipx uv uvx \
        cargo rustc go make cmake ninja gcc g++ clang clang++ \
        docker podman kubectl helm brew asdf mise direnv \
        fish zsh bash sh source set export alias \
        jq yq sqlite3 psql mysql redis-cli \
        pytest jest vitest tsc eslint prettier ruff mypy black \
        rails rake bundle gem composer php artisan \
        terraform pulumi aws gcloud az fly vercel netlify heroku

    contains -- "$needle" $common_commands
end
