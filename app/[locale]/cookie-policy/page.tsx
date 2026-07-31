import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { Reveal } from '@/components/Reveal';

export default async function CookiePolicyPage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('cookiePolicy');

  return (
    <div className="mx-auto max-w-[800px] px-6 py-20 md:px-10 md:py-28">
      <Reveal>
        <h1 className="font-display text-4xl italic text-ink md:text-5xl">{t('title')}</h1>
        <p className="mt-4 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
          {t('lastUpdated')}
        </p>

        <div className="mt-10 flex flex-col gap-8 font-body text-base leading-relaxed text-stone">
          <p>{t('intro')}</p>

          <section>
            <h2 className="font-display text-xl text-ink">{t('essentialTitle')}</h2>
            <p className="mt-3">{t('essentialBody')}</p>
          </section>

          <section>
            <h2 className="font-display text-xl text-ink">{t('localStorageTitle')}</h2>
            <p className="mt-3">{t('localStorageBody')}</p>
          </section>

          <section>
            <h2 className="font-display text-xl text-ink">{t('thirdPartyTitle')}</h2>
            <p className="mt-3">{t('thirdPartyBody')}</p>
          </section>

          <section>
            <h2 className="font-display text-xl text-ink">{t('rightsTitle')}</h2>
            <p className="mt-3">{t('rightsBody')}</p>
          </section>

          <section>
            <h2 className="font-display text-xl text-ink">{t('contactTitle')}</h2>
            <p className="mt-3">{t('contactBody')}</p>
          </section>
        </div>
      </Reveal>
    </div>
  );
}
