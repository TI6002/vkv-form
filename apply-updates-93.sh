#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — remove shipping note from product page..."

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
          <div className="min-w-0 overflow-hidden">
            <ProductGallery images={product.images ?? []} name={name} />
          </div>

          <div className="min-w-0">
            <h1 className="break-words [overflow-wrap:anywhere] font-display text-3xl text-ink md:text-4xl">{name}</h1>
            <p className="mt-3 font-mono text-xl text-ink">
              {formatPrice(product.price_cents, product.currency)}
            </p>

            <AvailabilityBadge productId={product.id} initialAvailable={available} />

            <p className="mt-6 break-words [overflow-wrap:anywhere] font-body text-base leading-relaxed text-stone">
              {description}
            </p>

            <dl className="mt-8 flex flex-col gap-3 border-t border-line pt-6">
              {materials && (
                <div className="flex flex-wrap gap-x-4 gap-y-1">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {t('materialsLabel')}
                  </dt>
                  <dd className="min-w-0 flex-1 break-words [overflow-wrap:anywhere] font-body text-sm text-ink">{materials}</dd>
                </div>
              )}
              {height && (
                <div className="flex flex-wrap gap-x-4 gap-y-1">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {t('heightLabel')}
                  </dt>
                  <dd className="min-w-0 flex-1 break-words [overflow-wrap:anywhere] font-body text-sm text-ink">{height}</dd>
                </div>
              )}
              {width && (
                <div className="flex flex-wrap gap-x-4 gap-y-1">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {t('widthLabel')}
                  </dt>
                  <dd className="min-w-0 flex-1 break-words [overflow-wrap:anywhere] font-body text-sm text-ink">{width}</dd>
                </div>
              )}
              {circumference && (
                <div className="flex flex-wrap gap-x-4 gap-y-1">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {t('circumferenceLabel')}
                  </dt>
                  <dd className="min-w-0 flex-1 break-words [overflow-wrap:anywhere] font-body text-sm text-ink">{circumference}</dd>
                </div>
              )}
              {depth && (
                <div className="flex flex-wrap gap-x-4 gap-y-1">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {t('depthLabel')}
                  </dt>
                  <dd className="min-w-0 flex-1 break-words [overflow-wrap:anywhere] font-body text-sm text-ink">{depth}</dd>
                </div>
              )}
              {weight && (
                <div className="flex flex-wrap gap-x-4 gap-y-1">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {t('weightLabel')}
                  </dt>
                  <dd className="min-w-0 flex-1 break-words [overflow-wrap:anywhere] font-body text-sm text-ink">{weight}</dd>
                </div>
              )}
            </dl>

            <AddToCartForm product={product} name={name} />

            <div className="mt-8 flex items-center gap-4 border-t border-line pt-6">
              <LikeButton productId={product.id} variant="button" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/catalog/[slug]/page.tsx"

echo "Done. git add -A && git commit -m \"Remove shipping note from product page\" && git push"