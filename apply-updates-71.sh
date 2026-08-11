#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — fix event banner cropping on mobile..."

mkdir -p "components"
cat > "components/HeroSlider.tsx" << '__VKV_PATCH_EOF__'
'use client';

import { useEffect, useRef, useState, type ReactNode } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';

/**
 * Full-bleed hero slider, like the reference site (joannenajjar.com) —
 * each slide is its own full-screen block passed in as children, with
 * arrows + a "1 / 3" counter + auto-advance (paused on hover/interaction).
 */
export function HeroSlider({ slides }: { slides: ReactNode[] }) {
  const [index, setIndex] = useState(0);
  const [paused, setPaused] = useState(false);
  const count = slides.length;
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  function goTo(i: number) {
    setIndex(((i % count) + count) % count);
  }
  function next() {
    goTo(index + 1);
  }
  function prev() {
    goTo(index - 1);
  }

  useEffect(() => {
    if (paused || count <= 1) return;
    timerRef.current = setInterval(() => {
      setIndex((i) => (i + 1) % count);
    }, 6000);
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [paused, count]);

  return (
    <div
      // Shorter on phones so images that switch to object-contain
      // (see HomePage — event slides with baked-in text) don't leave
      // huge empty letterbox bars; back up to the original full-bleed
      // height from tablet width up.
      className="relative h-[70vh] w-full overflow-hidden sm:h-[80vh] md:h-[92vh]"
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
    >
      {slides.map((slide, i) => (
        <div
          key={i}
          aria-hidden={i !== index}
          className={`absolute inset-0 transition-opacity duration-[1200ms] ease-signature ${
            i === index ? 'z-10 opacity-100' : 'pointer-events-none z-0 opacity-0'
          }`}
        >
          {slide}
        </div>
      ))}

      {count > 1 && (
        <>
          <button
            onClick={prev}
            aria-label="Previous slide"
            className="absolute left-4 top-1/2 z-20 flex h-10 w-10 -translate-y-1/2 items-center justify-center bg-cream/80 text-ink transition-colors hover:bg-cream md:left-8"
          >
            <ChevronLeft size={20} />
          </button>
          <button
            onClick={next}
            aria-label="Next slide"
            className="absolute right-4 top-1/2 z-20 flex h-10 w-10 -translate-y-1/2 items-center justify-center bg-cream/80 text-ink transition-colors hover:bg-cream md:right-8"
          >
            <ChevronRight size={20} />
          </button>

          <div className="absolute bottom-6 right-6 z-20 flex items-center gap-3 md:bottom-8 md:right-10">
            <span className="font-mono text-[11px] tracking-widest2 text-white [text-shadow:0_1px_4px_rgba(0,0,0,0.5)]">
              {index + 1} / {count}
            </span>
            <div className="flex gap-1.5">
              {slides.map((_, i) => (
                <button
                  key={i}
                  onClick={() => goTo(i)}
                  aria-label={`Go to slide ${i + 1}`}
                  className={`h-1.5 w-1.5 rounded-full transition-all ${
                    i === index ? 'w-4 bg-white' : 'bg-white/50'
                  }`}
                />
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: components/HeroSlider.tsx"

mkdir -p "app/[locale]"
cat > "app/[locale]/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import Image from 'next/image';
import { Link } from '@/lib/navigation';
import { Reveal } from '@/components/Reveal';
import { ProductCard } from '@/components/ProductCard';
import { HeroSlider } from '@/components/HeroSlider';
import { getProducts } from '@/lib/products';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

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
      {/*
        Hero slider — 3 slides. The first two are drafts for the client's
        two upcoming events (photo, title, link — all placeholder text
        below, meant to be edited). The third slide is the studio's
        regular homepage banner, unchanged.

        Event slides 1 & 2 use posters that have their own text baked
        into the photo. On phones, a tall/narrow slider box combined
        with object-cover zoomed in and cut that text off at the edges
        — object-contain (mobile) shows the whole poster instead, with
        a small solid-colour margin above/below when needed; from
        tablet width up there's enough room that object-cover (full
        bleed, no margin) looks better, so it switches back at `sm:`.
      */}
      <HeroSlider
        slides={[
          // --- Slide 1: Event (photo only — add text/button back if you want them) ---
          <div key="event-1" className="relative h-full w-full bg-ink">
            <Image
              src="/images/event-1.png"
              alt=""
              fill
              priority
              sizes="100vw"
              className="object-contain sm:object-cover"
            />
          </div>,

          // --- Slide 2: Event (photo has its own text — just a centered button) ---
          <div key="event-2" className="relative h-full w-full bg-ink">
            <Image
              src="/images/event-2.png"
              alt=""
              fill
              sizes="100vw"
              className="object-contain sm:object-cover"
            />
            <div className="relative z-10 flex h-full w-full items-end justify-center pb-20 md:pb-28">
              <Link
                href="https://www.1000vases.com/about"
                className="border-2 border-white px-12 py-5 font-mono text-sm uppercase tracking-widest2 text-white transition-colors hover:bg-white hover:text-ink"
              >
                Explore
              </Link>
            </div>
          </div>,

          // --- Slide 3: the studio's regular homepage banner (unchanged) ---
          <div key="studio" className="relative h-full w-full">
            <Image
              src="/images/hero.png"
              alt=""
              fill
              sizes="100vw"
              className="object-cover"
            />
            <div className="relative z-10 flex h-full w-full items-end">
              <div className="mx-auto w-full max-w-[1400px] px-6 pb-10 md:px-10 md:pb-16">
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
            </div>
          </div>,
        ]}
      />

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

echo ""
echo "Done. git add -A && git commit -m \"Fix event banner text getting cropped on mobile\" && git push"