import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { Reveal } from '@/components/Reveal';

export default async function AboutPage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('about');

  return (
    <div>
      <section className="mx-auto max-w-[1400px] px-6 pt-20 pb-8 md:px-10 md:pt-28">
        <Reveal>
          <h1 className="font-display text-5xl italic text-ink md:text-6xl">{t('title')}</h1>
        </Reveal>
      </section>

      {/* Author */}
      <section className="mx-auto max-w-[1400px] px-6 py-16 md:px-10 md:py-24">
        <div className="grid gap-12 md:grid-cols-[0.9fr_1.1fr] md:gap-20">
          <Reveal>
            <div className="aspect-[3/4] bg-sand">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="https://picsum.photos/seed/vkv-author/900/1200"
                alt=""
                className="h-full w-full object-cover"
              />
            </div>
          </Reveal>
          <Reveal delay={0.1}>
            <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              {t('authorEyebrow')}
            </p>
            <h2 className="mt-4 font-display text-3xl text-ink md:text-4xl">
              {t('authorTitle')}
            </h2>
            <p className="mt-6 font-body text-base leading-relaxed text-stone">
              {t('authorBody1')}
            </p>
            <p className="mt-5 font-body text-base leading-relaxed text-stone">
              {t('authorBody2')}
            </p>
          </Reveal>
        </div>
      </section>

      {/* Philosophy */}
      <section className="border-t border-line bg-paper">
        <div className="mx-auto max-w-[1400px] px-6 py-20 md:px-10 md:py-28">
          <Reveal>
            <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              {t('philosophyEyebrow')}
            </p>
            <h2 className="mt-4 max-w-2xl font-display text-4xl leading-[1.15] text-ink md:text-5xl">
              {t('philosophyTitle')}
            </h2>
          </Reveal>

          <div className="mt-14 grid gap-10 md:grid-cols-3 md:gap-10">
            {[t('philosophyBody1'), t('philosophyBody2'), t('philosophyBody3')].map(
              (text, i) => (
                <Reveal key={i} delay={i * 0.08}>
                  <span className="font-mono text-[11px] text-taupe">
                    0{i + 1}
                  </span>
                  <p className="mt-4 font-body text-base leading-relaxed text-stone">
                    {text}
                  </p>
                </Reveal>
              )
            )}
          </div>
        </div>
      </section>
    </div>
  );
}
