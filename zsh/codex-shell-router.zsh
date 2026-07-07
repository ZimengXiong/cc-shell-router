# codex-shell-router zsh integration

typeset -g codex_shell_router_enable="${codex_shell_router_enable:-1}"
typeset -g codex_shell_router_agent="${codex_shell_router_agent:-${CC_SHELL_ROUTER_AGENT:-codex}}"

__codex_shell_router_command_prefix() {
  if [[ -n "${codex_shell_router_command:-}" ]]; then
    printf '%s\n' "$codex_shell_router_command"
    return
  fi

  case "${codex_shell_router_agent:l}" in
    claude)
      printf '%s\n' 'claude --dangerously-skip-permissions'
      ;;
    pi)
      printf '%s\n' 'pi'
      ;;
    codex|*)
      printf '%s\n' 'codex --yolo'
      ;;
  esac
}

__codex_shell_router_contains() {
  local needle="$1"
  shift
  local item

  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done

  return 1
}

__codex_shell_router_trim() {
  local value="$1"
  value="${value#"${value%%[!$' \t\r\n']*}"}"
  value="${value%"${value##*[!$' \t\r\n']}"}"
  printf '%s\n' "$value"
}

__codex_shell_router_looks_like_command() {
  local token="$1"
  local needle="${token:l}"
  local -a common_commands

  [[ "$needle" =~ '^[[:alnum:]_+-]+$' ]] || return 1

  common_commands=(
    git gh ls cd pwd cp mv rm mkdir rmdir touch cat less more head tail
    grep rg find sed awk xargs sort uniq cut tr wc chmod chown ln tar zip unzip
    curl wget ssh scp rsync open man vim nvim emacs code nano
    npm npx pnpm yarn bun node deno python python3 py pip pip3 pipx uv uvx
    cargo rustc go make cmake ninja gcc g++ clang clang++
    docker podman kubectl helm brew asdf mise direnv
    fish zsh bash sh source set export alias
    jq yq sqlite3 psql mysql redis-cli
    pytest jest vitest tsc eslint prettier ruff mypy black
    rails rake bundle gem composer php artisan
    terraform pulumi aws gcloud az fly vercel netlify heroku
  )

  __codex_shell_router_contains "$needle" "${common_commands[@]}"
}

__codex_shell_router_command_phrase_should_route() {
  local -a words
  words=("$@")
  local lower_first="${${words[1]-}:l}"
  local lower_second="${${words[2]-}:l}"
  local lower_third="${${words[3]-}:l}"

  if [[ "$lower_first" == make && "$lower_second" == me ]]; then
    return 0
  fi

  if __codex_shell_router_contains "$lower_second" it this; then
    return 0
  fi

  if [[ "$lower_first" == ssh ]] &&
      __codex_shell_router_contains "$lower_second" copy add install setup set &&
      __codex_shell_router_contains "$lower_third" id key keys ssh-key ssh-keys pubkey public-key; then
    return 0
  fi

  return 1
}

__codex_shell_router_should_route() {
  emulate -L zsh
  setopt extendedglob

  local line="$1"
  local trimmed="$(__codex_shell_router_trim "$line")"
  local min_words=3
  local min_chars=18
  local min_alpha_words=3

  [[ -n "$trimmed" ]] || return 1
  [[ "$trimmed" != *$'\n'* ]] || return 1
  [[ ! "$trimmed" =~ '^[[:space:]]*[\./~$!#-]' ]] || return 1
  [[ ! "$trimmed" =~ '(\|\||&&|`)' ]] || return 1
  [[ ! "$trimmed" =~ '(^|[[:space:]])[|<>&;]([[:space:]]|$)' ]] || return 1

  local normalized="${trimmed//[[:space:]]##/ }"
  local -a words prompt_starters command_second_words
  words=(${=normalized})
  local first="${words[1]}"

  [[ -n "$first" ]] || return 1
  [[ ! "$first" =~ '[-_=:/@.]' ]] || return 1
  [[ ! "$first" =~ '^[0-9]+$' ]] || return 1

  local lower_first="${first:l}"
  local lower_second="${${words[2]-}:l}"
  local command_phrase_route=1

  prompt_starters=(
    please pls can could would should why how what when where fix add write
    update upgrade create make debug review run check explain summarize copy
  )

  if (( ${+commands[$first]} || ${+builtins[$first]} || ${+functions[$first]} )) &&
      ! __codex_shell_router_contains "$lower_first" "${prompt_starters[@]}"; then
    if ! __codex_shell_router_command_phrase_should_route "${words[@]}"; then
      return 1
    fi

    command_phrase_route=0
  fi

  if [[ "$lower_first" == make ]] &&
      ! __codex_shell_router_contains "$lower_second" me it this; then
    return 1
  fi

  if (( command_phrase_route != 0 )) &&
      ! __codex_shell_router_contains "$lower_first" "${prompt_starters[@]}"; then
    if __codex_shell_router_looks_like_command "$first"; then
      return 1
    fi
  fi

  if __codex_shell_router_contains "$lower_first" fix add write update upgrade create debug review run check explain summarize copy; then
    min_words=2
    min_alpha_words=2
  fi

  if __codex_shell_router_contains "$lower_first" why how what when where; then
    min_words=2
    min_chars=10
    min_alpha_words=2
  fi

  local word_count=${#words[@]}
  local char_count=${#trimmed}

  if (( word_count <= 4 )); then
    if ! __codex_shell_router_contains "$lower_first" "${prompt_starters[@]}"; then
      command_second_words=(
        add apply build check clean clone commit create delete deploy get init
        install list login logout push pull remove run serve start status stop
        test update upgrade
      )

      if __codex_shell_router_contains "$lower_second" "${command_second_words[@]}"; then
        return 1
      fi
    fi
  fi

  if (( word_count < min_words && char_count < min_chars )); then
    return 1
  fi

  local alpha_words=0 word

  for word in "${words[@]}"; do
    if [[ "$word" =~ '[[:alpha:]]' ]]; then
      (( alpha_words++ ))
    fi
  done

  (( alpha_words >= min_alpha_words )) || return 1

  return 0
}

__codex_shell_router_execute() {
  if __codex_shell_router_should_route "$BUFFER"; then
    local prompt="$(__codex_shell_router_trim "$BUFFER")"
    local command_prefix="$(__codex_shell_router_command_prefix)"

    BUFFER="$command_prefix ${(q)prompt}"
    CURSOR=${#BUFFER}
  fi

  zle accept-line
}

if [[ -o interactive && "$codex_shell_router_enable" != 0 ]]; then
  zle -N __codex_shell_router_execute
  bindkey '^M' __codex_shell_router_execute
fi
