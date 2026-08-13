#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — description only on the item page, paragraphs/indentation preserved..."

# --- 1. Collection Book listing: remove description from the grid cards ---
mkdir -p "app/[locale]/collection"
cat > "app/[locale]/collection/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import Image from 'next/image';
import { Reveal } from '@/components/Reveal';
import { Link } from '@/lib/navigation';
import { getCollectionItems } from '@/lib/collection-items';
import { pickLocalized } from '@/lib/localized';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function CollectionPage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('collection');
  const items = await getCollectionItems();

  return (
    <div className="mx-auto max-w-[1400px] px-6 py-20 md:px-10 md:py-28">
      <Reveal>
        <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {t('eyebrow')}
        </p>
        <h1 className="mt-4 font-display text-4xl italic text-ink md:text-5xl">
          {t('title')}
        </h1>
        <p className="mt-6 max-w-lg font-body text-base leading-relaxed text-stone">
          {t('intro')}
        </p>
      </Reveal>

      {items.length === 0 ? (
        <p className="mt-20 font-body text-stone">{t('empty')}</p>
      ) : (
        <div className="mt-16 grid grid-cols-1 gap-x-8 gap-y-16 sm:grid-cols-2 md:grid-cols-3">
          {items.map((item, i) => {
            const name = pickLocalized(item.name, locale);
            return (
              <Reveal key={item.id} delay={(i % 3) * 0.06}>
                {/* Description is deliberately not shown here — only on
                    the item's own page (/collection/[id]). The grid is
                    just name + photo + status, kept short on purpose. */}
                <Link href={`/collection/${item.id}`} className="group block">
                  <div className="relative aspect-[4/5] overflow-hidden bg-sand">
                    {item.images?.[0] && (
                      <Image
                        src={item.images[0]}
                        alt={name}
                        fill
                        sizes="(min-width: 768px) 33vw, 50vw"
                        className="object-cover grayscale-[15%] transition-transform duration-700 group-hover:scale-105"
                      />
                    )}
                    {/* Just "Sold" — no year shown publicly, even if one
                        was entered in the admin for internal reference. */}
                    <span className="absolute left-4 top-4 bg-cream/85 px-2.5 py-1 font-mono text-[10px] uppercase tracking-widest2 text-ink">
                      {t('sold')}
                    </span>
                  </div>
                  <h3 className="mt-4 font-display text-lg text-ink">{name}</h3>
                </Link>
              </Reveal>
            );
          })}
        </div>
      )}
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/collection/page.tsx"

# --- 2. Item page: preserve paragraphs (blank line = new paragraph) and indentation/tabs ---
mkdir -p "app/[locale]/collection/[id]"
cat > "app/[locale]/collection/[id]/page.tsx" << '__VKV_PATCH_EOF__'
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

  // Same convention as the About page: a blank line in the admin
  // textarea (press Enter twice) starts a new paragraph, and
  // whitespace-pre-wrap below preserves any spaces/tabs typed for
  // indentation within a paragraph instead of collapsing them.
  const descriptionParagraphs = description
    .split(/\n\s*\n/)
    .map((p) => p.trim())
    .filter(Boolean);

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

          {descriptionParagraphs.length > 0 && (
            <div className="mt-8 space-y-4">
              {descriptionParagraphs.map((paragraph, i) => (
                <p
                  key={i}
                  className="whitespace-pre-wrap font-body text-base leading-relaxed text-stone [tab-size:2]"
                >
                  {paragraph}
                </p>
              ))}
            </div>
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
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/collection/[id]/page.tsx"

# --- 3. Admin form: bigger textarea + note about blank line = paragraph, spaces/tabs preserved ---
FILE="components/AdminCollectionPanel.tsx"
if [ -f "$FILE" ] && grep -qF 'rows={3}' "$FILE"; then
  sed -i "s/rows={3}/rows={6}/" "$FILE"
  echo "  updated: $FILE (bigger description textarea)"
fi
if [ -f "$FILE" ] && grep -qF 'rows={6}' "$FILE" && ! grep -qF 'Press Enter twice for a new paragraph' "$FILE"; then
  sed -i '/rows={6}/,/<\/label>/{ /<\/label>/a\
          <p className="-mt-2 font-body text-xs text-taupe">Press Enter twice for a new paragraph. Spaces and tabs you type are preserved on the item page (e.g. for indenting a line).</p>
  }' "$FILE"
  echo "  updated: $FILE (added paragraph/indentation hint under Description)"
fi

echo ""
echo "Done. git add -A && git commit -m \"Move Collection Book description to item page only, preserve paragraphs/indentation\" && git push"