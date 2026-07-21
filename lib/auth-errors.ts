export type AuthErrorKey =
  | 'invalidCredentials'
  | 'emailNotConfirmed'
  | 'alreadyRegistered'
  | 'weakPassword'
  | 'rateLimited'
  | 'generic';

/** Supabase always returns its auth error messages in English — this maps
 * the known ones to a translation key so AuthForm can show them in
 * whatever language the site is currently in. */
export function mapAuthError(message: string): AuthErrorKey {
  const m = (message || '').toLowerCase();
  if (m.includes('invalid login credentials')) return 'invalidCredentials';
  if (m.includes('email not confirmed')) return 'emailNotConfirmed';
  if (m.includes('already registered') || m.includes('already exists')) return 'alreadyRegistered';
  if (m.includes('password should be at least') || m.includes('password is too short')) return 'weakPassword';
  if (m.includes('rate limit') || m.includes('security purposes')) return 'rateLimited';
  return 'generic';
}