#!/bin/zsh
set -euo pipefail

ROOT="/Users/millerm/Documents/Codex/2026-04-20-do-you-have-acess-to-any"
VALIDATOR="$ROOT/scripts/validate-chat-history-batch.swift"
MODULE_CACHE="/tmp/clang-module-cache"

mkdir -p "$MODULE_CACHE"

maybe_pause() {
  if [[ -t 0 ]]; then
    echo
    read -k 1 '?Press any key to close...'
    echo
  fi
}

if [[ $# -lt 1 ]]; then
  echo "BubblePath Chat History Validator"
  echo
  echo "Usage:"
  echo "  Drag one or more .json/.txt/.md/.markdown/.rtf/.doc/.docx/.odt/.html/.htm/.pdf/.webarchive files or folders onto this command file"
  echo "  or run it in Terminal like:"
  echo "  ./Validate\\ Chat\\ History.command path/to/chat-history.json [another-file.json] [folder]"
  echo
  maybe_pause
  exit 1
fi

targets=()
empty_dirs=()
for input_path in "$@"; do
  if [[ -d "$input_path" ]]; then
    dir_targets=()
    while IFS= read -r json_file; do
      dir_targets+=("$json_file")
    done < <(find "$input_path" -maxdepth 1 -type f \( -iname '*.json' -o -iname '*.txt' -o -iname '*.md' -o -iname '*.markdown' -o -iname '*.rtf' -o -iname '*.doc' -o -iname '*.docx' -o -iname '*.odt' -o -iname '*.html' -o -iname '*.htm' -o -iname '*.pdf' -o -iname '*.webarchive' \) | sort)
    if [[ ${#dir_targets[@]} -eq 0 ]]; then
      empty_dirs+=("$input_path")
    else
      targets+=("${dir_targets[@]}")
    fi
  else
    targets+=("$input_path")
  fi
done

if [[ ${#targets[@]} -eq 0 ]]; then
  echo "BubblePath Chat History Validator"
  echo
  if [[ ${#empty_dirs[@]} -gt 0 ]]; then
    echo "No JSON, text, markdown, rich-text, Word, OpenDocument, HTML, PDF, or webarchive files were found in:"
    for empty_dir in "${empty_dirs[@]}"; do
      echo "  $empty_dir"
    done
  else
    echo "No JSON, text, markdown, rich-text, Word, OpenDocument, HTML, PDF, or webarchive files were found in the provided input."
  fi
  maybe_pause
  exit 1
fi

typeset -A seen_targets
unique_targets=()
for target in "${targets[@]}"; do
  if [[ -z "${seen_targets[$target]-}" ]]; then
    seen_targets[$target]=1
    unique_targets+=("$target")
  fi
done
targets=("${unique_targets[@]}")

echo "BubblePath Chat History Validator"
echo
echo "Checking ${#targets[@]} file(s):"
for target in "${targets[@]}"; do
  echo "  $target"
done
echo

CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" swift "$VALIDATOR" "${targets[@]}"

maybe_pause
