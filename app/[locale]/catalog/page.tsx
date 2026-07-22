import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { Reveal } from '@/components/Reveal';
import { ProductCard } from '@/components/ProductCard';
import { getProducts } from '@/lib/products';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function CatalogPage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('catalog');
  const products = await getProducts();

  return (
    <div className="mx-auto max-w-[1400px] px-6 py-20 md:px-10 md:py-28">
      <Reveal>
        <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
          {t('title')}
        </p>
        <h1 className="mt-4 font-display text-4xl text-ink md:text-5xl">{t('subtitle')}</h1>
      </Reveal>

      {products.length === 0 ? (
        <p className="mt-20 font-body text-stone">{t('empty')}</p>
      ) : (
        <div className="mt-16 grid grid-cols-1 gap-x-8 gap-y-16 sm:grid-cols-2 md:grid-cols-3">
          {products.map((p, i) => (
            <Reveal key={p.id} delay={(i % 3) * 0.06}>
              <ProductCard product={p} index={i} />
            </Reveal>
          ))}
        </div>
      )}
    </div>
  );
}
