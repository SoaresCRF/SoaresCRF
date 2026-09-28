#!/usr/bin/env bash
# Downloads the README cards into assets/. Each card is independent: a failed or
# invalid download keeps the previous file, so the README never shows an error banner.
set -uo pipefail

ASSETS_DIR="assets"
TIMEOUT_SECONDS=30
# Error cards from these services are still valid SVGs served with HTTP 200,
# so the body has to be checked too.
ERROR_PATTERN='something went wrong|rate limit|error'

declare -A CARDS=(
  [top-langs]="https://github-readme-stats-eight-theta.vercel.app/api/top-langs/?username=SoaresCRF&cache_seconds=7200&langs_count=8&layout=compact&theme=radical&hide_border=true&bg_color=00000000"
  [stats]="https://github-readme-stats-eight-theta.vercel.app/api?username=SoaresCRF&cache_seconds=7200&include_all_commits=true&layout=compact&theme=radical&hide_border=true&bg_color=00000000"
  [streak]="https://streak-stats.demolab.com/?user=SoaresCRF&theme=radical&hide_border=true&background=transparent&stroke=transparent&cache_seconds=86400"
  [trophy]="https://trophy.ryglcloud.net/?username=SoaresCRF&theme=radical&no-frame=true&no-bg=true&margin-w=4&cache_seconds=86400"
)

mkdir -p "$ASSETS_DIR"
tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT
failed=0

for name in "${!CARDS[@]}"; do
  target="$ASSETS_DIR/$name.svg"

  if ! curl --fail --silent --show-error --location --max-time "$TIMEOUT_SECONDS" \
      --output "$tmp_file" "${CARDS[$name]}"; then
    echo "::warning::$name: download failed, keeping previous $target"
    failed=$((failed + 1))
    continue
  fi

  if ! grep -q '<svg' "$tmp_file"; then
    echo "::warning::$name: response is not an SVG, keeping previous $target"
    failed=$((failed + 1))
    continue
  fi

  if grep -qiE "$ERROR_PATTERN" "$tmp_file"; then
    echo "::warning::$name: response looks like an error card, keeping previous $target"
    failed=$((failed + 1))
    continue
  fi

  cp "$tmp_file" "$target"
  echo "$name: updated $target"
done

echo "Done: $failed of ${#CARDS[@]} cards failed."
