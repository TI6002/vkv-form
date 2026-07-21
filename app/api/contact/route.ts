import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { Resend } from 'resend';

const resend = new Resend(process.env.RESEND_API_KEY);

console.log(
  'RESEND KEY EXISTS:',
  !!process.env.RESEND_API_KEY
);

console.log(
  'CONTACT EMAIL:',
  process.env.CONTACT_EMAIL
);
export async function POST(req: Request) {
  try {
    const { name, email, message } = await req.json();

    if (!name || !email || !message) {
      return NextResponse.json(
        { error: 'Missing fields' },
        { status: 400 }
      );
    }

    // сохраняем в Supabase
    const supabase = createAdminClient();

    const { error } = await supabase
      .from('contact_messages')
      .insert({
        name,
        email,
        message,
      });

    if (error) throw error;


    // отправляем письмо
    const emailResponse = await resend.emails.send({
  from: 'contact@vkv.form',
  to: process.env.CONTACT_EMAIL!,
  subject: `New message from ${name}`,
  html: `
    <h2>New contact message</h2>
    <p><b>Name:</b> ${name}</p>
    <p><b>Email:</b> ${email}</p>
    <p><b>Message:</b> ${message}</p>
  `,
});

console.log('RESEND RESPONSE:', emailResponse);


    return NextResponse.json({ ok: true });

  } catch (err) {
    console.error('Contact form error:', err);

    return NextResponse.json(
      { error: 'Could not send message' },
      { status: 500 }
    );
  }
}