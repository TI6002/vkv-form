#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — fix contact route build error..."

mkdir -p "app/api/contact"
cat > "app/api/contact/route.ts" << '__VKV_PATCH_EOF__'
import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';

/**
 * Saves a contact form submission. Uses the admin (service-role) client
 * on purpose — a signed-out visitor filling out this form has no
 * Supabase session, so a client bound to RLS-as-anonymous would need an
 * explicit "anyone can insert" policy on contact_messages, which is an
 * easy thing to forget and leave the form silently broken. The
 * service-role client sidesteps that entirely for this one, low-risk,
 * write-only form.
 */
export async function POST(req: Request) {
  try {
    const { name, email, message } = (await req.json()) as {
      name?: string;
      email?: string;
      message?: string;
    };

    if (!name || !email || !message) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    const supabase = createAdminClient();
    const { error } = await supabase.from('contact_messages').insert({
      name,
      email,
      message,
    });

    if (error) {
      console.error('Failed to save contact message:', error);
      return NextResponse.json({ error: 'Could not save message' }, { status: 500 });
    }

    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error('Contact form error:', err);
    return NextResponse.json({ error: 'Something went wrong' }, { status: 500 });
  }
}
__VKV_PATCH_EOF__
echo "  updated: app/api/contact/route.ts"

echo "Done. git add -A && git commit -m \"Fix contact route type error\" && git push"