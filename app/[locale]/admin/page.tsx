import { unstable_setRequestLocale } from 'next-intl/server';
import { checkAdminAccess } from '@/lib/auth';
import { AdminDashboard } from '@/components/AdminDashboard';
import { Link } from '@/lib/navigation';

const messages: Record<string, string> = {
  'no-session':
    'You are not signed in. Go to /account and sign in with the exact email + password of the account you promoted to admin.',
  'no-profile-row':
    "You're signed in, but there's no matching row in the profiles table for this account. This shouldn't normally happen (a row is created automatically on sign-up) — check Table Editor → profiles for a row with your user's id.",
  'not-admin':
    "You're signed in, but this account's role in the profiles table isn't set to admin yet. Table Editor → profiles → find your row → set role to admin (exactly, lowercase) → save, then reload this page.",
  'supabase-error':
    "Couldn't reach Supabase. This almost always means .env.local is missing NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY, or you edited .env.local but didn't restart `npm run dev` afterwards (env files are only read when the server starts).",
};

export default async function AdminPage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);

  const result = await checkAdminAccess();

  if (!result.ok) {
    return (
      <div className="mx-auto max-w-[1400px] px-6 py-28 md:px-10">
        <p className="font-mono text-[11px] uppercase tracking-widest2 text-taupe">
          Admin access — {result.reason}
        </p>
        <p className="mt-4 max-w-xl font-body text-stone">{messages[result.reason]}</p>
        {result.detail && (
          <p className="mt-4 max-w-xl font-mono text-xs text-red-800">{result.detail}</p>
        )}
        {result.reason === 'no-session' && (
          <Link
            href="/account"
            className="mt-6 inline-block font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
          >
            Go to /account →
          </Link>
        )}
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-[1400px] px-6 py-16 md:px-10 md:py-20">
      <h1 className="font-display text-3xl text-ink">Studio admin</h1>
      <p className="mt-2 font-body text-sm text-stone">Signed in as {result.profile.email}</p>
      <div className="mt-12">
        <AdminDashboard />
      </div>
    </div>
  );
}