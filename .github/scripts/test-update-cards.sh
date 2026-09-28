#!/usr/bin/env bash
# Offline test for update-cards.sh: a fake curl on PATH returns one scenario per
# card, and the test checks which files in assets/ were replaced or kept.
# Run: bash .github/scripts/test-update-cards.sh
set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/update-cards.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/assets"
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
  *top-langs*) echo '<svg>new langs</svg>' > "$out" ;;
  *api\?username*) echo '<svg>Something went wrong! file an issue</svg>' > "$out" ;;
  *streak*) echo '<svg>Could not find a user with that name.</svg>' > "$out" ;;
  *trophy*)
    if [ "${FAKE_TROPHY:-}" = html ]; then
      echo '<html><body>Service page</body></html>' > "$out"
    else
      echo 'curl: (22) The requested URL returned error: 404' >&2; exit 22
    fi ;;
esac
EOF
chmod +x "$work/bin/curl"

for name in top-langs stats streak trophy; do
  echo "<svg>old $name</svg>" > "$work/assets/$name.svg"
done

output=$(cd "$work" && PATH="$work/bin:$PATH" bash "$script")

fail=0
check() {
  if [ "$(cat "$work/assets/$1.svg")" = "$2" ]; then
    echo "ok   $1: $3"
  else
    echo "FAIL $1: $3 (got: $(cat "$work/assets/$1.svg"))"
    fail=1
  fi
}
check top-langs '<svg>new langs</svg>' 'valid SVG replaces the old file'
check stats '<svg>old stats</svg>' 'error card keeps the old file'
check streak '<svg>old streak</svg>' '"could not" error card keeps the old file'
check trophy '<svg>old trophy</svg>' 'failed download keeps the old file'

if grep -q 'Done: 3 of 4 cards failed.' <<< "$output"; then
  echo "ok   summary reports 3 failures"
else
  echo "FAIL summary line missing or wrong"
  fail=1
fi

(cd "$work" && FAKE_TROPHY=html PATH="$work/bin:$PATH" bash "$script" > /dev/null)
check trophy '<svg>old trophy</svg>' 'non-SVG response keeps the old file'

exit $fail
