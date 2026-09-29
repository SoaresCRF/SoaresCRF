#!/usr/bin/env bash
# Offline test for update-cards.sh: fake generated cards plus a fake curl on PATH
# give one scenario per card, and the test checks which files in assets/ were
# replaced or kept.
# Run: bash .github/scripts/test-update-cards.sh
set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/update-cards.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/assets" "$work/generated"
cat > "$work/bin/curl" <<'EOF'
#!/usr/bin/env bash
# Fake curl: writes a canned response to --output, chosen by the card URL.
while [ $# -gt 0 ]; do
  case "$1" in
    --output) out="$2"; shift 2 ;;
    --max-time) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
case "$url" in
  *streak*)
    if [ "${FAKE_STREAK:-}" = html ]; then
      echo '<html><body>Service page</body></html>' > "$out"
    else
      echo 'curl: (22) The requested URL returned error: 404' >&2; exit 22
    fi ;;
esac
EOF
chmod +x "$work/bin/curl"

for name in stats top-langs streak trophy; do
  echo "<svg>old $name</svg>" > "$work/assets/$name.svg"
done
echo '<svg>new stats</svg>' > "$work/generated/stats.svg"
echo '<svg>Something went wrong! file an issue</svg>' > "$work/generated/top-langs.svg"
echo '<svg>Could not find a user with that name.</svg>' > "$work/generated/trophy.svg"

run() {
  (cd "$work" && PATH="$work/bin:$PATH" bash "$script")
}

fail=0
check() {
  if [ "$(cat "$work/assets/$1.svg")" = "$2" ]; then
    echo "ok   $1: $3"
  else
    echo "FAIL $1: $3 (got: $(cat "$work/assets/$1.svg"))"
    fail=1
  fi
}

output=$(run)
check stats '<svg>new stats</svg>' 'valid generated card replaces the old file'
check top-langs '<svg>old top-langs</svg>' 'generated error card keeps the old file'
check trophy '<svg>old trophy</svg>' '"could not" error card keeps the old file'
check streak '<svg>old streak</svg>' 'failed download keeps the old file'

if grep -q 'Done: 3 of 4 cards failed.' <<< "$output"; then
  echo "ok   summary reports 3 failures"
else
  echo "FAIL summary line missing or wrong"
  fail=1
fi

rm "$work/generated/stats.svg"
(export FAKE_STREAK=html; run > /dev/null)
check stats '<svg>new stats</svg>' 'missing generated card keeps the current file'
check streak '<svg>old streak</svg>' 'non-SVG response keeps the old file'

exit $fail
