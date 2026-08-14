#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — fix mobile horizontal overflow on product/collection item pages..."

mkdir -p "components"
cat > "components/ProductGallery.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useState } from 'react';
import Image from 'next/image';
import { ChevronLeft, ChevronRight } from 'lucide-react';

export function ProductGallery({ images, name }: { images: string[]; name: string }) {
  const [index, setIndex] = useState(0);
  const hasMultiple = images.length > 1;

  function prev() {
    setIndex((i) => (i - 1 + images.length) % images.length);
  }
  function next() {
    setIndex((i) => (i + 1) % images.length);
  }

  if (images.length === 0) {
    return <div className="aspect-[4/5] bg-sand" />;
  }

  return (
    // min-w-0 lets this column shrink inside its parent CSS grid
    // (product/collection pages use `grid md:grid-cols-2`) — grid
    // items default to min-width: auto and otherwise refuse to shrink
    // below their content's natural width.
    <div className="min-w-0">
      {/* w-full (not w-auto) is the key fix here: combined with
          aspect-[4/5] and max-h-[65vh], "w-auto" let the browser size
          this box's width FROM the height on tall/narrow mobile
          screens — which could come out wider than the actual screen,
          pushing the whole page (photo, text, buttons) sideways off
          the edge. w-full guarantees the box is never wider than its
          own container; object-cover on the photo still fills
          whatever box shape results without distorting or leaving
          gaps. */}
      <div className="relative mx-auto aspect-[4/5] max-h-[65vh] w-full max-w-full overflow-hidden bg-sand">
        <Image
          key={images[index]}
          src={images[index]}
          alt={name}
          fill
          priority
          sizes="(min-width: 768px) 50vw, 100vw"
          className="object-cover"
        />

        {hasMultiple && (
          <>
            <button
              onClick={prev}
              aria-label="Previous photo"
              className="absolute left-3 top-1/2 flex h-9 w-9 -translate-y-1/2 items-center justify-center bg-cream/85 text-ink transition-colors hover:bg-cream"
            >
              <ChevronLeft size={18} />
            </button>
            <button
              onClick={next}
              aria-label="Next photo"
              className="absolute right-3 top-1/2 flex h-9 w-9 -translate-y-1/2 items-center justify-center bg-cream/85 text-ink transition-colors hover:bg-cream"
            >
              <ChevronRight size={18} />
            </button>
            <span className="absolute bottom-3 right-3 bg-cream/85 px-2.5 py-1 font-mono text-[10px] uppercase tracking-widest2 text-ink">
              {index + 1} / {images.length}
            </span>
          </>
        )}
      </div>

      {hasMultiple && (
        <div className="mt-3 flex min-w-0 gap-3 overflow-x-auto">
          {images.map((src, i) => (
            <button
              key={src}
              onClick={() => setIndex(i)}
              className={`relative h-20 w-16 shrink-0 overflow-hidden bg-sand transition-opacity ${
                i === index ? 'opacity-100 ring-1 ring-ink' : 'opacity-60 hover:opacity-90'
              }`}
              aria-label={`Photo ${i + 1}`}
            >
              <Image src={src} alt="" fill sizes="64px" className="object-cover" />
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/ProductGallery.tsx"

echo ""
echo "Done. git add -A && git commit -m \"Fix mobile horizontal overflow on product/collection item pages\" && git push"