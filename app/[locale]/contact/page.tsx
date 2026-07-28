import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { Reveal } from '@/components/Reveal';

export default async function ContactPage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('contact');

  // Fill these in .env.local — see README "Studio details" section.
  const details = {
    company: process.env.NEXT_PUBLIC_STUDIO_COMPANY_NAME || 'vkv.form SIA',
    reg: process.env.NEXT_PUBLIC_STUDIO_REG_NUMBER || 'add your registration number',
    vat: process.env.NEXT_PUBLIC_STUDIO_VAT_NUMBER || 'add your VAT number',
    address: process.env.NEXT_PUBLIC_STUDIO_ADDRESS || 'Burtnieku Street 33, Riga, Latvia',
    email: process.env.NEXT_PUBLIC_STUDIO_EMAIL || 'vkv.form.info@gmail.com',
    phone: process.env.NEXT_PUBLIC_STUDIO_PHONE || '+371 20509471',
  };

  const mapQuery = encodeURIComponent(details.address);

  return (
    <div className="mx-auto max-w-[1400px] px-6 py-20 md:px-10 md:py-28">
      <Reveal>
        <h1 className="font-display text-5xl italic text-ink md:text-6xl">{t('title')}</h1>
        <p className="mt-6 max-w-lg font-body text-base leading-relaxed text-stone">
          {t('intro')}
        </p>
      </Reveal>

      <div className="mt-16 grid gap-16 md:grid-cols-2 md:gap-24">
        <Reveal>
          <div className="relative aspect-[4/3] w-full overflow-hidden bg-sand md:aspect-square">
            <iframe
              title="Studio location"
              src={`https://www.google.com/maps?q=${mapQuery}&output=embed`}
              className="absolute inset-0 h-full w-full border-0"
              loading="lazy"
              referrerPolicy="no-referrer-when-downgrade"
            />
          </div>
        </Reveal>

        <Reveal delay={0.1}>
          <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
            {t('detailsTitle')}
          </p>
          <dl className="mt-6 space-y-4 border-t border-line pt-6">
            <Row label={t('companyName')} value={details.company} />
            <Row label={t('regNumber')} value={details.reg} />
            <Row label={t('vatNumber')} value={details.vat} />
            <Row label={t('address')} value={details.address} />
            <Row
              label={t('email')}
              value={details.email}
              href={`mailto:${details.email}`}
            />
            <Row label={t('phone')} value={details.phone} href={`tel:${details.phone.replace(/\s+/g, '')}`} />
          </dl>

          <p className="mt-10 font-mono text-[11px] uppercase tracking-widest2 text-stone">
            {t('follow')}
          </p>
          <div className="mt-3 flex flex-col gap-1.5">
            <a
              href="https://www.instagram.com/vkv.form"
              target="_blank"
              rel="noreferrer"
              className="font-body text-sm text-ink underline underline-offset-4"
            >
              Instagram — @vkv.form
            </a>
          </div>
        </Reveal>
      </div>
    </div>
  );
}

function Row({ label, value, href }: { label: string; value: string; href?: string }) {
  return (
    <div className="flex gap-4">
      <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
        {label}
      </dt>
      <dd className="font-body text-sm text-ink">
        {href ? (
          <a href={href} className="underline underline-offset-4 hover:text-stone">
            {value}
          </a>
        ) : (
          value
        )}
      </dd>
    </div>
  );
}
