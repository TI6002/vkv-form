import { createClient } from '@/lib/supabase/server';

export type AdminCheckResult =
  | { ok: true; profile: { id: string; email: string; role: string } }
  | { ok: false; reason: 'no-session' | 'no-profile-row' | 'not-admin' | 'supabase-error'; detail?: string };

/**
 * Returns the signed-in user's profile (with role) or null.
 * "Admin" is just a row in public.profiles with role = 'admin' —
 * see supabase/schema.sql. Promote your own account by hand once
 * in the Supabase Table Editor after your first sign-up.
 */
export async function getCurrentProfile() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, email, role')
    .eq('id', user.id)
    .single();

  return profile ?? null;
}

export async function requireAdmin() {
  const profile = await getCurrentProfile();
  return profile?.role === 'admin' ? profile : null;
}

/**
 * Same check as requireAdmin(), but tells you *why* it failed instead of
 * just returning null. Use this on /admin so a misconfigured .env.local,
 * a missing profiles row, or a role that isn't literally "admin" all show
 * a different, actionable message instead of one generic "not allowed".
 */
export async function checkAdminAccess(): Promise<AdminCheckResult> {
  try {
    const supabase = createClient();
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError) return { ok: false, reason: 'supabase-error', detail: userError.message };
    if (!user) return { ok: false, reason: 'no-session' };

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, email, role')
      .eq('id', user.id)
      .single();

    if (profileError) return { ok: false, reason: 'supabase-error', detail: profileError.message };
    if (!profile) return { ok: false, reason: 'no-profile-row' };
    if (profile.role !== 'admin') return { ok: false, reason: 'not-admin' };

    return { ok: true, profile };
  } catch (err) {
    return {
      ok: false,
      reason: 'supabase-error',
      detail: err instanceof Error ? err.message : String(err),
    };
  }
}
