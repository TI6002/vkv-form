import { unstable_setRequestLocale } from 'next-intl/server';
import { requireAdmin } from '@/lib/auth';
import { AdminDashboard } from '@/components/AdminDashboard';

export default async function AdminPage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);

  let admin = null;
  try {
    admin = await requireAdmin();
  } catch {
    // Supabase not configured yet.
  }

  if (!admin) {
    return (
      <div className="mx-auto max-w-[1400px] px-6 py-28 md:px-10">
        <p className="font-body text-stone">
          This page is only visible to studio admins. Sign in at{' '}
          <span className="underline">/account</span>, then promote your account to
          <code className="mx-1 rounded bg-sand px-1.5 py-0.5">role = &apos;admin&apos;</code>
          in the Supabase Table Editor (table <code className="rounded bg-sand px-1.5 py-0.5">profiles</code>)
          — see README.md.
        </p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-[1400px] px-6 py-16 md:px-10 md:py-20">
      <h1 className="font-display text-3xl text-ink">Studio admin</h1>
      <div className="mt-12">
        <AdminDashboard />
      </div>
    </div>
  );
}
