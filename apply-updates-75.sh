#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — fix build error: add 'delivered' to OrderCard's STATUS_LABEL..."

FILE="components/OrderCard.tsx"

if [ ! -f "$FILE" ]; then
  echo "ERROR: $FILE not found — run this from the project root."
  exit 1
fi

if grep -q "delivered:" "$FILE"; then
  echo "  $FILE already has a 'delivered' entry — nothing to do."
else
  if grep -q "shipped: 'Shipped'," "$FILE"; then
    sed -i "s/shipped: 'Shipped',/shipped: 'Shipped',\n  delivered: 'Delivered',/" "$FILE"
    echo "  updated: $FILE"
  else
    echo "WARNING: could not find \"shipped: 'Shipped',\" in $FILE."
    echo "  Open components/OrderCard.tsx yourself and add this line to the"
    echo "  STATUS_LABEL object (next to the other statuses):"
    echo "    delivered: 'Delivered',"
  fi
fi

echo ""
echo "Done. git add -A && git commit -m \"Fix build: add delivered status label to OrderCard\" && git push"