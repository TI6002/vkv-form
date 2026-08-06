#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — disable on-server image processing (fixes likely OOM on the small hosting tier)..."

cat > "next.config.mjs" << '__VKV_PATCH_EOF__'
import createNextIntlPlugin from 'next-intl/plugin';

const withNextIntl = createNextIntlPlugin('./i18n.ts');

/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: '*.supabase.co',
      },
      {
        protocol: 'https',
        hostname: 'picsum.photos',
      },
    ],
    // Next.js normally resizes/re-encodes every image on the server the
    // first time it's requested at a given size — this is CPU- and
    // memory-heavy, and on a small 512MB hosting container it can crash
    // or stall the whole app (which matches "images load slowly, then
    // the page errors out"). Photos already come from Supabase Storage
    // at a reasonable size, so skipping Next's own processing trades a
    // small amount of extra bandwidth for a server that doesn't fall
    // over under a handful of concurrent visitors.
    unoptimized: true,
  },
};

export default withNextIntl(nextConfig);
__VKV_PATCH_EOF__
echo "  updated: next.config.mjs"

echo "Done. git add -A && git commit -m \"Disable image optimization to reduce server load\" && git push"