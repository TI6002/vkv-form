#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — fix build error: make Product.sort_order optional..."

FILES=$(grep -rl "sort_order: number | null;" --include="*.ts" --include="*.tsx" . 2>/dev/null || true)

if [ -z "$FILES" ]; then
  echo "WARNING: could not find \"sort_order: number | null;\" in any .ts/.tsx file."
  echo "  Open lib/types.ts yourself and make sure the Product interface has:"
  echo "    sort_order?: number | null;"
  echo "  (note the ? — it must be optional, not required)"
else
  echo "$FILES" | while IFS= read -r f; do
    sed -i "s/sort_order: number | null;/sort_order?: number | null;/" "$f"
    echo "  updated: $f"
  done
fi

echo ""
echo "Done. git add -A && git commit -m \"Fix build: make Product.sort_order optional\" && git push"