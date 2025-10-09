#!/usr/bin/env bash
set -euo pipefail

DIR="All_Case_Parties_EML"
OUT_TXT="eml_sha256.txt"
OUT_CSV="eml_sha256.csv"
OUT_JSON="eml_sha256_summary.json"

if [ ! -d "$DIR" ]; then
  echo "Directory $DIR does not exist. Aborting."
  exit 1
fi

: > "$OUT_TXT"
: > "$OUT_CSV"
printf 'sha256,filepath,size_bytes\n' > "$OUT_CSV"

FILES_TMP=$(mktemp)
trap 'rm -f "$FILES_TMP"' EXIT

# find files excluding common tmp
find "$DIR" -type f \
  -not -name '*.tmp' -not -name '*~' -not -name '.DS_Store' -not -name '*.swp' -not -name '*.bak' -not -name '*.log' -print0 | tr '\0' '\n' | sort > "$FILES_TMP"

count=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  sha=$(shasum -a 256 "$f" | awk '{print $1}')
  size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f")
  printf '%s  %s\n' "$sha" "$f" >> "$OUT_TXT"
  esc_path=${f//\"/\"\"}
  printf '%s,"%s",%s\n' "$sha" "$esc_path" "$size" >> "$OUT_CSV"
  count=$((count+1))
done < "$FILES_TMP"

printf '{"files": %s, "total_bytes": %s}\n' "$count" "$(awk -F, 'NR>1{sum+=$3} END{print sum+0}' "$OUT_CSV")" > "$OUT_JSON"

echo "Wrote $count files to $OUT_TXT and CSV $OUT_CSV"

# commit and push
 git add "$OUT_TXT" "$OUT_CSV" "$OUT_JSON" || true
 if git diff --staged --quiet && git diff --quiet; then
   echo "No changes to commit (eml checksums up-to-date)"
 else
   git commit -m "Add checksums for All_Case_Parties_EML"
 fi
 git push
