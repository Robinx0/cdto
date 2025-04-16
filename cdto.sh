#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

FD_CMD=$(command -v fd || command -v fdfind || true)
FIND_CMD=$(command -v find)
FZF_CMD=$(command -v fzf || true)

GREEN='\033[0;32m'
RESET='\033[0m'

SHELL_PATH="${SHELL:-/bin/bash}"

ask_confirm() {
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

search_root_fallback() {
  local mode=$1
  local term=$2

  if [[ -n "$FD_CMD" ]]; then
    if [[ "$mode" == "file" ]]; then
      sudo "$FD_CMD" --type file -i -- "$term" /
    else
      sudo "$FD_CMD" --type directory -i -- "$term" /
    fi
  else
    if [[ "$mode" == "file" ]]; then
      sudo "$FIND_CMD" / -type f -iname "*$term*" 2>/dev/null
    else
      sudo "$FIND_CMD" / -type d -iname "*$term*" 2>/dev/null
    fi
  fi
}

if [[ "${1:-}" == "file" ]]; then
  [[ $# -eq 2 ]] || { echo "Usage: cdto file <name>"; exit 1; }

  query=$2
  results=()

  if [[ -n "$FD_CMD" ]]; then
    mapfile -t results < <("$FD_CMD" --type file -i -- "$query" "$HOME")
  else
    mapfile -t results < <("$FIND_CMD" "$HOME" -type f -iname "*$query*" 2>/dev/null)
  fi

  results+=("[Search entire filesystem]")

  if [[ -n "$FZF_CMD" ]]; then
    selected=$(printf "%s\n" "${results[@]}" | "$FZF_CMD" --prompt="Select file> " --height=15 --reverse)
    [[ -z "$selected" ]] && exit 0

    if [[ "$selected" == "[Search entire filesystem]" ]]; then
      mapfile -t results < <(search_root_fallback "file" "$query" || true)
      [[ ${#results[@]} -eq 0 ]] && { echo "No files found."; exit 1; }

      selected=$(printf "%s\n" "${results[@]}" | "$FZF_CMD" --prompt="Select file> " --height=15 --reverse)
      [[ -z "$selected" ]] && exit 0
    fi

    dir="${selected%/*}"
    name="${selected##*/}"
    echo -e "${dir}/${GREEN}${name}${RESET}"
    exit 0
  fi

  for file in "${results[@]}"; do
    [[ "$file" == "[Search entire filesystem]" ]] && continue
    dir="${file%/*}"
    name="${file##*/}"
    echo -e "${dir}/${GREEN}${name}${RESET}"
  done

  exit 0
fi

declare -A BASE_MAP=()
for d in "$HOME"/*/; do
  [[ -d "$d" ]] || continue
  key=$(basename "$d" | tr '[:upper:]' '[:lower:]')
  BASE_MAP["$key"]="$d"
done

if [[ $# -eq 2 ]]; then
  base=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  query=$2
  root="${BASE_MAP[$base]:-}"
  [[ -z "$root" || ! -d "$root" ]] && { echo "Unknown base: $1"; exit 1; }
  depth_flag="-maxdepth 4"
elif [[ $# -eq 1 ]]; then
  query=$1
  root="$HOME"
  depth_flag=""
else
  echo "Usage: cdto <base> <target> | cdto <target> | cdto file <name>"
  exit 1
fi

results=()

if [[ -n "$FD_CMD" ]]; then
  mapfile -t results < <("$FD_CMD" --type directory -i -d 4 -- "$query" "$root")
else
  mapfile -t results < <("$FIND_CMD" "$root" $depth_flag -type d -iname "*$query*" 2>/dev/null)
fi

results+=("[Search entire filesystem]")

if [[ -n "$FZF_CMD" ]]; then
  selected=$(printf "%s\n" "${results[@]}" | "$FZF_CMD" --prompt="Select directory> " --height=15 --reverse)
  [[ -z "$selected" ]] && exit 0

  if [[ "$selected" == "[Search entire filesystem]" ]]; then
    mapfile -t results < <(search_root_fallback "directory" "$query" || true)
    [[ ${#results[@]} -eq 0 ]] && { echo "No directories found."; exit 1; }

    selected=$(printf "%s\n" "${results[@]}" | "$FZF_CMD" --prompt="Select directory> " --height=15 --reverse)
    [[ -z "$selected" ]] && exit 0
  fi

  cd "$selected" && exec "$SHELL_PATH"
else
  for d in "${results[@]}"; do
    [[ "$d" == "[Search entire filesystem]" ]] && continue
    echo "$d"
  done
fi
