#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CWN_DATA="$ROOT/cwn-data"
JA_DIR="$ROOT/ja"
TRANSLATE="node --experimental-strip-types $ROOT/scripts/translate.ts"

# Parse arguments
FILE=""
SINCE=""
FROM_REF=""
TO_REF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)    FILE="$2";     shift 2 ;;
    --since)   SINCE="$2";    shift 2 ;;
    --from-ref) FROM_REF="$2"; shift 2 ;;
    --to-ref)  TO_REF="$2";   shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if { [[ -n "$FROM_REF" ]] && [[ -z "$TO_REF" ]]; } || \
   { [[ -z "$FROM_REF" ]] && [[ -n "$TO_REF" ]]; }; then
  echo "--from-ref and --to-ref must be used together" >&2
  exit 1
fi

# Determine file list (array of date strings like "2026.03.31")
dates=()

if [[ -n "$FILE" ]]; then
  date="${FILE%.org}"
  if [[ ! -f "$CWN_DATA/$date.org" ]]; then
    echo "File not found: $CWN_DATA/$date.org" >&2
    exit 1
  fi
  dates+=("$date")
elif [[ -n "$FROM_REF" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && dates+=("${f%.org}")
  done < <(git -C "$CWN_DATA" diff --name-only "$FROM_REF" "$TO_REF" -- "*.org")
else
  for f in "$CWN_DATA"/*.org; do
    [[ -f "$f" ]] || continue
    date="$(basename "$f" .org)"
    if [[ -n "$SINCE" ]]; then
      # --since implies force: include all files on or after the date
      dates+=("$date")
    else
      # Default: skip already-translated files
      if [[ ! -f "$JA_DIR/$date.org" ]]; then
        dates+=("$date")
      fi
    fi
  done
fi

# Apply --since filter
if [[ -n "$SINCE" ]]; then
  filtered=()
  for d in "${dates[@]}"; do
    if [[ ! "$d" < "$SINCE" ]]; then
      filtered+=("$d")
    fi
  done
  dates=("${filtered[@]}")
fi

# Sort dates
IFS=$'\n' dates=($(sort <<<"${dates[*]}")); unset IFS

if [[ ${#dates[@]} -eq 0 ]]; then
  echo "No files to translate."
  exit 0
fi

echo "Found ${#dates[@]} file(s) to translate: ${dates[*]}"

mkdir -p "$JA_DIR"

succeeded=0
failed=0

for date in "${dates[@]}"; do
  echo "--- Translating $date ---"
  if $TRANSLATE "$CWN_DATA/$date.org" "$JA_DIR/$date.org"; then
    ((succeeded++))
  else
    echo "FAILED: $date" >&2
    ((failed++))
  fi
done

echo ""
echo "Translation: $succeeded succeeded, $failed failed."

# Generate HTML for all translated org files
echo "Running make to generate HTML..."
make -C "$ROOT"

if [[ $failed -gt 0 ]]; then
  exit 1
fi
