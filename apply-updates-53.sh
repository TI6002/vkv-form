#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — make Stripe client lazy, fixes build-time crash..."

mkdir -p "lib"
cat > "lib/stripe.ts" << '__VKV_PATCH_EOF__'
import Stripe from 'stripe';

/**
 * Lazy Stripe client, exposed as the same `stripe` export other files
 * already import — but the real Stripe instance isn't constructed until
 * the first time it's actually used, not the moment this file loads.
 *
 * Why this matters: Next.js "collects page data" for every API route
 * during the production build, which imports this file. Constructing
 * `new Stripe(...)` at the top level throws immediately if
 * STRIPE_SECRET_KEY looks missing/empty in that specific build step,
 * which fails the entire build — even though the key is set correctly
 * for the app at runtime. Deferring construction avoids that entirely.
 */
let _instance: Stripe | null = null;

function getInstance(): Stripe {
  if (_instance) return _instance;

  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) {
    throw new Error(
      'STRIPE_SECRET_KEY is not set — add it to your environment variables.'
    );
  }

  _instance = new Stripe(key, { apiVersion: '2024-06-20' });
  return _instance;
}

export const stripe: Stripe = new Proxy({} as Stripe, {
  get(_target, prop, receiver) {
    const real = getInstance();
    const value = Reflect.get(real, prop, receiver);
    return typeof value === 'function' ? value.bind(real) : value;
  },
});
__VKV_PATCH_EOF__
echo "  updated: lib/stripe.ts"

echo "Done. Commit and push this to trigger a new deploy: git add -A && git commit -m \"Fix Stripe build error\" && git push"