#!/bin/zsh
set -euo pipefail

ROOT="/Users/millerm/Documents/Codex/2026-04-20-do-you-have-acess-to-any"
WRAPPER="$ROOT/scripts/wrap-chat-history-batch.swift"
VALIDATOR="$ROOT/scripts/validate-chat-history-batch.swift"
CLANG_CACHE="$ROOT/.swift-cache/clang-module-cache"
SWIFTPM_CACHE="$ROOT/.swift-cache/swiftpm"

mkdir -p "$CLANG_CACHE" "$SWIFTPM_CACHE"

maybe_pause() {
  if [[ -t 0 ]]; then
    echo
    read -k 1 '?Press any key to close...'
    echo
  fi
}

if [[ $# -lt 1 ]]; then
  echo "BubblePath Chat History Wrapper"
  echo
  echo "Usage:"
  echo "  Drag one or more JSON, text, markdown, rich-text, Word, OpenDocument, HTML, PDF, or webarchive files or folders onto this command file"
  echo "  or run it in Terminal like:"
  echo "  ./Wrap\\ Chat\\ History.command path/to/file.json [another-file.json] [folder]"
  echo
  echo "Each input JSON file will produce a sibling *-wrapped.json output file and then be validated."
  echo
  maybe_pause
  exit 1
fi

echo "BubblePath Chat History Wrapper"
echo

targets=()
empty_dirs=()
wrapped_only_inputs=()
skipped_wrapped_count=0
for input_path in "$@"; do
  if [[ -d "$input_path" ]]; then
    dir_targets=()
    wrapped_matches=0
    while IFS= read -r json_file; do
      if [[ "$json_file" == *-wrapped.json ]]; then
        wrapped_matches=$((wrapped_matches + 1))
        skipped_wrapped_count=$((skipped_wrapped_count + 1))
        continue
      fi
      dir_targets+=("$json_file")
    done < <(find "$input_path" -maxdepth 1 -type f \( -iname '*.json' -o -iname '*.txt' -o -iname '*.md' -o -iname '*.markdown' -o -iname '*.rtf' -o -iname '*.doc' -o -iname '*.docx' -o -iname '*.odt' -o -iname '*.html' -o -iname '*.htm' -o -iname '*.pdf' -o -iname '*.webarchive' \) | sort)
    if [[ ${#dir_targets[@]} -eq 0 ]]; then
      if [[ $wrapped_matches -gt 0 ]]; then
        wrapped_only_inputs+=("$input_path")
      else
        empty_dirs+=("$input_path")
      fi
    else
      targets+=("${dir_targets[@]}")
    fi
  else
    if [[ "$input_path" == *-wrapped.json ]]; then
      wrapped_only_inputs+=("$input_path")
      skipped_wrapped_count=$((skipped_wrapped_count + 1))
      continue
    fi
    targets+=("$input_path")
  fi
done

if [[ ${#targets[@]} -eq 0 ]]; then
  if [[ ${#wrapped_only_inputs[@]} -gt 0 ]]; then
    echo "Only already-wrapped JSON files were found in:"
    for wrapped_input in "${wrapped_only_inputs[@]}"; do
      echo "  $wrapped_input"
    done
  elif [[ ${#empty_dirs[@]} -gt 0 ]]; then
        echo "No JSON, text, markdown, rich-text, Word, OpenDocument, HTML, PDF, or webarchive files were found in:"
    for empty_dir in "${empty_dirs[@]}"; do
      echo "  $empty_dir"
    done
  else
    echo "No JSON, text, markdown, rich-text, Word, OpenDocument, HTML, PDF, or webarchive files were found in the provided input."
  fi
  echo
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

echo "Wrapping ${#targets[@]} file(s):"
for target in "${targets[@]}"; do
  echo "  $target"
done
echo

wrapped_outputs=()

for input_path in "${targets[@]}"; do
  echo "Wrapping:"
  echo "  $input_path"
  output_path="${input_path%.*}-wrapped.json"
  CLANG_MODULE_CACHE_PATH="$CLANG_CACHE" \
  SWIFTPM_MODULECACHE_OVERRIDE="$SWIFTPM_CACHE" \
  HOME="$ROOT" \
  swift "$WRAPPER" "$input_path"
  wrapped_outputs+=("$output_path")
  echo
done

if [[ $skipped_wrapped_count -gt 0 ]]; then
  echo "Skipped $skipped_wrapped_count already-wrapped file(s)."
  echo
fi

echo "Validating wrapped output(s):"
for wrapped_output in "${wrapped_outputs[@]}"; do
  echo "  $wrapped_output"
done
echo

CLANG_MODULE_CACHE_PATH="$CLANG_CACHE" \
SWIFTPM_MODULECACHE_OVERRIDE="$SWIFTPM_CACHE" \
HOME="$ROOT" \
swift "$VALIDATOR" "${wrapped_outputs[@]}"

echo
echo "Wrapped ${#wrapped_outputs[@]} file(s) successfully."

maybe_pause
