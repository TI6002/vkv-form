import { notFound } from 'next/navigation';
import Image from 'next/image';
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { Link } from '@/lib/navigation';
import { Reveal } from '@/components/Reveal';
import { getAboutPostById } from '@/lib/content';
import { pickLocalized } from '@/lib/localized';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function JournalPostPage({
  params: { locale, id },
}: {
  params: { locale: string; id: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('about');
  const post = await getAboutPostById(id);
  if (!post) notFound();

  const title = pickLocalized(post.title, locale);
  const body = pickLocalized(post.body, locale);

  return (
    <div className="mx-auto max-w-[800px] px-6 py-16 md:px-10 md:py-24">
      <Link
        href="/about"
        className="font-mono text-[11px] uppercase tracking-widest2 text-stone hover:text-ink"
      >
        ← {t('title')}
      </Link>

      <Reveal>
        {post.images?.[0] && (
          <div className="relative mt-8 aspect-[16/10] overflow-hidden bg-sand">
            <Image
              src={post.images[0]}
              alt={title}
              fill
              priority
              sizes="800px"
              className="object-cover"
            />
          </div>
        )}

        <p className="mt-8 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
          {new Date(post.created_at).toLocaleDateString(locale, {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
          })}
        </p>
        <h1 className="mt-3 font-display text-3xl text-ink md:text-4xl">{title}</h1>
        <p className="mt-6 whitespace-pre-line font-body text-base leading-relaxed text-stone">
          {body}
        </p>

        {post.images && post.images.length > 1 && (
          <div className="mt-10 grid grid-cols-2 gap-4 sm:grid-cols-3">
            {post.images.slice(1).map((src) => (
              <div key={src} className="relative aspect-square bg-sand">
                <Image src={src} alt="" fill sizes="260px" className="object-cover" />
              </div>
            ))}
          </div>
        )}
      </Reveal>
    </div>
  );
}
