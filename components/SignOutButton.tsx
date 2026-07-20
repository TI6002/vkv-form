'use client';

import { useTranslations } from 'next-intl';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';

export function SignOutButton() {
  const t = useTranslations('account');
  const router = useRouter();

  async function handleSignOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.refresh();
  }

  return (
    <button
      onClick={handleSignOut}
      className="font-mono text-[11px] uppercase tracking-widest2 text-stone underline underline-offset-4 hover:text-ink"
    >
      {t('signOut')}
    </button>
  );
}
