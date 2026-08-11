#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — fix build error: add 'delivered' to OrderCard's STATUS_COLOR..."

FILE="components/OrderCard.tsx"

if [ ! -f "$FILE" ]; then
  echo "ERROR: $FILE not found — run this from the project root."
  exit 1
fi

if grep -q "delivered: 'text-" "$FILE"; then
  echo "  $FILE already has a 'delivered' entry in STATUS_COLOR — nothing to do."
else
  if grep -q "shipped: 'text-stone'," "$FILE"; then
    sed -i "s/shipped: 'text-stone',/shipped: 'text-stone',\n  delivered: 'text-green-700',/" "$FILE"
    echo "  updated: $FILE"
  else
    echo "WARNING: could not find \"shipped: 'text-stone',\" in $FILE."
    echo "  Open components/OrderCard.tsx yourself and add this line to the"
    echo "  STATUS_COLOR object (next to the other statuses):"
    echo "    delivered: 'text-green-700',"
  fi
fi

echo ""
echo "Done. git add -A && git commit -m \"Fix build: add delivered status color to OrderCard\" && git push"