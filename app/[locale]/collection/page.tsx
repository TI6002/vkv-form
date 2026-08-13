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
