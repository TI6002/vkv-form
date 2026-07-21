import { useTranslations } from 'next-intl';
import { Link } from '@/lib/navigation';
import { NewsletterForm } from './NewsletterForm';
import { Instagram, Facebook } from 'lucide-react';

export function Footer() {
  const t = useTranslations('footer');
  const tn = useTranslations('nav');

  return (
    <footer className="border-t border-line bg-cream">
      <div className="mx-auto max-w-[1400px] px-6 py-10 md:px-10 md:py-12">
        <div className="grid gap-10 md:grid-cols-[1.3fr_1fr_1fr]">
          <div>
            <p className="font-display text-lg italic text-cocoa">vkv.form</p>
            <p className="mt-3 max-w-xs font-body text-xs leading-relaxed text-stone">
              {t('newsletterBody')}
            </p>
            <div className="mt-4">
              <NewsletterForm />
            </div>
          </div>

          <div>
            <p className="font-mono text-[10px] uppercase tracking-widest2 text-stone">
              {tn('catalog')}
            </p>
            <nav className="mt-3 flex flex-col gap-2">
              <Link href="/catalog" className="font-body text-sm text-ink hover:text-stone">
                {tn('catalog')}
              </Link>
              <Link href="/about" className="font-body text-sm text-ink hover:text-stone">
                {tn('about')}
              </Link>
              <Link href="/contact" className="font-body text-sm text-ink hover:text-stone">
                {tn('contact')}
              </Link>
            </nav>
          </div>

          <div>
            <p className="font-mono text-[10px] uppercase tracking-widest2 text-stone">
              Studio
            </p>
            <div className="mt-3 flex gap-4">
              <a
                href="https://www.instagram.com/vkv.form"
                target="_blank"
                rel="noreferrer"
                aria-label="Instagram"
                className="text-ink hover:text-stone"
              >
                <Instagram size={16} strokeWidth={1.5} />
              </a>
              <a
                href="https://www.facebook.com"
                target="_blank"
                rel="noreferrer"
                aria-label="Facebook"
                className="text-ink hover:text-stone"
              >
                <Facebook size={16} strokeWidth={1.5} />
              </a>
            </div>
          </div>
        </div>

        <div className="mt-8 flex flex-col-reverse items-start justify-between gap-3 border-t border-line pt-4 md:flex-row md:items-center">
          <p className="font-mono text-[10px] uppercase tracking-widest2 text-stone">
            © {new Date().getFullYear()} vkv.form — {t('rights')}
          </p>
        </div>
      </div>
    </footer>
  );
}
