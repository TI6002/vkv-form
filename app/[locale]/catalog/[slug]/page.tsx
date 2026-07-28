import { notFound } from 'next/navigation';
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { Link } from '@/lib/navigation';
import { Reveal } from '@/components/Reveal';

// Without this, Next.js can cache this page's rendered output (and the
// Supabase fetch behind it) and keep showing stale product data — e.g.
// availability toggled in /admin not showing up here without a rebuild.
export const dynamic = 'force-dynamic';
export const revalidate = 0;
import { AddToCartForm } from '@/components/AddToCartForm';
import { LikeButton } from '@/components/LikeButton';
import { ProductGallery } from '@/components/ProductGallery';
import { AvailabilityBadge } from '@/components/AvailabilityBadge';
import { getProductBySlug } from '@/lib/products';
import { formatPrice } from '@/lib/format';
import { pickLocalized } from '@/lib/localized';

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
    <div className="mx-auto max-w-[1400px] px-6 py-16 md:px-10 md:py-24">
      <Link
        href="/catalog"
        className="font-mono text-[11px] uppercase tracking-widest2 text-stone hover:text-ink"
      >
        ← {t('back')}
      </Link>

      <div className="mt-8 grid gap-14 md:grid-cols-2 md:gap-20">
        <Reveal>
          <ProductGallery images={product.images ?? []} name={name} />
        </Reveal>

        <Reveal delay={0.1}>
          <div className="flex items-start justify-between gap-4">
            <h1 className="font-display text-4xl text-ink md:text-5xl">{name}</h1>
          </div>
          <p className="mt-3 font-mono text-xl text-stone">
            {formatPrice(product.price_cents, product.currency)}
          </p>

          <AvailabilityBadge productId={product.id} initialAvailable={available} />

          <p className="mt-8 font-body text-base leading-relaxed text-stone">
            {description}
          </p>

          <dl className="mt-8 space-y-3 border-t border-line pt-6">
            {materials && (
              <div className="flex gap-4">
                <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                  {t('materialsLabel')}
                </dt>
                <dd className="font-body text-sm text-ink">{materials}</dd>
              </div>
            )}
            {height && (
              <div className="flex gap-4">
                <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                  {t('heightLabel')}
                </dt>
                <dd className="font-body text-sm text-ink">{height}</dd>
              </div>
            )}
            {width && (
              <div className="flex gap-4">
                <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                  {t('widthLabel')}
                </dt>
                <dd className="font-body text-sm text-ink">{width}</dd>
              </div>
            )}
            {circumference && (
              <div className="flex gap-4">
                <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                  {t('circumferenceLabel')}
                </dt>
                <dd className="font-body text-sm text-ink">{circumference}</dd>
              </div>
            )}
            {depth && (
              <div className="flex gap-4">
                <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                  {t('depthLabel')}
                </dt>
                <dd className="font-body text-sm text-ink">{depth}</dd>
              </div>
            )}
            {weight && (
              <div className="flex gap-4">
                <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                  {t('weightLabel')}
                </dt>
                <dd className="font-body text-sm text-ink">{weight}</dd>
              </div>
            )}
          </dl>

          <AddToCartForm product={product} name={name} />

          <div className="mt-3">
            <LikeButton productId={product.id} />
          </div>

          <p className="mt-6 font-body text-xs leading-relaxed text-taupe">
            {t('shippingNote')}
          </p>
        </Reveal>
      </div>
    </div>
  );
}
