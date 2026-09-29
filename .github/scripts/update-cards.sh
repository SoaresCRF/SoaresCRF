#!/usr/bin/env bash
# Updates the README cards in assets/. Each card is independent: a failed or
# invalid card keeps the previous file, so the README never shows an error banner.
set -uo pipefail

ASSETS_DIR="assets"
TIMEOUT_SECONDS=30
# Error cards from these services are still valid SVGs served with HTTP 200,
# so the body has to be checked too.
ERROR_PATTERN='something went wrong|rate limit|could not|error'
# Cards rendered earlier in the workflow by the official github-readme-stats action.
GENERATED_DIR="${GENERATED_DIR:-generated}"
GENERATED_CARDS=(stats top-langs)

declare -A CARDS=(
  [streak]="https://streak-stats.demolab.com/?user=SoaresCRF&theme=radical&hide_border=true&background=transparent&stroke=transparent&cache_seconds=86400"
  [trophy]="https://trophy.ryglcloud.net/?username=SoaresCRF&theme=radical&no-frame=true&no-bg=true&margin-w=4&cache_seconds=86400"
)

mkdir -p "$ASSETS_DIR"
tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT
failed=0

# Copies $2 over assets/$1.svg only if it is a real SVG and not an error card.
install_card() {
  local name="$1" source="$2" target="$ASSETS_DIR/$1.svg"

  if ! grep -q '<svg' "$source"; then
    echo "::warning::$name: response is not an SVG, keeping previous $target"
    failed=$((failed + 1))
    return
  fi

  if grep -qiE "$ERROR_PATTERN" "$source"; then
    echo "::warning::$name: response looks like an error card, keeping previous $target"
    failed=$((failed + 1))
    return
  fi

  cp "$source" "$target"
  echo "$name: updated $target"
}

for name in "${GENERATED_CARDS[@]}"; do
  if [ ! -s "$GENERATED_DIR/$name.svg" ]; then
    echo "::warning::$name: not generated, keeping previous $ASSETS_DIR/$name.svg"
    failed=$((failed + 1))
    continue
  fi
  install_card "$name" "$GENERATED_DIR/$name.svg"
done

for name in "${!CARDS[@]}"; do
  if ! curl --fail --silent --show-error --location --max-time "$TIMEOUT_SECONDS" \
      --output "$tmp_file" "${CARDS[$name]}"; then
    echo "::warning::$name: download failed, keeping previous $ASSETS_DIR/$name.svg"
    failed=$((failed + 1))
    continue
  fi
  install_card "$name" "$tmp_file"
done

echo "Done: $failed of $((${#GENERATED_CARDS[@]} + ${#CARDS[@]})) cards failed."
