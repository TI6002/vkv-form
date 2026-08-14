#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — fix product page mobile overflow..."

mkdir -p "app/[locale]/catalog/[slug]"
cat > "app/[locale]/catalog/[slug]/page.tsx" << '__VKV_PATCH_EOF__'
import { notFound } from 'next/navigation';
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { AddToCartForm } from '@/components/AddToCartForm';
import { LikeButton } from '@/components/LikeButton';
import { ProductGallery } from '@/components/ProductGallery';
import { AvailabilityBadge } from '@/components/AvailabilityBadge';
import { getProductBySlug } from '@/lib/products';
import { pickLocalized } from '@/lib/localized';
import { formatPrice } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function ProductPage({
  params: { locale, slug },
}: {
  params: { locale: string; slug: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('product');
  const product = await getProductBySlug(slug);
  if (!product) notFound();

  const name = pickLocalized(product.name, locale);
  const description = pickLocalized(product.description, locale);
  const materials = pickLocalized(product.materials, locale);
  const height = pickLocalized(product.height, locale);
  const width = pickLocalized(product.width, locale);
  const circumference = pickLocalized(product.circumference, locale);
  const depth = pickLocalized(product.depth, locale);
  const weight = pickLocalized(product.weight, locale);
  const available = product.available;

  return (
    // overflow-x-hidden here is a safety net: nothing inside this page
    // should ever need to be wider than the screen, but if something
    // does miscalculate (long unbroken text, a fixed-width element,
    // etc.) this stops the whole page from scrolling sideways on
    // mobile instead of just clipping the one offending element.
    <div className="overflow-x-hidden">
      <div className="mx-auto max-w-[1400px] px-6 py-10 md:px-10 md:py-16">
        <a
          href={`/${locale}/catalog`}
          className="font-mono text-[11px] uppercase tracking-widest2 text-stone hover:text-ink"
        >
          ← {t('back')}
        </a>

        {/*
          grid-cols-1 is explicit (not relying on the implicit default)
          so this always stacks into a single column on mobile, then
          becomes two columns from md: up. min-w-0 on both children
          stops a long word or a wide image from forcing its column
          wider than the grid track, which is what was pushing content
          off-screen on phones.
        */}
        <div className="mt-8 grid grid-cols-1 gap-10 md:grid-cols-2 md:gap-16">
          <div className="min-w-0">
            <ProductGallery images={product.images ?? []} name={name} />
          </div>

          <div className="min-w-0">
            <h1 className="font-display text-3xl text-ink md:text-4xl">{name}</h1>
            <p className="mt-3 font-mono text-xl text-ink">
              {formatPrice(product.price_cents, product.currency)}
            </p>

            <AvailabilityBadge productId={product.id} initialAvailable={available} />

            <p className="mt-6 font-body text-base leading-relaxed text-stone">
              {description}
            </p>

            <dl className="mt-8 flex flex-col gap-3 border-t border-line pt-6">
              {materials && (
                <div className="flex flex-wrap gap-x-4 gap-y-1">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {t('materialsLabel')}
                  </dt>
                  <dd className="min-w-0 flex-1 font-body text-sm text-ink">{materials}</dd>
                </div>
              )}
              {height && (
                <div className="flex flex-wrap gap-x-4 gap-y-1">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {t('heightLabel')}
                  </dt>
                  <dd className="min-w-0 flex-1 font-body text-sm text-ink">{height}</dd>
                </div>
              )}
              {width && (
                <div className="flex flex-wrap gap-x-4 gap-y-1">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {t('widthLabel')}
                  </dt>
                  <dd className="min-w-0 flex-1 font-body text-sm text-ink">{width}</dd>
                </div>
              )}
              {circumference && (
                <div className="flex flex-wrap gap-x-4 gap-y-1">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {t('circumferenceLabel')}
                  </dt>
                  <dd className="min-w-0 flex-1 font-body text-sm text-ink">{circumference}</dd>
                </div>
              )}
              {depth && (
                <div className="flex flex-wrap gap-x-4 gap-y-1">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {t('depthLabel')}
                  </dt>
                  <dd className="min-w-0 flex-1 font-body text-sm text-ink">{depth}</dd>
                </div>
              )}
              {weight && (
                <div className="flex flex-wrap gap-x-4 gap-y-1">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {t('weightLabel')}
                  </dt>
                  <dd className="min-w-0 flex-1 font-body text-sm text-ink">{weight}</dd>
                </div>
              )}
            </dl>

            <AddToCartForm product={product} name={name} />

            <div className="mt-8 flex items-center gap-4 border-t border-line pt-6">
              <LikeButton productId={product.id} variant="button" />
            </div>

            <p className="mt-8 font-body text-xs text-taupe">{t('shippingNote')}</p>
          </div>
        </div>
      </div>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/catalog/[slug]/page.tsx"

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
    return <div className="aspect-[4/5] w-full bg-sand" />;
  }

  return (
    // w-full + max-w-full: the gallery must never be wider than its
    // parent grid column. Without this, on some phones the main image
    // (or the horizontally-scrolling thumbnail strip) was reported to
    // spill past the right edge of the screen instead of staying
    // within it.
    <div className="w-full max-w-full">
      <div className="relative aspect-[4/5] w-full max-w-full overflow-hidden bg-sand">
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
        <div className="mt-3 flex w-full max-w-full gap-3 overflow-x-auto">
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

echo "Done. git add -A && git commit -m \"Fix product page mobile overflow\" && git push"