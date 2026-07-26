import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import Image from 'next/image';
import { Link } from '@/lib/navigation';
import { Reveal } from '@/components/Reveal';
import { getAboutContent, getAboutPosts } from '@/lib/content';
import { pickLocalized } from '@/lib/localized';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function AboutPage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('about');
  const [content, posts] = await Promise.all([getAboutContent(), getAboutPosts()]);

  // The client can edit any of these from /admin → About. Anything they
  // haven't touched yet falls back to the built-in copy below, so the
  // page is never missing text.
  const text = (key: string, fallback: string) => {
    const value = content[key];
    if (!value || Object.keys(value).length === 0) return fallback;
    return pickLocalized(value, locale) || fallback;
  };

  const authorTitle = text('authorTitle', t('authorTitle'));
  const authorBody1 = text('authorBody1', t('authorBody1'));
  const authorBody2 = text('authorBody2', t('authorBody2'));
  const philosophyTitle = text('philosophyTitle', t('philosophyTitle'));
  const philosophyBody1 = text('philosophyBody1', t('philosophyBody1'));
  const philosophyBody2 = text('philosophyBody2', t('philosophyBody2'));
  const philosophyBody3 = text('philosophyBody3', t('philosophyBody3'));

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
            <div className="relative aspect-[3/4] bg-sand">
              <Image
                src="/images/about-author.png"
                alt=""
                fill
                sizes="(min-width: 768px) 45vw, 100vw"
                className="object-cover"
              />
            </div>
          </Reveal>
          <Reveal delay={0.1}>
            <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              {t('authorEyebrow')}
            </p>
            <h2 className="mt-4 font-display text-3xl text-ink md:text-4xl">{authorTitle}</h2>
            <p className="mt-6 font-body text-base leading-relaxed text-stone">{authorBody1}</p>
            <p className="mt-5 font-body text-base leading-relaxed text-stone">{authorBody2}</p>
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
              {philosophyTitle}
            </h2>
          </Reveal>

          <div className="mt-14 grid gap-10 md:grid-cols-3 md:gap-10">
            {[philosophyBody1, philosophyBody2, philosophyBody3].map((body, i) => (
              <Reveal key={i} delay={i * 0.08}>
                <span className="font-mono text-[11px] text-taupe">0{i + 1}</span>
                <p className="mt-4 font-body text-base leading-relaxed text-stone">{body}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* Journal — the studio's growing collection of posts, editable from /admin */}
      {posts.length > 0 && (
        <section className="bg-white">
          <div className="mx-auto max-w-[1400px] px-6 py-20 md:px-10 md:py-28">
            <Reveal>
              <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
                {t('journalEyebrow')}
              </p>
              <h2 className="mt-4 font-display text-3xl text-ink md:text-4xl">
                {t('journalTitle')}
              </h2>
            </Reveal>

            <div className="mt-14 grid grid-cols-1 gap-x-8 gap-y-16 sm:grid-cols-2 md:grid-cols-3">
              {posts.map((post, i) => {
                const title = pickLocalized(post.title, locale);
                const body = pickLocalized(post.body, locale);
                const EXCERPT_LIMIT = 220;
                const isLong = body.length > EXCERPT_LIMIT;
                const excerpt = isLong
                  ? body.slice(0, body.lastIndexOf(' ', EXCERPT_LIMIT)) + '…'
                  : body;

                return (
                  <Reveal key={post.id} delay={(i % 3) * 0.06}>
                    <article>
                      {post.images?.[0] && (
                        <div className="relative aspect-[4/3] overflow-hidden bg-sand">
                          <Image
                            src={post.images[0]}
                            alt={title}
                            fill
                            sizes="(min-width: 768px) 33vw, 50vw"
                            className="object-cover"
                          />
                        </div>
                      )}
                      <p className="mt-4 font-mono text-[10px] uppercase tracking-widest2 text-taupe">
                        {new Date(post.created_at).toLocaleDateString(locale, {
                          year: 'numeric',
                          month: 'long',
                          day: 'numeric',
                        })}
                      </p>
                      <h3 className="mt-2 font-display text-xl text-ink">{title}</h3>
                      <p className="mt-3 whitespace-pre-line font-body text-sm leading-relaxed text-stone">
                        {excerpt}
                      </p>
                      {isLong && (
                        <Link
                          href={`/about/journal/${post.id}`}
                          className="mt-3 inline-block font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
                        >
                          {t('readMore')}
                        </Link>
                      )}
                    </article>
                  </Reveal>
                );
              })}
            </div>
          </div>
        </section>
      )}
    </div>
  );
}
