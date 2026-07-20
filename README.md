# vkv.form

A quiet, editorial e-commerce site for handmade sculptural objects — built with
Next.js, Supabase, Stripe and automated multi-language translation.

This README is written so you can go from this folder to a running site,
then to a live GitHub repo, without guessing anything.

## What's in this repo

- **Home, Catalogue, Product, About (Author + Philosophy), Contact, Account, Admin** —
  all pages from the brief, in `app/[locale]/...`
- **7 languages**: English (default), French, Italian, Spanish, German, Russian,
  Latvian — routed as `/`, `/fr`, `/it`, `/es`, `/de`, `/ru`, `/lv`
- **Automated translation** — you only ever write copy in `messages/en.json`;
  `npm run translate` fills in the rest by machine translation (see below)
- **Supabase** — free, hosted Postgres + Auth + file storage for products,
  customer accounts, orders, contact messages, newsletter signups
- **Stripe Checkout** for card payments (see "About the Payoneer request" below)
- **Admin dashboard** at `/admin` — add/edit/delete products, upload photos,
  no code required once it's set up
- Design: warm cream/beige/black palette, Fraunces + Inter + IBM Plex Mono,
  slow scroll-reveal motion — built after studying 101cph.com and
  Atelier Courbet's artist pages, per your reference links

## Quick start

```bash
npm install
cp .env.example .env.local   # then fill it in — see "Setting up services" below
npm run dev
```

Open http://localhost:3000 — the site works and looks complete immediately,
even before you configure Supabase: the Home and Catalogue pages fall back to
three demo objects (`lib/demo-products.ts`) so you're never looking at an
empty page while wiring things up. Once Supabase is connected, real products
you add in `/admin` replace the demo ones automatically.

## Setting up services (all free to start)

### 1. Supabase — your database, accounts, and image storage
1. Create a free project at supabase.com (no credit card required).
2. Project Settings → API — copy the **Project URL**, **anon public** key,
   and **service_role** key into `.env.local`.
3. SQL Editor → New query → paste the entire contents of
   `supabase/schema.sql` → Run. This creates every table, security rule,
   and the `product-images` storage bucket in one go.
4. Sign up once through `/account` on your running site.
5. Table Editor → `profiles` → find your row → change `role` to `admin`.
6. Reload `/admin` — you can now add products and upload photos.

Supabase's free tier (500 MB database, 1 GB file storage, 50,000 monthly
active users) comfortably covers a small studio's catalogue and shows no
signs of being deprecated — it's Postgres underneath, so you're never
locked in.

### 2. Stripe — card checkout
Stripe Checkout is what actually does what the brief described (customer
types their card number, pays, done) — see `lib/stripe.ts` for a note on
why Payoneer doesn't fit this role directly.
1. Create a free Stripe account at stripe.com.
2. Developers → API keys → copy the **Secret key** into `.env.local` as
   `STRIPE_SECRET_KEY`, and the **Publishable key** as
   `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`.
3. Developers → Webhooks → Add endpoint → URL
   `https://your-domain.com/api/webhooks/stripe` → event
   `checkout.session.completed` → copy the **Signing secret** into
   `STRIPE_WEBHOOK_SECRET`.
4. Stripe takes a small per-transaction fee (no monthly cost) — there is no
   setup fee to test this in "test mode" using their fake card numbers.

### 3. Studio details for /contact
Fill the `NEXT_PUBLIC_STUDIO_*` variables in `.env.local` with your real
company name, registration number, VAT number and address (реквизиты).

## Automated translation — how it actually works

You write copy exactly once, in English, in `messages/en.json`. Then:

```bash
npm run translate
```

This script (`scripts/translate-missing.mjs`) walks every other locale file
and machine-translates only the strings that are new or missing — anything
you've already hand-edited in `fr.json`, `ru.json`, etc. is left alone, so
polishing one line never gets overwritten by the next run. It uses a free
Google Translate wrapper (no API key needed) to start; if you later want
higher-quality translation, open that file — there's one function,
`translateText()`, to swap for DeepL or Google Cloud Translate's paid API.

The six non-English files already ship with a complete first-pass translation
so the site is fully usable in all seven languages right away — running
`npm run translate` from now on only needs to catch new copy you add later.

## The admin dashboard

`/admin` is only visible to accounts with `role = 'admin'` in the `profiles`
table (step 5 above). From there your client can:
- Add a new object: name, price, stock, description, materials, dimensions
- Upload one or more photos per object (stored in Supabase Storage)
- Edit or delete any existing object

No code, no redeploy needed for day-to-day catalogue updates.

## About the Payoneer request

The brief asked for "введя данные карты" (typing in your card number) via
Payoneer. In practice, Payoneer's products are built for marketplace payouts
and B2B invoicing — they don't offer a drop-in checkout widget where a
customer types their card directly on your site. Stripe Checkout is the
direct equivalent of what was actually described, works in every country on
your list (France, Italy, Spain, Germany, plus the rest of the EU and
beyond), and has no monthly fee. The integration lives entirely in
`lib/stripe.ts` and `app/api/checkout/route.ts` if you want to swap or add a
provider later.

## Project structure

```
app/[locale]/        pages (Home, Catalogue, Product, About, Contact, Account, Admin)
app/api/              Stripe checkout + webhook, contact form endpoint
components/           UI building blocks (Header, Footer, ProductCard, CartDrawer, ...)
context/CartContext   client-side cart state (persisted to localStorage)
lib/                  Supabase clients, Stripe client, product data access, types
messages/             one JSON file per language — en.json is the source of truth
scripts/               translate-missing.mjs — the automated translation script
supabase/schema.sql    the entire database schema, run once
```

## Deploying

The easiest free option is Vercel (made by the Next.js team):
1. Push this repo to GitHub (see below).
2. vercel.com → New Project → import the repo.
3. Paste in the same variables from `.env.local`.
4. Deploy. Then update `NEXT_PUBLIC_SITE_URL` and the Stripe webhook URL to
   your real `.vercel.app` (or custom) domain.

## Getting this into your own GitHub, from VS Code

This zip is a plain folder, not yet a git repository — connect it in a
couple of minutes:

1. Unzip it and open the folder in VS Code.
2. Create a **new, empty** repository on github.com (don't add a README —
   this folder already has one).
3. In VS Code's terminal (`` Ctrl+` ``), from inside the project folder:

   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/<your-username>/<your-repo>.git
   git push -u origin main
   ```
4. Refresh GitHub — everything is there.

From then on it's a completely normal repo: `git add . && git commit -m "..."
&& git push` after any change.

## What's intentionally left for you to finish

- Real product photography (currently placeholder images from picsum.photos)
- Decrementing `stock` automatically when an order is paid (the webhook
  has a comment marking exactly where to add this)
- Sending yourself an email when the contact form is submitted (it currently
  saves to the `contact_messages` table — wire up Resend/Postmark there if
  you want an instant email too)
- A dedicated order-confirmation page (checkout currently redirects to
  `/account`, which lists the new order)

Everything else — routing, styling, animation, i18n, auth, cart, checkout,
admin — is wired up and working.
