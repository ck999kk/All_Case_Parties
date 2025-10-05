#!/usr/bin/env zsh
# compute_shas.sh
# Compute SHA-256 for all files excluding common temporary/junk files
# Writes results to all_non_tmp_sha256.txt and all_non_tmp_sha256.csv in the repository root.

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
EXPR=()
for p in "${EXCLUDE_PATHS[@]}"; do
  EXPR+=( -not -path "$p" )
done
for n in "${EXCLUDE_NAMES[@]}"; do
  EXPR+=( -not -name "$n" )
done

# Find files, sort, compute sha256 and sizes
# Use shasum -a 256 (macOS) and stat -f%z for size (macOS). Fall back to stat -c%s on Linux if needed.

is_linux=false
if stat --version >/dev/null 2>&1; then
  is_linux=true
fi

FILES_TMP=$(mktemp)
trap 'rm -f "$FILES_TMP"' EXIT

eval find . -type f "${EXPR[@]}" -print0 | xargs -0 -I{} sh -c 'printf "%s\n" "{}"' | sort > "$FILES_TMP"

while IFS= read -r f; do
  # compute sha256
  sha=$(shasum -a 256 "$f" | awk '{print $1}')
  if $is_linux; then
    size=$(stat -c%s "$f")
  else
    size=$(stat -f%z "$f")
  fi
  printf '%s  %s\n' "$sha" "$f" >> "$OUT_TXT"
  # CSV needs to escape double quotes and wrap path in quotes
  esc_path=${f//"/""}
  printf '%s,"%s",%s\n' "$sha" "$esc_path" "$size" >> "$OUT_CSV"
done < "$FILES_TMP"

# Summary JSON (basic)
total=$(wc -l < "$OUT_TXT" | tr -d ' ')
total_bytes=$(awk '{sum += $3} END {print sum+0}' "$OUT_CSV" | sed -n '1p' || true)
printf '{"files": %s, "total_bytes": %s}\n' "$total" "${total_bytes:-0}" > "$OUT_JSON"

echo "Wrote checksums to $OUT_TXT and CSV to $OUT_CSV"
wc -l "$OUT_TXT" | awk '{print $1 " files recorded"}'
