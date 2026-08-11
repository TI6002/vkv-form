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

  // authorBody is one free-form field — the admin separates paragraphs
  // with a blank line (press Enter twice), same as writing in a normal
  // text editor. Falls back to the older authorBody1/authorBody2 fields
  // (from before this was a single field) if authorBody was never saved.
  const legacyBody1 = text('authorBody1', '');
  const legacyBody2 = text('authorBody2', '');
  const legacyCombined = [legacyBody1, legacyBody2].filter(Boolean).join('\n\n');
  const authorBodyFallback = legacyCombined || `${t('authorBody1')}\n\n${t('authorBody2')}`;
  const authorBody = text('authorBody', authorBodyFallback);

  const authorParagraphs = authorBody
    .split(/\n\s*\n/)
    .map((p) => p.trim())
    .filter(Boolean);

  // Split the author text roughly in half so it can sit next to two
  // photos: the quote + first half runs next to photo #1, the rest
  // runs next to photo #2 further down the page. If the admin edits
  // the text later, this split recalculates automatically — no code
  // change needed.
  const splitIndex = Math.ceil(authorParagraphs.length / 2);
  const firstHalf = authorParagraphs.slice(0, splitIndex);
  const secondHalf = authorParagraphs.slice(splitIndex);

  return (
    <div>
      <section className="mx-auto max-w-[1400px] px-6 pt-20 pb-8 md:px-10 md:pt-28">
        <Reveal>
          <h1 className="font-display text-5xl italic text-ink md:text-6xl">{t('title')}</h1>
        </Reveal>
      </section>

      {/* Author — part 1: photo left, quote + first half of the text right */}
      <section className="mx-auto max-w-[1400px] px-6 py-16 md:px-10 md:py-24">
        <div className="grid gap-12 md:grid-cols-[0.9fr_1.1fr] md:gap-20">
          <Reveal>
            <div className="relative aspect-[3/4] bg-sand">
              <Image
                src="/images/about-author.jpg"
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

            <blockquote className="relative mt-8 max-w-2xl border-l-2 border-cocoa pl-7">
              <span
                aria-hidden
                className="pointer-events-none absolute -left-2 -top-8 select-none font-display text-[7rem] italic leading-none text-cocoa/25"
              >
                &ldquo;
              </span>
              <p className="relative font-display text-3xl italic leading-snug text-ink md:text-[2.6rem]">
                {authorTitle}
              </p>
            </blockquote>

            {firstHalf.length > 0 && (
              <div className="mt-10 max-w-2xl space-y-5 border-l border-line pl-6">
                {firstHalf.map((paragraph, i) => (
                  <p
                    key={i}
                    className="whitespace-pre-wrap font-body text-base leading-relaxed text-stone [tab-size:2]"
                  >
                    {paragraph}
                  </p>
                ))}
              </div>
            )}
          </Reveal>
        </div>
      </section>

      {/* Author — part 2: rest of the text left, photo right */}
      {secondHalf.length > 0 && (
        <section className="mx-auto max-w-[1400px] px-6 pb-16 md:px-10 md:pb-24">
          <div className="grid gap-12 md:grid-cols-[1.1fr_0.9fr] md:gap-20">
            <Reveal>
              <div className="max-w-2xl space-y-5 border-l border-line pl-6 md:mt-2">
                {secondHalf.map((paragraph, i) => (
                  <p
                    key={i}
                    className="whitespace-pre-wrap font-body text-base leading-relaxed text-stone [tab-size:2]"
                  >
                    {paragraph}
                  </p>
                ))}
              </div>
            </Reveal>
            <Reveal delay={0.1}>
              <div className="relative aspect-[3/4] bg-sand">
                <Image
                  src="/images/about-author-2.jpg"
                  alt=""
                  fill
                  sizes="(min-width: 768px) 45vw, 100vw"
                  className="object-cover"
                />
              </div>
            </Reveal>
          </div>
        </section>
      )}

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
                        <div className="relative aspect-[4/5] overflow-hidden bg-sand">
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
