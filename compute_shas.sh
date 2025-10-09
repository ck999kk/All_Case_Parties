#!/usr/bin/env bash
# compute_shas.sh
# Compute SHA-256 for all files excluding common temporary/junk files
# Writes results to all_non_tmp_sha256.txt, all_non_tmp_sha256.csv and a small JSON summary.

set -euo pipefail

OUT_TXT="all_non_tmp_sha256.txt"
OUT_CSV="all_non_tmp_sha256.csv"
OUT_JSON="all_non_tmp_sha256_summary.json"

: > "$OUT_TXT"
: > "$OUT_CSV"

# CSV header
printf 'sha256,filepath,size_bytes\n' > "$OUT_CSV"

# Patterns to exclude
EXCLUDE_NAMES=("*.tmp" "*~" ".DS_Store" "*.swp" "*.bak" "*.log")
EXCLUDE_PATHS=("*/__pycache__/*" "*/node_modules/*" "*/.git/*")

# Build find exclude expressions
FIND_ARGS=(.)
for p in "${EXCLUDE_PATHS[@]}"; do
  FIND_ARGS+=( -not -path "$p" )
done
for n in "${EXCLUDE_NAMES[@]}"; do
  FIND_ARGS+=( -not -name "$n" )
done
FIND_ARGS+=( -type f -print0 )

# Detect stat flavor
IS_LINUX=false
if stat --version >/dev/null 2>&1; then
  IS_LINUX=true
fi

FILES_TMP=$(mktemp)
trap 'rm -f "$FILES_TMP"' EXIT

# Run find and create a sorted newline-separated list
find "${FIND_ARGS[@]}" | tr '\0' '\n' | sort > "$FILES_TMP"

while IFS= read -r f; do
  # skip if empty
  [ -z "$f" ] && continue
  if [ ! -f "$f" ]; then
    continue
  fi
  sha=$(shasum -a 256 "$f" | awk '{print $1}')
  if $IS_LINUX; then
    size=$(stat -c%s "$f")
  else
    size=$(stat -f%z "$f")
  fi
  printf '%s  %s\n' "$sha" "$f" >> "$OUT_TXT"
  # escape double quotes in path for CSV
  esc_path=${f//\"/\"\"}
  printf '%s,"%s",%s\n' "$sha" "$esc_path" "$size" >> "$OUT_CSV"
done < "$FILES_TMP"

# Summary JSON
total=$(wc -l < "$OUT_TXT" | tr -d ' ')
total_bytes=$(awk -F, 'NR>1{sum += $3} END {print sum+0}' "$OUT_CSV" || true)
printf '{"files": %s, "total_bytes": %s}\n' "$total" "${total_bytes:-0}" > "$OUT_JSON"

echo "Wrote checksums to $OUT_TXT and CSV to $OUT_CSV"
wc -l "$OUT_TXT" | awk '{print $1 " files recorded"}'
