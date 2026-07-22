#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates (round 15 — plain white hero text, no block/card at all)..."

mkdir -p "app/[locale]"
cat > "app/[locale]/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import Image from 'next/image';
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
        {/*
          Drop your own photo in as public/images/hero.png (landscape,
          ideally 1800px+ wide) and it replaces this automatically — no
          code change needed. Falls back to a placeholder until then.
        */}
        <Image
          src="/images/hero.png"
          alt=""
          fill
          priority
          sizes="100vw"
          className="object-cover"
        />

        <div className="relative z-10 mx-auto w-full max-w-[1400px] px-6 pb-10 md:px-10 md:pb-16">
          <div className="max-w-xl">
            <p className="hero-text-outline font-mono text-[11px] uppercase tracking-widest2 text-white">
              {t('heroEyebrow')}
            </p>
            <h1 className="hero-text-outline mt-5 font-display text-[11vw] leading-[0.98] text-white md:text-[4.4vw]">
              {heroLines.map((line, i) => (
                <span key={i} className="block">
                  {i === heroLines.length - 1 ? (
                    <em className="not-italic italic">{line}</em>
                  ) : (
                    line
                  )}
                </span>
              ))}
            </h1>
            <p className="hero-text-outline mt-6 font-body text-base leading-relaxed text-white">
              {t('heroSubtitle')}
            </p>
            <Link
              href="/catalog"
              className="mt-8 inline-block border border-white px-7 py-3.5 font-mono text-[11px] uppercase tracking-widest2 text-white transition-colors hover:bg-white hover:text-ink"
            >
              {t('heroCta')}
            </Link>
          </div>
        </div>
      </section>

      {/* Philosophy — white panel */}
      <section className="bg-white">
        <div className="mx-auto max-w-[1400px] px-6 py-28 md:px-10 md:py-36">
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
        </div>
      </section>

      {/* Featured catalogue — beige panel, alternating with the white one above */}
      <section className="bg-cream">
        <div className="mx-auto max-w-[1400px] px-6 py-28 md:px-10 md:py-36">
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
        </div>
      </section>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/page.tsx"

echo "Done. Restart npm run dev after this."