#!/usr/bin/env bash
# Installs the README cards rendered earlier in the workflow by the official
# github-readme-stats, github-profile-trophy and github-readme-streak-stats
# actions. Each card is independent: a missing or invalid card keeps the
# previous file, so the README never shows an error banner.
set -uo pipefail

ASSETS_DIR="assets"
GENERATED_DIR="${GENERATED_DIR:-generated}"
CARDS=(stats top-langs trophy streak)
# Error cards are still valid SVGs, so the body has to be checked too.
ERROR_PATTERN='something went wrong|rate limit|could not|error'

mkdir -p "$ASSETS_DIR"
failed=0

for name in "${CARDS[@]}"; do
  source="$GENERATED_DIR/$name.svg"
  target="$ASSETS_DIR/$name.svg"

  if [ ! -s "$source" ]; then
    echo "::warning::$name: not generated, keeping previous $target"
    failed=$((failed + 1))
    continue
  fi

  if ! grep -q '<svg' "$source"; then
    echo "::warning::$name: output is not an SVG, keeping previous $target"
    failed=$((failed + 1))
    continue
  fi

  if grep -qiE "$ERROR_PATTERN" "$source"; then
    echo "::warning::$name: output looks like an error card, keeping previous $target"
    failed=$((failed + 1))
    continue
  fi

  cp "$source" "$target"
  echo "$name: updated $target"
done

echo "Done: $failed of ${#CARDS[@]} cards failed."
