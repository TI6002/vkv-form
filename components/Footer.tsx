import { useTranslations } from 'next-intl';
import { Link } from '@/lib/navigation';
import { NewsletterForm } from './NewsletterForm';
import { Instagram, Facebook } from 'lucide-react';

export function Footer() {
  const t = useTranslations('footer');
  const tn = useTranslations('nav');

  return (
    <footer className="border-t border-line bg-cream">
      <div className="mx-auto max-w-[1400px] px-6 py-7 md:px-10 md:py-8">
        <div className="grid gap-8 md:grid-cols-[1.3fr_1fr_1fr]">
          <div>
            <p className="font-display text-base uppercase italic text-cocoa">vkv.form</p>
            
          </div>

          <div>
            <p className="font-mono text-[10px] uppercase tracking-widest2 text-stone">
              {tn('catalog')}
            </p>
            <nav className="mt-2 flex flex-col gap-1.5">
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
            <div className="mt-2 flex gap-4">
              <a
                href="https://www.instagram.com/vkv.form?igsh=b244OG1yd2Vja2d3"
                target="_blank"
                rel="noreferrer"
                aria-label="Instagram"
                className="text-ink hover:text-stone"
              >
                <Instagram size={16} strokeWidth={1.5} />
              </a>
              <a
                href="https://www.facebook.com/share/1BcSUJmHiN/"
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

        <div className="mt-6 flex flex-col-reverse items-start justify-between gap-2 border-t border-line pt-3 md:flex-row md:items-center">
          <p className="font-mono text-[10px] uppercase tracking-widest2 text-stone">
            © {new Date().getFullYear()} VKV.FORM — {t('rights')}
          </p>
        </div>
      </div>
    </footer>
  );
}
