import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { Link } from '@/lib/navigation';
import { Reveal } from '@/components/Reveal';
import { ProductCard } from '@/components/ProductCard';
import { getProducts } from '@/lib/products';

export default async function HomePage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('home');
  const products = (await getProducts()).slice(0, 3);

  const heroLines = t('heroTitle').split('\n');

  return (
    <div>
      {/* Hero */}
      <section className="relative flex min-h-[92vh] items-end overflow-hidden">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="https://picsum.photos/seed/vkv-hero/1800/1400"
          alt=""
          className="absolute inset-0 h-full w-full object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-ink/55 via-ink/10 to-transparent" />
        <div className="relative z-10 mx-auto w-full max-w-[1400px] px-6 pb-16 md:px-10 md:pb-24">
          <p className="font-mono text-[11px] uppercase tracking-widest2 text-cream/80">
            {t('heroEyebrow')}
          </p>
          <h1 className="mt-5 max-w-2xl font-display text-[13vw] leading-[0.95] text-cream md:text-[6.2vw]">
            {heroLines.map((line, i) => (
              <span key={i} className="block">
                {i === heroLines.length - 1 ? <em className="not-italic italic">{line}</em> : line}
              </span>
            ))}
          </h1>
          <p className="mt-7 max-w-md font-body text-base leading-relaxed text-cream/90">
            {t('heroSubtitle')}
          </p>
          <Link
            href="/catalog"
            className="mt-9 inline-block border border-cream/70 px-7 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-cream transition-colors hover:bg-cream hover:text-ink"
          >
            {t('heroCta')}
          </Link>
        </div>
      </section>

      {/* Philosophy */}
      <section className="mx-auto max-w-[1400px] px-6 py-28 md:px-10 md:py-36">
        <Reveal>
          <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
            {t('philosophyEyebrow')}
          </p>
        </Reveal>
        <div className="mt-6 grid gap-10 md:grid-cols-2 md:gap-20">
          <Reveal>
            <h2 className="font-display text-4xl leading-[1.1] text-ink md:text-5xl">
              {t('philosophyTitle')}
            </h2>
          </Reveal>
          <Reveal delay={0.1}>
            <p className="font-body text-lg leading-relaxed text-stone">
              {t('philosophyBody')}
            </p>
          </Reveal>
        </div>
      </section>

      {/* Featured catalogue */}
      <section className="mx-auto max-w-[1400px] px-6 pb-28 md:px-10 md:pb-36">
        <Reveal>
          <div className="flex items-end justify-between border-b border-line pb-6">
            <div>
              <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
                {t('catalogEyebrow')}
              </p>
              <h2 className="mt-3 font-display text-3xl text-ink md:text-4xl">
                {t('catalogTitle')}
              </h2>
            </div>
            <span className="hidden font-mono text-[11px] uppercase tracking-widest2 text-taupe md:block">
              {t('featuredEyebrow')}
            </span>
          </div>
        </Reveal>

        <div className="mt-12 grid grid-cols-1 gap-x-8 gap-y-14 sm:grid-cols-2 md:grid-cols-3">
          {products.map((p, i) => (
            <Reveal key={p.id} delay={i * 0.08}>
              <ProductCard product={p} index={i} />
            </Reveal>
          ))}
        </div>

        <Reveal delay={0.15}>
          <div className="mt-16 text-center">
            <Link
              href="/catalog"
              className="font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
            >
              {t('catalogCta')}
            </Link>
          </div>
        </Reveal>
      </section>
    </div>
  );
}
