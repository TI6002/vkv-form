import { notFound } from 'next/navigation';
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { Link } from '@/lib/navigation';
import { Reveal } from '@/components/Reveal';
import { ProductGallery } from '@/components/ProductGallery';
import { getCollectionItemById } from '@/lib/collection-item';
import { pickLocalized } from '@/lib/localized';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function CollectionItemPage({
  params: { locale, id },
}: {
  params: { locale: string; id: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('collection');
  const tp = await getTranslations('product');
  const item = await getCollectionItemById(id);
  if (!item) notFound();

  const name = pickLocalized(item.name, locale);
  const description = pickLocalized(item.description, locale);
  const materials = pickLocalized(item.materials, locale);
  const height = pickLocalized(item.height, locale);
  const width = pickLocalized(item.width, locale);
  const circumference = pickLocalized(item.circumference, locale);
  const depth = pickLocalized(item.depth, locale);
  const weight = pickLocalized(item.weight, locale);

  return (
    <div className="mx-auto max-w-[1400px] px-6 py-16 md:px-10 md:py-24">
      <Link
        href="/collection"
        className="font-mono text-[11px] uppercase tracking-widest2 text-stone hover:text-ink"
      >
        ← {t('title')}
      </Link>

      <div className="mt-8 grid gap-14 md:grid-cols-2 md:gap-20">
        <Reveal>
          <ProductGallery images={item.images ?? []} name={name} />
        </Reveal>

        <Reveal delay={0.1}>
          <h1 className="font-display text-4xl text-ink md:text-5xl">{name}</h1>

          {/* No price, no buy button, no year — this piece has already
              found its home; this badge is the only status shown. */}
          <span className="mt-5 inline-block bg-sand px-3.5 py-2 font-mono text-[11px] uppercase tracking-widest2 text-ink">
            {t('sold')}
          </span>

          {description && (
            <p className="mt-8 font-body text-base leading-relaxed text-stone">
              {description}
            </p>
          )}

          {(materials || height || width || circumference || depth || weight) && (
            <dl className="mt-8 space-y-3 border-t border-line pt-6">
              {materials && (
                <div className="flex gap-4">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {tp('materialsLabel')}
                  </dt>
                  <dd className="font-body text-sm text-ink">{materials}</dd>
                </div>
              )}
              {height && (
                <div className="flex gap-4">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {tp('heightLabel')}
                  </dt>
                  <dd className="font-body text-sm text-ink">{height}</dd>
                </div>
              )}
              {width && (
                <div className="flex gap-4">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {tp('widthLabel')}
                  </dt>
                  <dd className="font-body text-sm text-ink">{width}</dd>
                </div>
              )}
              {circumference && (
                <div className="flex gap-4">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {tp('circumferenceLabel')}
                  </dt>
                  <dd className="font-body text-sm text-ink">{circumference}</dd>
                </div>
              )}
              {depth && (
                <div className="flex gap-4">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {tp('depthLabel')}
                  </dt>
                  <dd className="font-body text-sm text-ink">{depth}</dd>
                </div>
              )}
              {weight && (
                <div className="flex gap-4">
                  <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
                    {tp('weightLabel')}
                  </dt>
                  <dd className="font-body text-sm text-ink">{weight}</dd>
                </div>
              )}
            </dl>
          )}
        </Reveal>
      </div>
    </div>
  );
}
