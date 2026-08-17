#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — redesign gallery layout, update About page author text on all 7 languages..."

mkdir -p "app/[locale]"
cat > "app/[locale]/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import Image from 'next/image';
import { Link } from '@/lib/navigation';
import { Reveal } from '@/components/Reveal';
import { ProductCard } from '@/components/ProductCard';
import { HeroSlider } from '@/components/HeroSlider';
import { getProducts } from '@/lib/products';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function HomePage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('home');
  const products = (await getProducts()).filter((p) => p.available).slice(0, 3);

  const heroLines = t('heroTitle').split('\n');

  return (
    <div>
      {/*
        Hero slider — 3 slides. The studio's main banner is now first
        (was third) — it shows ONLY the hero title, nothing else, per
        request. The two event slides follow it.

        Event slides use posters that have their own text baked into
        the photo. On phones, a tall/narrow slider box combined with
        object-cover zoomed in and cut that text off at the edges —
        object-contain (mobile) shows the whole poster instead, with a
        small solid-colour margin above/below when needed; from tablet
        width up there's enough room that object-cover (full bleed, no
        margin) looks better, so it switches back at `sm:`.
      */}
      <HeroSlider
        slides={[
          // --- Slide 1: the studio's main banner (moved from 3rd to 1st) ---
          // Only the hero title is shown here — no eyebrow, subtitle or CTA.
          <div key="studio" className="relative h-full w-full">
            <Image
              src="/images/hero.png"
              alt=""
              fill
              priority
              sizes="100vw"
              className="object-cover"
            />
            <div className="relative z-10 flex h-full w-full items-start justify-center pt-14 md:pt-20">
              <div className="mx-auto w-full max-w-[1400px] px-6 text-center md:px-10">
                <div className="mx-auto max-w-2xl">
                  <h1 className="hero-text-outline font-display text-[11vw] leading-[0.98] text-white md:text-[4.4vw]">
                    {heroLines.map((line, i) => (
                      <span key={i} className="block">
                        {i === heroLines.length - 1 ? (
                          <em className="not-italic italic">{line}</em>
                        ) : (
                          line
                        )}
                      </span>
                    ))}
                  </h1>
                </div>
              </div>
            </div>
          </div>,

          // --- Slide 2: Event (photo only — add text/button back if you want them) ---
          <div key="event-1" className="relative h-full w-full bg-ink">
            <Image
              src="/images/event-1.png"
              alt=""
              fill
              sizes="100vw"
              className="object-contain sm:object-cover"
            />
          </div>,

          // --- Slide 3: Event (photo has its own text — just a centered button) ---
          <div key="event-2" className="relative h-full w-full bg-ink">
            <Image
              src="/images/event-2.png"
              alt=""
              fill
              sizes="100vw"
              className="object-contain sm:object-cover"
            />
            <div className="relative z-10 flex h-full w-full items-end justify-center pb-20 md:pb-28">
              <Link
                href="https://www.1000vases.com/about"
                className="border-2 border-white px-12 py-5 font-mono text-sm uppercase tracking-widest2 text-white transition-colors hover:bg-white hover:text-ink"
              >
                Explore
              </Link>
            </div>
          </div>,
        ]}
      />

      {/* Philosophy — white panel */}
      <section className="bg-white">
        <div className="mx-auto max-w-[1400px] px-6 py-28 md:px-10 md:py-36">
          <Reveal>
            <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
              {t('philosophyEyebrow')}
            </p>
          </Reveal>
          <Reveal delay={0.1}>
            <h2 className="mt-6 max-w-2xl font-display text-2xl italic leading-[1.5] text-ink md:text-3xl">
              {t('philosophyTitle')}
            </h2>
          </Reveal>
        </div>
      </section>

      {/*
        Gallery — group shots of pieces styled together (2-3 vases per
        photo), between Philosophy and the catalogue. One wide "accent"
        photo on top, two smaller ones below it side by side — clearer
        visual hierarchy than three equal photos in a row, and the wide
        aspect ratio suits rectangular/landscape photos far better than
        forcing everything into a tall portrait crop. Stacks to one
        column on mobile.

        Swap /images/gallery-1.jpg, gallery-2.jpg, gallery-3.jpg for
        the client's real photos — same folder as hero.png etc.
      */}
      <section className="bg-paper">
        <div className="mx-auto max-w-[1400px] px-6 py-20 md:px-10 md:py-28">
          <div className="flex flex-col gap-6 md:gap-8">
            <Reveal>
              <div className="relative aspect-[16/9] overflow-hidden bg-sand md:aspect-[21/9]">
                <Image
                  src="/images/gallery-1.jpg"
                  alt=""
                  fill
                  sizes="100vw"
                  className="object-cover"
                />
              </div>
            </Reveal>
            <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 md:gap-8">
              <Reveal delay={0.08}>
                <div className="relative aspect-[4/3] overflow-hidden bg-sand">
                  <Image
                    src="/images/gallery-2.jpg"
                    alt=""
                    fill
                    sizes="(min-width: 640px) 50vw, 100vw"
                    className="object-cover"
                  />
                </div>
              </Reveal>
              <Reveal delay={0.16}>
                <div className="relative aspect-[4/3] overflow-hidden bg-sand">
                  <Image
                    src="/images/gallery-3.jpg"
                    alt=""
                    fill
                    sizes="(min-width: 640px) 50vw, 100vw"
                    className="object-cover"
                  />
                </div>
              </Reveal>
            </div>
          </div>
        </div>
      </section>

      {/* Featured catalogue — beige panel, alternating with the white one above */}
      <section className="bg-cream">
        <div className="mx-auto max-w-[1400px] px-6 py-28 md:px-10 md:py-36">
          <Reveal>
            <div className="flex items-end justify-between border-b border-line pb-6">
              <div>
                <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
                  {t('catalogEyebrow')}
                </p>
                <h2 className="mt-3 font-display text-3xl text-ink md:text-4xl">
                  {t('catalogTitle')}
                </h2>
              </div>
              <span className="hidden font-mono text-[11px] uppercase tracking-widest2 text-taupe md:block">
                {t('featuredEyebrow')}
              </span>
            </div>
          </Reveal>

          <div className="mt-12 grid grid-cols-1 gap-x-8 gap-y-14 sm:grid-cols-2 md:grid-cols-3">
            {products.map((p, i) => (
              <Reveal key={p.id} delay={i * 0.08}>
                <ProductCard product={p} index={i} />
              </Reveal>
            ))}
          </div>

          <Reveal delay={0.15}>
            <div className="mt-16 text-center">
              <Link
                href="/catalog"
                className="font-mono text-[11px] uppercase tracking-widest2 text-ink underline underline-offset-4"
              >
                {t('catalogCta')}
              </Link>
            </div>
          </Reveal>
        </div>
      </section>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/page.tsx"

mkdir -p "messages"
cat > "messages/en.json" << '__VKV_PATCH_EOF__'
{
  "nav": {
    "home": "Home",
    "catalog": "Catalogue",
    "about": "About",
    "contact": "Contact",
    "account": "Account",
    "cart": "Cart",
    "search": "Search",
    "collection": "Collection Book"
  },
  "home": {
    "heroEyebrow": "vkv.form — objects in clay, plaster and stone",
    "heroTitle": "Overcoming, which has become a form.",
    "heroSubtitle": "Handmade sculptural objects for considered interiors. Each piece is cast, carved and finished by hand in a small studio, one at a time.",
    "heroCta": "Enter the catalogue",
    "philosophyEyebrow": "Philosophy",
    "philosophyTitle": "We believe that real strength is not always visible. It lives in the ability to go on, to remain yourself, and to take on a new form when the old one is no longer possible.",
    "philosophyBody": "We believe that real strength is not always visible. It lives in the ability to go on, to remain yourself, and to take on a new form when the old one is no longer possible.",
    "catalogEyebrow": "The Collection",
    "catalogTitle": "Recent forms",
    "catalogCta": "View all objects",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "About",
    "authorEyebrow": "The maker",
    "authorTitle": "About the author",
    "authorBody1": "I am a contemporary artist creating sculptural vessels and forms that reveal the idea of rebirth. My work is turned toward the moment when loss ceases to be an ending and becomes the beginning of a new life.\n\nAt the heart of my artistic practice lies my own technique, Lacera, in which, during the process of shaping, the material reveals its own logic: lines of opening arise and form, at times independently of the original intention, as if the form itself finds its way toward tearing, opening, and subsequent joining. Tears, ragged edges and cracks become an integral part of the structure and meaning, where a new wholeness is born not in spite of change, but because of it.\n\nI work primarily with materials that have already passed through a previous life cycle, returning them to the artistic realm in a new capacity. My own paper-based composite clay, which entirely eliminates the firing stage, gives the freedom to create objects with a visually pristine, deeply textured surface. The material itself becomes part of the artistic statement: the idea of rebirth is embodied not only in form, but in matter itself, which takes on a new existence.\n\nEach work invites a silent dialogue about human resilience, inner states, and quiet empathy, revealing the emotional nature of a person. In some works, the composition is complemented by botanical elements, symbolising the continuity of life, the capacity to overcome and to renew.",
    "authorBody2": "",
    "philosophyEyebrow": "Philosophy",
    "philosophyTitle": "Why we make what we make",
    "philosophyBody1": "Modern rooms are full of things that ask for attention. We wanted to make the opposite — objects that settle into a space quietly and reward a longer look rather than a first glance.",
    "philosophyBody2": "That means restraint in colour, honesty in material, and no two pieces that are perfectly identical. A vase with a slightly uneven rim is not a mistake to hide; it is proof that a person, not a mould alone, finished the work.",
    "philosophyBody3": "We work primarily in three families of material — unglazed stoneware, tinted plaster, and soft natural stone — chosen because they age well and because their surface changes gently with light and touch over years of use.",
    "journalEyebrow": "Journal",
    "journalTitle": "Notes from the studio",
    "readMore": "Read more"
  },
  "catalog": {
    "title": "Catalogue",
    "subtitle": "Every object currently in the studio.",
    "empty": "No forms match this filter yet.",
    "priceLabel": "Price",
    "viewProduct": "View object",
    "addToCart": "Add to cart",
    "filterAll": "All"
  },
  "product": {
    "back": "Back to catalogue",
    "descriptionLabel": "Description",
    "materialsLabel": "Materials",
    "dimensionsLabel": "Dimensions",
    "careLabel": "Care",
    "addToCart": "Add to cart",
    "adding": "Adding…",
    "added": "Added",
    "outOfStock": "Currently unavailable",
    "quantityLabel": "Quantity",
    "shippingNote": "Made to order in small batches. Ships from the EU within 5–10 working days.",
    "inStock": "In stock",
    "like": "Save",
    "liked": "Saved",
    "orderNow": "Order now",
    "save": "Save",
    "saved": "Saved",
    "weightLabel": "Weight",
    "heightLabel": "Height",
    "circumferenceLabel": "Circumference",
    "depthLabel": "Depth",
    "widthLabel": "Width"
  },
  "cart": {
    "title": "Your cart",
    "empty": "Your cart is currently empty.",
    "continue": "Continue browsing",
    "subtotal": "Subtotal",
    "checkout": "Proceed to checkout",
    "remove": "Remove",
    "quantity": "Qty",
    "taxNote": "Shipping and any applicable taxes are calculated at checkout."
  },
  "checkout": {
    "title": "Checkout",
    "redirecting": "Taking you to secure checkout…",
    "error": "Something went wrong preparing your order. Please try again.",
    "emailLabel": "Email",
    "payButton": "Pay now"
  },
  "contact": {
    "title": "Contact",
    "intro": "For studio visits, press, stockist enquiries or anything else — Please, write to us directly.",
    "formName": "Name",
    "formEmail": "Email",
    "formMessage": "Message",
    "formSubmit": "Send message",
    "formSuccess": "Thank you — we will reply within a few days.",
    "formError": "The message could not be sent. Please try again or email us directly.",
    "detailsTitle": "Studio details",
    "companyName": "Company",
    "regNumber": "Registration No.",
    "vatNumber": "VAT No.",
    "address": "Address",
    "email": "Email",
    "follow": "Follow the studio",
    "phone": "Phone"
  },
  "account": {
    "signInTitle": "Sign in",
    "signUpTitle": "Create an account",
    "email": "Email",
    "password": "Password",
    "signIn": "Sign in",
    "signUp": "Create account",
    "orSignUp": "New here? Create an account",
    "orSignIn": "Already have an account? Sign in",
    "signOut": "Sign out",
    "ordersTitle": "Profile & Orders",
    "noOrders": "You have no orders yet.",
    "orderNumber": "Order",
    "orderStatus": "Status",
    "orderTotal": "Total",
    "error": "Something went wrong. Please check your details and try again.",
    "activeOrdersTitle": "Active orders",
    "noActiveOrders": "You have no active orders right now.",
    "pastOrdersTitle": "Order history",
    "noPastOrders": "Your order history is empty.",
    "savedTitle": "Saved items",
    "noSaved": "You haven't saved anything yet.",
    "errors": {
      "invalidCredentials": "Incorrect email or password.",
      "emailNotConfirmed": "Please confirm your email before signing in.",
      "alreadyRegistered": "An account with this email already exists — try signing in instead.",
      "weakPassword": "Password should be at least 6 characters.",
      "rateLimited": "Too many attempts — please wait a few minutes and try again.",
      "generic": "Something went wrong. Please check your details and try again."
    },
    "signInRequired": "Please sign in first to do that."
  },
  "admin": {
    "title": "Studio admin",
    "productsTab": "Objects",
    "ordersTab": "Orders",
    "newProduct": "Add new object",
    "name": "Name",
    "slug": "URL slug",
    "price": "Price (EUR)",
    "stock": "Stock",
    "description": "Description",
    "materials": "Materials",
    "dimensions": "Dimensions",
    "images": "Images",
    "uploadImage": "Upload image",
    "save": "Save object",
    "saving": "Saving…",
    "delete": "Delete",
    "edit": "Edit",
    "cancel": "Cancel",
    "confirmDelete": "Delete this object? This cannot be undone.",
    "noProducts": "No objects yet. Add the first one above.",
    "available": "Available for sale"
  },
  "footer": {
    "newsletterTitle": "Notes from the studio",
    "newsletterBody": "Occasional word when a new small batch is ready. No noise in between.",
    "newsletterPlaceholder": "Your email",
    "newsletterCta": "Subscribe",
    "newsletterSuccess": "Subscribed — thank you.",
    "rights": "All rights reserved.",
    "cookiePolicy": "Cookie Policy"
  },
  "common": {
    "loading": "Loading…",
    "currency": "€"
  },
  "collection": {
    "eyebrow": "Archive",
    "title": "Collection Book",
    "intro": "A record of pieces that have already found their homes — kept here as an archive rather than offered for sale again.",
    "empty": "The collection book is empty for now.",
    "soldIn": "Sold in"
  },
  "cookies": {
    "message": "This site uses a small number of essential cookies to keep you signed in and remember your cart — nothing is used for advertising or tracking.",
    "learnMore": "Learn more",
    "accept": "Got it"
  },
  "cookiePolicy": {
    "title": "Cookie Policy",
    "lastUpdated": "Last updated 2026",
    "intro": "This page explains, in plain language, what cookies and similar technologies vkv.form uses and why. We keep this deliberately short because we deliberately use very little.",
    "essentialTitle": "Essential cookies",
    "essentialBody": "When you sign in, our authentication provider (Supabase) sets a secure cookie so the site knows you're signed in as you move between pages. This cookie is strictly necessary for the site to function — without it, you couldn't stay logged in or view your orders — so it doesn't require consent under GDPR, but we mention it here for transparency.",
    "localStorageTitle": "Your cart",
    "localStorageBody": "Items you add to your cart are stored in your browser's local storage, not a cookie, and not on our servers, until you check out. Clearing your browser data will clear your cart.",
    "thirdPartyTitle": "Third parties",
    "thirdPartyBody": "We do not use advertising cookies, tracking pixels, or third-party analytics. When you pay, you are taken to our payment provider's own secure checkout page, which is subject to their own cookie and privacy policy, not ours.",
    "rightsTitle": "Your rights",
    "rightsBody": "Under GDPR, you can ask us what personal data we hold about you, ask us to correct or delete it, and object to how it's processed. Since we store very little (an account email, order history, and anything you've explicitly saved), most requests can be handled quickly.",
    "contactTitle": "Contact",
    "contactBody": "Questions about this policy or your data can be sent to the studio email listed on our Contact page."
  }
}
__VKV_PATCH_EOF__
echo "  updated: messages/en.json"

mkdir -p "messages"
cat > "messages/ru.json" << '__VKV_PATCH_EOF__'
{
  "nav": {
    "home": "Главная",
    "catalog": "Каталог",
    "about": "О нас",
    "contact": "Контакты",
    "account": "Аккаунт",
    "cart": "Корзина",
    "search": "Поиск",
    "collection": "Коллекция"
  },
  "home": {
    "heroEyebrow": "vkv.form — предметы из глины, гипса и камня",
    "heroTitle": "Преодоление, ставшее формой.",
    "heroSubtitle": "Рукотворные скульптурные предметы для продуманных интерьеров. Каждое изделие отливается, вырезается и доводится вручную в небольшой мастерской — по одному.",
    "heroCta": "В каталог",
    "philosophyEyebrow": "Философия",
    "philosophyTitle": "Мы верим, что настоящая сила не всегда заметна. Она живёт в способности продолжать, оставаться собой и обретать новую форму, когда прежняя уже невозможна.",
    "philosophyBody": "Мы верим, что настоящая сила не всегда заметна. Она живёт в способности продолжать, оставаться собой и обретать новую форму, когда прежняя уже невозможна.",
    "catalogEyebrow": "Коллекция",
    "catalogTitle": "Последние формы",
    "catalogCta": "Смотреть все предметы",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "О нас",
    "authorEyebrow": "Автор",
    "authorTitle": "Об авторе",
    "authorBody1": "Я — современный художник, создающий скульптурные сосуды и формы, раскрывающие идею перерождения. Моё творчество обращено к моменту, когда утрата перестаёт быть завершением и становится началом новой жизни.\n\nВ основе моей художественной практики лежит авторская техника Lacera, в которой в процессе формирования материя проявляет собственную логику: линии раскрытия возникают и формируются порой независимо от первоначального замысла, словно сама форма находит свой путь к разрыву, раскрытию и последующему соединению. Разрывы, рваные края и трещины становятся неотъемлемой частью структуры и смысла, где новая целостность рождается не вопреки изменениям, а благодаря им.\n\nЯ работаю преимущественно с материалами, прошедшими предыдущий жизненный цикл, возвращая их в художественное пространство в новом качестве. Авторская композитная глина на бумажной основе, полностью исключающая стадию обжига, даёт свободу создавать объекты с визуально первозданной, глубоко текстурированной поверхностью. Сам материал становится частью художественного высказывания: идея перерождения воплощается не только в форме, но и в материи, обретающей новое существование.\n\nКаждое произведение приглашает к безмолвному диалогу о человеческой стойкости, внутреннем состоянии и тихом сопереживании, раскрывая эмоциональную природу человека. В отдельных работах композицию дополняют ботанические элементы, символизирующие продолжение жизни, способность к преодолению и обновлению.",
    "authorBody2": "",
    "philosophyEyebrow": "Философия",
    "philosophyTitle": "Почему мы делаем то, что делаем",
    "philosophyBody1": "Современные комнаты переполнены вещами, требующими внимания. Мы хотели сделать обратное — предметы, которые тихо занимают своё место в пространстве и вознаграждают долгий взгляд, а не первое впечатление.",
    "philosophyBody2": "Это значит — сдержанность в цвете, честность в материале и отсутствие двух абсолютно одинаковых изделий. Слегка неровный край вазы — не ошибка, которую нужно скрыть, а доказательство того, что работу завершил человек, а не только форма.",
    "philosophyBody3": "Мы работаем в основном с тремя группами материалов — неглазурованная керамика, тонированный гипс и мягкий природный камень — потому что они красиво стареют, и их поверхность мягко меняется от света и прикосновений годами.",
    "journalEyebrow": "Журнал",
    "journalTitle": "Заметки из мастерской",
    "readMore": "Читать дальше"
  },
  "catalog": {
    "title": "Каталог",
    "subtitle": "Все предметы, которые сейчас есть в мастерской.",
    "empty": "По этому фильтру пока ничего нет.",
    "priceLabel": "Цена",
    "viewProduct": "Смотреть предмет",
    "addToCart": "В корзину",
    "filterAll": "Все"
  },
  "product": {
    "back": "Назад в каталог",
    "descriptionLabel": "Описание",
    "materialsLabel": "Материалы",
    "dimensionsLabel": "Размеры",
    "careLabel": "Уход",
    "addToCart": "В корзину",
    "adding": "Добавляем…",
    "added": "Добавлено",
    "outOfStock": "Сейчас недоступно",
    "quantityLabel": "Количество",
    "shippingNote": "Изготавливается на заказ небольшими партиями. Доставка из ЕС занимает 5–10 рабочих дней.",
    "inStock": "В наличии",
    "like": "Сохранить",
    "liked": "Сохранено",
    "orderNow": "Заказать",
    "save": "Сохранить",
    "saved": "Сохранено",
    "weightLabel": "Вес",
    "heightLabel": "Высота",
    "circumferenceLabel": "Окружность",
    "depthLabel": "Глубина",
    "widthLabel": "Ширина"
  },
  "cart": {
    "title": "Ваша корзина",
    "empty": "Ваша корзина пуста.",
    "continue": "Продолжить покупки",
    "subtotal": "Промежуточный итог",
    "checkout": "Перейти к оформлению",
    "remove": "Удалить",
    "quantity": "Кол-во",
    "taxNote": "Доставка и налоги рассчитываются при оформлении заказа."
  },
  "checkout": {
    "title": "Оформление заказа",
    "redirecting": "Переходим к безопасной оплате…",
    "error": "Не удалось оформить заказ. Попробуйте ещё раз.",
    "emailLabel": "Email",
    "payButton": "Оплатить"
  },
  "contact": {
    "title": "Контакты",
    "intro": "По вопросам посещения студии, для представителей прессы, по запросам дистрибьюторов или по любым другим вопросам — пожалуйста, обращайтесь к нам напрямую.",
    "formName": "Имя",
    "formEmail": "Email",
    "formMessage": "Сообщение",
    "formSubmit": "Отправить",
    "formSuccess": "Спасибо — мы ответим в течение нескольких дней.",
    "formError": "Не удалось отправить сообщение. Попробуйте ещё раз или напишите нам на почту.",
    "detailsTitle": "Реквизиты",
    "companyName": "Компания",
    "regNumber": "Рег. номер",
    "vatNumber": "VAT номер",
    "address": "Адрес",
    "email": "Email",
    "follow": "Мастерская в соцсетях",
    "phone": "Телефон"
  },
  "account": {
    "signInTitle": "Вход",
    "signUpTitle": "Создать аккаунт",
    "email": "Email",
    "password": "Пароль",
    "signIn": "Войти",
    "signUp": "Создать аккаунт",
    "orSignUp": "Впервые здесь? Создать аккаунт",
    "orSignIn": "Уже есть аккаунт? Войти",
    "signOut": "Выйти",
    "ordersTitle": "Профиль и заказы",
    "noOrders": "У вас пока нет заказов.",
    "orderNumber": "Заказ",
    "orderStatus": "Статус",
    "orderTotal": "Сумма",
    "error": "Что-то пошло не так. Проверьте данные и попробуйте снова.",
    "activeOrdersTitle": "Активные заказы",
    "noActiveOrders": "Сейчас нет активных заказов.",
    "pastOrdersTitle": "История заказов",
    "noPastOrders": "История заказов пуста.",
    "savedTitle": "Сохранённое",
    "noSaved": "Вы пока ничего не сохранили.",
    "errors": {
      "invalidCredentials": "Неверный email или пароль.",
      "emailNotConfirmed": "Подтвердите email перед входом.",
      "alreadyRegistered": "Аккаунт с таким email уже существует — попробуйте войти.",
      "weakPassword": "Пароль должен содержать не менее 6 символов.",
      "rateLimited": "Слишком много попыток — подождите несколько минут и попробуйте снова.",
      "generic": "Что-то пошло не так. Проверьте данные и попробуйте снова."
    },
    "signInRequired": "Сначала нужно войти в аккаунт."
  },
  "admin": {
    "title": "Админ-панель мастерской",
    "productsTab": "Предметы",
    "ordersTab": "Заказы",
    "newProduct": "Добавить новый предмет",
    "name": "Название",
    "slug": "URL-слаг",
    "price": "Цена (EUR)",
    "stock": "Остаток",
    "description": "Описание",
    "materials": "Материалы",
    "dimensions": "Размеры",
    "images": "Изображения",
    "uploadImage": "Загрузить изображение",
    "save": "Сохранить",
    "saving": "Сохраняем…",
    "delete": "Удалить",
    "edit": "Редактировать",
    "cancel": "Отмена",
    "confirmDelete": "Удалить этот предмет? Это действие необратимо.",
    "noProducts": "Пока нет предметов. Добавьте первый выше.",
    "available": "Доступен для продажи"
  },
  "footer": {
    "newsletterTitle": "Новости мастерской",
    "newsletterBody": "Изредка — весточка, когда готова новая небольшая партия. Без лишнего шума.",
    "newsletterPlaceholder": "Ваш email",
    "newsletterCta": "Подписаться",
    "newsletterSuccess": "Готово — спасибо за подписку.",
    "rights": "Все права защищены.",
    "cookiePolicy": "Политика cookie"
  },
  "common": {
    "loading": "Загрузка…",
    "currency": "€"
  },
  "collection": {
    "eyebrow": "Архив",
    "title": "Книга коллекции",
    "intro": "Летопись предметов, которые уже нашли свой дом — хранится здесь как архив, а не для повторной продажи.",
    "empty": "Книга коллекции пока пуста.",
    "soldIn": "Продано в"
  },
  "cookies": {
    "message": "Сайт использует небольшой набор необходимых файлов cookie, чтобы сохранять вход в аккаунт и корзину — ничего не используется для рекламы или слежки.",
    "learnMore": "Подробнее",
    "accept": "Понятно"
  },
  "cookiePolicy": {
    "title": "Политика использования cookie",
    "lastUpdated": "Обновлено в 2026 году",
    "intro": "На этой странице простым языком объясняется, какие cookie и похожие технологии использует vkv.form и зачем. Мы специально держим это коротко, потому что специально используем их совсем немного.",
    "essentialTitle": "Необходимые cookie",
    "essentialBody": "При входе в аккаунт наш провайдер авторизации (Supabase) устанавливает защищённый cookie-файл, чтобы сайт понимал, что вы вошли, пока вы переходите между страницами. Этот файл строго необходим для работы сайта — без него нельзя оставаться в системе и видеть свои заказы — поэтому по GDPR он не требует согласия, но мы упоминаем его здесь для прозрачности.",
    "localStorageTitle": "Ваша корзина",
    "localStorageBody": "Товары, добавленные в корзину, хранятся в локальном хранилище вашего браузера, а не в cookie и не на наших серверах, до момента оформления заказа. Очистка данных браузера очистит и корзину.",
    "thirdPartyTitle": "Сторонние сервисы",
    "thirdPartyBody": "Мы не используем рекламные cookie, пиксели отслеживания или сторонние аналитические сервисы. При оплате вас перенаправляет на защищённую страницу оплаты нашего платёжного провайдера, которая подчиняется его собственной политике cookie и конфиденциальности, а не нашей.",
    "rightsTitle": "Ваши права",
    "rightsBody": "По GDPR вы можете запросить у нас, какие персональные данные мы храним о вас, попросить исправить или удалить их, а также возразить против их обработки. Поскольку мы храним очень мало данных (email аккаунта, историю заказов и то, что вы явно сохранили), большинство запросов обрабатываются быстро.",
    "contactTitle": "Контакты",
    "contactBody": "Вопросы по этой политике или вашим данным можно направить на email студии, указанный на странице «Контакты»."
  }
}
__VKV_PATCH_EOF__
echo "  updated: messages/ru.json"

mkdir -p "messages"
cat > "messages/fr.json" << '__VKV_PATCH_EOF__'
{
  "nav": {
    "home": "Accueil",
    "catalog": "Catalogue",
    "about": "À propos",
    "contact": "Contact",
    "account": "Compte",
    "cart": "Panier",
    "search": "Recherche",
    "collection": "Livre de collection"
  },
  "home": {
    "heroEyebrow": "vkv.form — objets en argile, plâtre et pierre",
    "heroTitle": "Le dépassement devenu forme.",
    "heroSubtitle": "Objets sculpturaux faits main pour des intérieurs pensés. Chaque pièce est coulée, sculptée et finie à la main dans un petit atelier, une à une.",
    "heroCta": "Découvrir le catalogue",
    "philosophyEyebrow": "Philosophie",
    "philosophyTitle": "Nous croyons que la vraie force n'est pas toujours visible. Elle réside dans la capacité à continuer, à rester soi-même, et à prendre une nouvelle forme lorsque l'ancienne n'est plus possible.",
    "philosophyBody": "Nous croyons que la vraie force n'est pas toujours visible. Elle réside dans la capacité à continuer, à rester soi-même, et à prendre une nouvelle forme lorsque l'ancienne n'est plus possible.",
    "catalogEyebrow": "La collection",
    "catalogTitle": "Formes récentes",
    "catalogCta": "Voir tous les objets",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "À propos",
    "authorEyebrow": "La créatrice",
    "authorTitle": "À propos de l'auteure",
    "authorBody1": "Je suis une artiste contemporaine créant des vases et formes sculpturales qui révèlent l'idée de renaissance. Mon travail se tourne vers ce moment où la perte cesse d'être une fin et devient le commencement d'une vie nouvelle.\n\nAu cœur de ma pratique artistique se trouve ma technique personnelle, Lacera, dans laquelle, au cours du processus de formation, la matière révèle sa propre logique : les lignes d'ouverture naissent et se forment, parfois indépendamment de l'intention initiale, comme si la forme elle-même trouvait son chemin vers la déchirure, l'ouverture, puis la réunion. Les déchirures, les bords irréguliers et les fissures deviennent une partie intégrante de la structure et du sens, où une nouvelle intégrité naît non pas malgré le changement, mais grâce à lui.\n\nJe travaille principalement avec des matériaux ayant déjà connu un cycle de vie antérieur, les faisant revenir dans l'espace artistique sous une nouvelle forme. Mon argile composite à base de papier, qui élimine entièrement l'étape de cuisson, offre la liberté de créer des objets à la surface visuellement brute et profondément texturée. La matière elle-même devient partie de la déclaration artistique : l'idée de renaissance s'incarne non seulement dans la forme, mais aussi dans la matière, qui acquiert une nouvelle existence.\n\nChaque œuvre invite à un dialogue silencieux sur la résilience humaine, l'état intérieur et l'empathie discrète, révélant la nature émotionnelle de l'être humain. Dans certaines œuvres, la composition est complétée par des éléments botaniques, symbolisant la continuité de la vie, la capacité à surmonter et à se renouveler.",
    "authorBody2": "",
    "philosophyEyebrow": "Philosophie",
    "philosophyTitle": "Pourquoi nous faisons ce que nous faisons",
    "philosophyBody1": "Les intérieurs modernes regorgent d'objets qui réclament de l'attention. Nous avons voulu faire l'inverse — des objets qui s'installent tranquillement dans un espace et récompensent un regard prolongé plutôt qu'un premier coup d'œil.",
    "philosophyBody2": "Cela signifie de la sobriété dans la couleur, de l'honnêteté dans la matière, et jamais deux pièces parfaitement identiques. Un bord de vase légèrement irrégulier n'est pas une erreur à cacher ; c'est la preuve qu'une personne, et non un simple moule, a terminé l'ouvrage.",
    "philosophyBody3": "Nous travaillons principalement trois familles de matériaux — grès non émaillé, plâtre teinté et pierre naturelle tendre — choisis parce qu'ils vieillissent bien et que leur surface évolue doucement avec la lumière et le toucher au fil des années.",
    "journalEyebrow": "Journal",
    "journalTitle": "Notes de l'atelier",
    "readMore": "Lire la suite"
  },
  "catalog": {
    "title": "Catalogue",
    "subtitle": "Tous les objets actuellement en atelier.",
    "empty": "Aucune forme ne correspond encore à ce filtre.",
    "priceLabel": "Prix",
    "viewProduct": "Voir l'objet",
    "addToCart": "Ajouter au panier",
    "filterAll": "Tout"
  },
  "product": {
    "back": "Retour au catalogue",
    "descriptionLabel": "Description",
    "materialsLabel": "Matériaux",
    "dimensionsLabel": "Dimensions",
    "careLabel": "Entretien",
    "addToCart": "Ajouter au panier",
    "adding": "Ajout…",
    "added": "Ajouté",
    "outOfStock": "Actuellement indisponible",
    "quantityLabel": "Quantité",
    "shippingNote": "Fabriqué sur commande en petites séries. Expédié depuis l'UE sous 5 à 10 jours ouvrés.",
    "inStock": "En stock",
    "like": "Enregistrer",
    "liked": "Enregistré",
    "orderNow": "Commander",
    "save": "Enregistrer",
    "saved": "Enregistré",
    "weightLabel": "Poids",
    "heightLabel": "Hauteur",
    "circumferenceLabel": "Circonférence",
    "depthLabel": "Profondeur",
    "widthLabel": "Largeur"
  },
  "cart": {
    "title": "Votre panier",
    "empty": "Votre panier est actuellement vide.",
    "continue": "Continuer la visite",
    "subtotal": "Sous-total",
    "checkout": "Passer à la caisse",
    "remove": "Retirer",
    "quantity": "Qté",
    "taxNote": "Les frais de livraison et taxes applicables sont calculés à la caisse."
  },
  "checkout": {
    "title": "Commande",
    "redirecting": "Redirection vers le paiement sécurisé…",
    "error": "Une erreur est survenue lors de la préparation de votre commande. Veuillez réessayer.",
    "emailLabel": "Email",
    "payButton": "Payer maintenant"
  },
  "contact": {
    "title": "Contact",
    "intro": "Pour les visites d'atelier, les demandes de la presse, les demandes des revendeurs ou toute autre question, n'hésitez pas à nous écrire directement.",
    "formName": "Nom",
    "formEmail": "Email",
    "formMessage": "Message",
    "formSubmit": "Envoyer le message",
    "formSuccess": "Merci — nous répondrons sous quelques jours.",
    "formError": "Le message n'a pas pu être envoyé. Réessayez ou écrivez-nous directement.",
    "detailsTitle": "Coordonnées de l'atelier",
    "companyName": "Société",
    "regNumber": "N° d'immatriculation",
    "vatNumber": "N° de TVA",
    "address": "Adresse",
    "email": "Email",
    "follow": "Suivre l'atelier",
    "phone": "Téléphone"
  },
  "account": {
    "signInTitle": "Se connecter",
    "signUpTitle": "Créer un compte",
    "email": "Email",
    "password": "Mot de passe",
    "signIn": "Se connecter",
    "signUp": "Créer un compte",
    "orSignUp": "Nouveau ici ? Créer un compte",
    "orSignIn": "Déjà un compte ? Se connecter",
    "signOut": "Se déconnecter",
    "ordersTitle": "Profil et commandes",
    "noOrders": "Vous n'avez pas encore de commande.",
    "orderNumber": "Commande",
    "orderStatus": "Statut",
    "orderTotal": "Total",
    "error": "Une erreur est survenue. Vérifiez vos informations et réessayez.",
    "activeOrdersTitle": "Commandes en cours",
    "noActiveOrders": "Vous n'avez aucune commande en cours.",
    "pastOrdersTitle": "Historique des commandes",
    "noPastOrders": "Votre historique de commandes est vide.",
    "savedTitle": "Objets enregistrés",
    "noSaved": "Vous n'avez encore rien enregistré.",
    "errors": {
      "invalidCredentials": "Email ou mot de passe incorrect.",
      "emailNotConfirmed": "Veuillez confirmer votre email avant de vous connecter.",
      "alreadyRegistered": "Un compte existe déjà avec cet email — essayez de vous connecter.",
      "weakPassword": "Le mot de passe doit contenir au moins 6 caractères.",
      "rateLimited": "Trop de tentatives — veuillez patienter quelques minutes et réessayer.",
      "generic": "Une erreur est survenue. Vérifiez vos informations et réessayez."
    },
    "signInRequired": "Veuillez d'abord vous connecter."
  },
  "admin": {
    "title": "Administration de l'atelier",
    "productsTab": "Objets",
    "ordersTab": "Commandes",
    "newProduct": "Ajouter un nouvel objet",
    "name": "Nom",
    "slug": "Slug d'URL",
    "price": "Prix (EUR)",
    "stock": "Stock",
    "description": "Description",
    "materials": "Matériaux",
    "dimensions": "Dimensions",
    "images": "Images",
    "uploadImage": "Téléverser une image",
    "save": "Enregistrer l'objet",
    "saving": "Enregistrement…",
    "delete": "Supprimer",
    "edit": "Modifier",
    "cancel": "Annuler",
    "confirmDelete": "Supprimer cet objet ? Action irréversible.",
    "noProducts": "Aucun objet pour l'instant. Ajoutez le premier ci-dessus.",
    "available": "Disponible à la vente"
  },
  "footer": {
    "newsletterTitle": "Nouvelles de l'atelier",
    "newsletterBody": "Un mot occasionnel lorsqu'une nouvelle petite série est prête. Rien d'autre entre-temps.",
    "newsletterPlaceholder": "Votre email",
    "newsletterCta": "S'abonner",
    "newsletterSuccess": "Abonné — merci.",
    "rights": "Tous droits réservés.",
    "cookiePolicy": "Politique cookies"
  },
  "common": {
    "loading": "Chargement…",
    "currency": "€"
  },
  "collection": {
    "eyebrow": "Archives",
    "title": "Livre de collection",
    "intro": "Un registre des pièces qui ont déjà trouvé leur foyer — conservé ici comme archive plutôt que remis en vente.",
    "empty": "Le livre de collection est vide pour l'instant.",
    "soldIn": "Vendu en"
  },
  "cookies": {
    "message": "Ce site utilise un petit nombre de cookies essentiels pour vous garder connecté(e) et mémoriser votre panier — rien n'est utilisé pour la publicité ou le suivi.",
    "learnMore": "En savoir plus",
    "accept": "Compris"
  },
  "cookiePolicy": {
    "title": "Politique relative aux cookies",
    "lastUpdated": "Mise à jour en 2026",
    "intro": "Cette page explique, en langage simple, quels cookies et technologies similaires vkv.form utilise et pourquoi. Nous restons volontairement brefs, car nous en utilisons volontairement très peu.",
    "essentialTitle": "Cookies essentiels",
    "essentialBody": "Lorsque vous vous connectez, notre fournisseur d'authentification (Supabase) dépose un cookie sécurisé afin que le site sache que vous êtes connecté(e) en naviguant entre les pages. Ce cookie est strictement nécessaire au fonctionnement du site — sans lui, vous ne pourriez pas rester connecté(e) ni consulter vos commandes — il ne nécessite donc pas de consentement au titre du RGPD, mais nous le mentionnons ici par souci de transparence.",
    "localStorageTitle": "Votre panier",
    "localStorageBody": "Les articles ajoutés à votre panier sont stockés dans le stockage local de votre navigateur, pas dans un cookie, et pas sur nos serveurs, jusqu'à la validation de la commande. Effacer les données de votre navigateur effacera aussi votre panier.",
    "thirdPartyTitle": "Tiers",
    "thirdPartyBody": "Nous n'utilisons ni cookies publicitaires, ni pixels de suivi, ni outils d'analyse tiers. Lors du paiement, vous êtes redirigé(e) vers la page de paiement sécurisée de notre prestataire, soumise à sa propre politique de cookies et de confidentialité, distincte de la nôtre.",
    "rightsTitle": "Vos droits",
    "rightsBody": "Conformément au RGPD, vous pouvez nous demander quelles données personnelles nous détenons vous concernant, demander leur correction ou suppression, et vous opposer à leur traitement. Comme nous conservons très peu de données (email du compte, historique des commandes et ce que vous avez explicitement enregistré), la plupart des demandes sont traitées rapidement.",
    "contactTitle": "Contact",
    "contactBody": "Toute question sur cette politique ou vos données peut être envoyée à l'adresse email de l'atelier indiquée sur notre page Contact."
  }
}
__VKV_PATCH_EOF__
echo "  updated: messages/fr.json"

mkdir -p "messages"
cat > "messages/es.json" << '__VKV_PATCH_EOF__'
{
  "nav": {
    "home": "Inicio",
    "catalog": "Catálogo",
    "about": "Sobre nosotros",
    "contact": "Contacto",
    "account": "Cuenta",
    "cart": "Carrito",
    "search": "Buscar",
    "collection": "Libro de colección"
  },
  "home": {
    "heroEyebrow": "vkv.form — objetos en arcilla, yeso y piedra",
    "heroTitle": "La superación convertida en forma.",
    "heroSubtitle": "Objetos escultóricos hechos a mano para interiores pensados con cuidado. Cada pieza se moldea, talla y termina a mano en un pequeño taller, una a una.",
    "heroCta": "Entrar al catálogo",
    "philosophyEyebrow": "Filosofía",
    "philosophyTitle": "Creemos que la verdadera fuerza no siempre es visible. Vive en la capacidad de continuar, de seguir siendo uno mismo y de adoptar una nueva forma cuando la anterior ya no es posible.",
    "philosophyBody": "Creemos que la verdadera fuerza no siempre es visible. Vive en la capacidad de continuar, de seguir siendo uno mismo y de adoptar una nueva forma cuando la anterior ya no es posible.",
    "catalogEyebrow": "La colección",
    "catalogTitle": "Formas recientes",
    "catalogCta": "Ver todos los objetos",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "Sobre nosotros",
    "authorEyebrow": "La autora",
    "authorTitle": "Sobre la autora",
    "authorBody1": "Soy una artista contemporánea que crea vasijas y formas escultóricas que revelan la idea del renacimiento. Mi obra se dirige hacia el momento en que la pérdida deja de ser un final y se convierte en el comienzo de una nueva vida.\n\nEn el centro de mi práctica artística se encuentra mi propia técnica, Lacera, en la cual, durante el proceso de formación, la materia revela su propia lógica: las líneas de apertura surgen y se forman, a veces con independencia de la intención inicial, como si la propia forma encontrara su camino hacia el desgarro, la apertura y la posterior unión. Los desgarros, los bordes irregulares y las grietas se convierten en parte integral de la estructura y el significado, donde una nueva integridad nace no a pesar del cambio, sino gracias a él.\n\nTrabajo principalmente con materiales que ya han atravesado un ciclo de vida anterior, devolviéndolos al espacio artístico con una nueva condición. Mi arcilla compuesta de base de papel, que elimina por completo la etapa de cocción, ofrece la libertad de crear objetos con una superficie visualmente prístina y profundamente texturizada. El propio material se convierte en parte del discurso artístico: la idea del renacimiento se materializa no solo en la forma, sino también en la materia, que adquiere una nueva existencia.\n\nCada obra invita a un diálogo silencioso sobre la resiliencia humana, el estado interior y la empatía discreta, revelando la naturaleza emocional del ser humano. En algunas obras, la composición se complementa con elementos botánicos que simbolizan la continuidad de la vida, la capacidad de superación y de renovación.",
    "authorBody2": "",
    "philosophyEyebrow": "Filosofía",
    "philosophyTitle": "Por qué hacemos lo que hacemos",
    "philosophyBody1": "Los interiores modernos están llenos de objetos que piden atención. Quisimos hacer lo contrario — objetos que se asientan en silencio en un espacio y recompensan una mirada larga en lugar de un primer vistazo.",
    "philosophyBody2": "Eso significa contención en el color, honestidad en el material, y ninguna pieza perfectamente idéntica a otra. Un borde ligeramente irregular en un jarrón no es un error que ocultar; es la prueba de que una persona, y no solo un molde, terminó la obra.",
    "philosophyBody3": "Trabajamos principalmente con tres familias de materiales — gres sin esmaltar, yeso teñido y piedra natural blanda — elegidos porque envejecen bien y su superficie cambia suavemente con la luz y el tacto a lo largo de los años.",
    "journalEyebrow": "Diario",
    "journalTitle": "Notas del taller",
    "readMore": "Leer más"
  },
  "catalog": {
    "title": "Catálogo",
    "subtitle": "Todos los objetos que hay ahora mismo en el taller.",
    "empty": "Ningún objeto coincide todavía con este filtro.",
    "priceLabel": "Precio",
    "viewProduct": "Ver objeto",
    "addToCart": "Añadir al carrito",
    "filterAll": "Todos"
  },
  "product": {
    "back": "Volver al catálogo",
    "descriptionLabel": "Descripción",
    "materialsLabel": "Materiales",
    "dimensionsLabel": "Dimensiones",
    "careLabel": "Cuidado",
    "addToCart": "Añadir al carrito",
    "adding": "Añadiendo…",
    "added": "Añadido",
    "outOfStock": "No disponible por ahora",
    "quantityLabel": "Cantidad",
    "shippingNote": "Hecho por encargo en tiradas pequeñas. Se envía desde la UE en 5–10 días laborables.",
    "inStock": "En stock",
    "like": "Guardar",
    "liked": "Guardado",
    "orderNow": "Pedir ahora",
    "save": "Guardar",
    "saved": "Guardado",
    "weightLabel": "Peso",
    "heightLabel": "Altura",
    "circumferenceLabel": "Circunferencia",
    "depthLabel": "Profundidad",
    "widthLabel": "Ancho"
  },
  "cart": {
    "title": "Tu carrito",
    "empty": "Tu carrito está vacío por ahora.",
    "continue": "Seguir viendo",
    "subtotal": "Subtotal",
    "checkout": "Ir a pagar",
    "remove": "Quitar",
    "quantity": "Cant.",
    "taxNote": "El envío y los impuestos aplicables se calculan al pagar."
  },
  "checkout": {
    "title": "Pago",
    "redirecting": "Te llevamos al pago seguro…",
    "error": "Algo salió mal al preparar tu pedido. Inténtalo de nuevo.",
    "emailLabel": "Email",
    "payButton": "Pagar ahora"
  },
  "contact": {
    "title": "Contacto",
    "intro": "Para visitas al estudio, consultas de prensa, distribuidores o cualquier otro asunto, por favor, escríbenos directamente.",
    "formName": "Nombre",
    "formEmail": "Email",
    "formMessage": "Mensaje",
    "formSubmit": "Enviar mensaje",
    "formSuccess": "Gracias — responderemos en unos días.",
    "formError": "No se pudo enviar el mensaje. Inténtalo de nuevo o escríbenos por email.",
    "detailsTitle": "Datos del taller",
    "companyName": "Empresa",
    "regNumber": "N.º de registro",
    "vatNumber": "N.º de IVA",
    "address": "Dirección",
    "email": "Email",
    "follow": "Sigue al taller",
    "phone": "Teléfono"
  },
  "account": {
    "signInTitle": "Iniciar sesión",
    "signUpTitle": "Crear una cuenta",
    "email": "Email",
    "password": "Contraseña",
    "signIn": "Iniciar sesión",
    "signUp": "Crear cuenta",
    "orSignUp": "¿Nuevo aquí? Crea una cuenta",
    "orSignIn": "¿Ya tienes cuenta? Inicia sesión",
    "signOut": "Cerrar sesión",
    "ordersTitle": "Perfil y pedidos",
    "noOrders": "Todavía no tienes pedidos.",
    "orderNumber": "Pedido",
    "orderStatus": "Estado",
    "orderTotal": "Total",
    "error": "Algo salió mal. Revisa tus datos e inténtalo de nuevo.",
    "activeOrdersTitle": "Pedidos activos",
    "noActiveOrders": "No tienes pedidos activos por ahora.",
    "pastOrdersTitle": "Historial de pedidos",
    "noPastOrders": "Tu historial de pedidos está vacío.",
    "savedTitle": "Guardados",
    "noSaved": "Todavía no has guardado nada.",
    "errors": {
      "invalidCredentials": "Email o contraseña incorrectos.",
      "emailNotConfirmed": "Confirma tu email antes de iniciar sesión.",
      "alreadyRegistered": "Ya existe una cuenta con este email — intenta iniciar sesión.",
      "weakPassword": "La contraseña debe tener al menos 6 caracteres.",
      "rateLimited": "Demasiados intentos — espera unos minutos y vuelve a intentarlo.",
      "generic": "Algo salió mal. Revisa tus datos e inténtalo de nuevo."
    },
    "signInRequired": "Primero inicia sesión para hacer esto."
  },
  "admin": {
    "title": "Administración del taller",
    "productsTab": "Objetos",
    "ordersTab": "Pedidos",
    "newProduct": "Añadir nuevo objeto",
    "name": "Nombre",
    "slug": "Slug de URL",
    "price": "Precio (EUR)",
    "stock": "Existencias",
    "description": "Descripción",
    "materials": "Materiales",
    "dimensions": "Dimensiones",
    "images": "Imágenes",
    "uploadImage": "Subir imagen",
    "save": "Guardar objeto",
    "saving": "Guardando…",
    "delete": "Eliminar",
    "edit": "Editar",
    "cancel": "Cancelar",
    "confirmDelete": "¿Eliminar este objeto? Esta acción no se puede deshacer.",
    "noProducts": "Todavía no hay objetos. Añade el primero arriba.",
    "available": "Disponible para la venta"
  },
  "footer": {
    "newsletterTitle": "Noticias del taller",
    "newsletterBody": "Un mensaje ocasional cuando una nueva tirada pequeña está lista. Nada más entre medias.",
    "newsletterPlaceholder": "Tu email",
    "newsletterCta": "Suscribirse",
    "newsletterSuccess": "Suscrito — gracias.",
    "rights": "Todos los derechos reservados.",
    "cookiePolicy": "Política de cookies"
  },
  "common": {
    "loading": "Cargando…",
    "currency": "€"
  },
  "collection": {
    "eyebrow": "Archivo",
    "title": "Libro de colección",
    "intro": "Un registro de piezas que ya han encontrado su hogar — conservado aquí como archivo y no para la venta.",
    "empty": "El libro de colección está vacío por ahora.",
    "soldIn": "Vendido en"
  },
  "cookies": {
    "message": "Este sitio usa un pequeño número de cookies esenciales para mantenerte conectado(a) y recordar tu carrito — nada se usa para publicidad o seguimiento.",
    "learnMore": "Saber más",
    "accept": "Entendido"
  },
  "cookiePolicy": {
    "title": "Política de cookies",
    "lastUpdated": "Actualizado en 2026",
    "intro": "Esta página explica, en lenguaje sencillo, qué cookies y tecnologías similares usa vkv.form y por qué. Mantenemos esto deliberadamente breve, porque deliberadamente usamos muy pocas.",
    "essentialTitle": "Cookies esenciales",
    "essentialBody": "Al iniciar sesión, nuestro proveedor de autenticación (Supabase) coloca una cookie segura para que el sitio sepa que has iniciado sesión mientras navegas entre páginas. Esta cookie es estrictamente necesaria para el funcionamiento del sitio — sin ella no podrías permanecer conectado(a) ni ver tus pedidos — por lo que no requiere consentimiento bajo el RGPD, pero la mencionamos aquí por transparencia.",
    "localStorageTitle": "Tu carrito",
    "localStorageBody": "Los artículos añadidos a tu carrito se guardan en el almacenamiento local de tu navegador, no en una cookie, y no en nuestros servidores, hasta que finalizas la compra. Borrar los datos del navegador borrará también tu carrito.",
    "thirdPartyTitle": "Terceros",
    "thirdPartyBody": "No usamos cookies publicitarias, píxeles de seguimiento ni analítica de terceros. Al pagar, se te redirige a la página segura de pago de nuestro proveedor, sujeta a su propia política de cookies y privacidad, no a la nuestra.",
    "rightsTitle": "Tus derechos",
    "rightsBody": "Según el RGPD, puedes solicitarnos qué datos personales tenemos sobre ti, pedir que los corrijamos o eliminemos, y oponerte a su tratamiento. Como guardamos muy pocos datos (email de la cuenta, historial de pedidos y lo que hayas guardado explícitamente), la mayoría de solicitudes se resuelven rápido.",
    "contactTitle": "Contacto",
    "contactBody": "Las preguntas sobre esta política o tus datos pueden enviarse al email del taller indicado en nuestra página de Contacto."
  }
}
__VKV_PATCH_EOF__
echo "  updated: messages/es.json"

mkdir -p "messages"
cat > "messages/it.json" << '__VKV_PATCH_EOF__'
{
  "nav": {
    "home": "Home",
    "catalog": "Catalogo",
    "about": "Chi siamo",
    "contact": "Contatti",
    "account": "Account",
    "cart": "Carrello",
    "search": "Cerca",
    "collection": "Libro della collezione"
  },
  "home": {
    "heroEyebrow": "vkv.form — oggetti in argilla, gesso e pietra",
    "heroTitle": "Il superamento che è diventato forma.",
    "heroSubtitle": "Oggetti scultorei fatti a mano per interni curati. Ogni pezzo viene colato, scolpito e rifinito a mano in un piccolo studio, uno alla volta.",
    "heroCta": "Entra nel catalogo",
    "philosophyEyebrow": "Filosofia",
    "philosophyTitle": "Crediamo che la vera forza non sia sempre visibile. Vive nella capacità di continuare, di restare se stessi e di assumere una nuova forma quando quella precedente non è più possibile.",
    "philosophyBody": "Crediamo che la vera forza non sia sempre visibile. Vive nella capacità di continuare, di restare se stessi e di assumere una nuova forma quando quella precedente non è più possibile.",
    "catalogEyebrow": "La collezione",
    "catalogTitle": "Forme recenti",
    "catalogCta": "Vedi tutti gli oggetti",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "Chi siamo",
    "authorEyebrow": "L'autrice",
    "authorTitle": "Chi è l'autrice",
    "authorBody1": "Sono un'artista contemporanea che crea vasi e forme scultoree che rivelano l'idea di rinascita. Il mio lavoro si rivolge al momento in cui la perdita cessa di essere una fine e diventa l'inizio di una nuova vita.\n\nAl centro della mia pratica artistica vi è la mia tecnica personale, Lacera, in cui, durante il processo di formazione, la materia rivela una propria logica: le linee di apertura nascono e si formano, talvolta indipendentemente dall'intenzione iniziale, come se la forma stessa trovasse la propria via verso lo strappo, l'apertura e la successiva unione. Gli strappi, i bordi irregolari e le crepe diventano parte integrante della struttura e del significato, dove una nuova integrità nasce non nonostante il cambiamento, ma grazie ad esso.\n\nLavoro principalmente con materiali che hanno già attraversato un ciclo di vita precedente, restituendoli allo spazio artistico in una nuova veste. La mia argilla composita a base di carta, che elimina completamente la fase di cottura, offre la libertà di creare oggetti dalla superficie visivamente incontaminata e profondamente strutturata. Il materiale stesso diventa parte della dichiarazione artistica: l'idea di rinascita si incarna non solo nella forma, ma anche nella materia, che acquisisce una nuova esistenza.\n\nOgni opera invita a un dialogo silenzioso sulla resilienza umana, lo stato interiore e la silenziosa empatia, rivelando la natura emotiva dell'essere umano. In alcune opere, la composizione è arricchita da elementi botanici, che simboleggiano la continuità della vita, la capacità di superamento e di rinnovamento.",
    "authorBody2": "",
    "philosophyEyebrow": "Filosofia",
    "philosophyTitle": "Perché facciamo ciò che facciamo",
    "philosophyBody1": "Gli interni moderni sono pieni di oggetti che chiedono attenzione. Abbiamo voluto fare l'opposto — oggetti che si posano in silenzio in uno spazio e premiano uno sguardo prolungato più di una prima occhiata.",
    "philosophyBody2": "Questo significa sobrietà nel colore, onestà nel materiale, e nessun pezzo perfettamente identico a un altro. Un bordo leggermente irregolare di un vaso non è un errore da nascondere; è la prova che a finire il lavoro è stata una persona, non solo uno stampo.",
    "philosophyBody3": "Lavoriamo principalmente con tre famiglie di materiali — grès non smaltato, gesso colorato e pietra naturale tenera — scelti perché invecchiano bene e la loro superficie cambia dolcemente con la luce e il tocco nel corso degli anni.",
    "journalEyebrow": "Diario",
    "journalTitle": "Note dallo studio",
    "readMore": "Leggi di più"
  },
  "catalog": {
    "title": "Catalogo",
    "subtitle": "Tutti gli oggetti attualmente in studio.",
    "empty": "Nessuna forma corrisponde ancora a questo filtro.",
    "priceLabel": "Prezzo",
    "viewProduct": "Vedi l'oggetto",
    "addToCart": "Aggiungi al carrello",
    "filterAll": "Tutti"
  },
  "product": {
    "back": "Torna al catalogo",
    "descriptionLabel": "Descrizione",
    "materialsLabel": "Materiali",
    "dimensionsLabel": "Dimensioni",
    "careLabel": "Manutenzione",
    "addToCart": "Aggiungi al carrello",
    "adding": "Aggiunta…",
    "added": "Aggiunto",
    "outOfStock": "Non disponibile al momento",
    "quantityLabel": "Quantità",
    "shippingNote": "Realizzato su ordinazione in piccole serie. Spedizione dall'UE in 5–10 giorni lavorativi.",
    "inStock": "Disponibile",
    "like": "Salva",
    "liked": "Salvato",
    "orderNow": "Ordina ora",
    "save": "Salva",
    "saved": "Salvato",
    "weightLabel": "Peso",
    "heightLabel": "Altezza",
    "circumferenceLabel": "Circonferenza",
    "depthLabel": "Profondità",
    "widthLabel": "Larghezza"
  },
  "cart": {
    "title": "Il tuo carrello",
    "empty": "Il tuo carrello è vuoto.",
    "continue": "Continua a guardare",
    "subtotal": "Subtotale",
    "checkout": "Vai al checkout",
    "remove": "Rimuovi",
    "quantity": "Qtà",
    "taxNote": "Spedizione e tasse applicabili calcolate al checkout."
  },
  "checkout": {
    "title": "Checkout",
    "redirecting": "Reindirizzamento al pagamento sicuro…",
    "error": "Qualcosa è andato storto nella preparazione dell'ordine. Riprova.",
    "emailLabel": "Email",
    "payButton": "Paga ora"
  },
  "contact": {
    "title": "Contatti",
    "intro": "Per visite allo studio, richieste da parte della stampa, informazioni sui rivenditori o qualsiasi altra cosa, vi preghiamo di scriverci direttamente.",
    "formName": "Nome",
    "formEmail": "Email",
    "formMessage": "Messaggio",
    "formSubmit": "Invia messaggio",
    "formSuccess": "Grazie — risponderemo entro pochi giorni.",
    "formError": "Impossibile inviare il messaggio. Riprova o scrivici via email.",
    "detailsTitle": "Dati dello studio",
    "companyName": "Azienda",
    "regNumber": "N. di registrazione",
    "vatNumber": "P. IVA",
    "address": "Indirizzo",
    "email": "Email",
    "follow": "Segui lo studio",
    "phone": "Telefono"
  },
  "account": {
    "signInTitle": "Accedi",
    "signUpTitle": "Crea un account",
    "email": "Email",
    "password": "Password",
    "signIn": "Accedi",
    "signUp": "Crea account",
    "orSignUp": "Nuovo qui? Crea un account",
    "orSignIn": "Hai già un account? Accedi",
    "signOut": "Esci",
    "ordersTitle": "Profilo e ordini",
    "noOrders": "Non hai ancora nessun ordine.",
    "orderNumber": "Ordine",
    "orderStatus": "Stato",
    "orderTotal": "Totale",
    "error": "Qualcosa è andato storto. Controlla i dati e riprova.",
    "activeOrdersTitle": "Ordini attivi",
    "noActiveOrders": "Non hai ordini attivi al momento.",
    "pastOrdersTitle": "Storico ordini",
    "noPastOrders": "Lo storico dei tuoi ordini è vuoto.",
    "savedTitle": "Salvati",
    "noSaved": "Non hai ancora salvato nulla.",
    "errors": {
      "invalidCredentials": "Email o password errati.",
      "emailNotConfirmed": "Conferma la tua email prima di accedere.",
      "alreadyRegistered": "Esiste già un account con questa email — prova ad accedere.",
      "weakPassword": "La password deve contenere almeno 6 caratteri.",
      "rateLimited": "Troppi tentativi — attendi qualche minuto e riprova.",
      "generic": "Qualcosa è andato storto. Controlla i dati e riprova."
    },
    "signInRequired": "Devi prima accedere per farlo."
  },
  "admin": {
    "title": "Amministrazione dello studio",
    "productsTab": "Oggetti",
    "ordersTab": "Ordini",
    "newProduct": "Aggiungi nuovo oggetto",
    "name": "Nome",
    "slug": "Slug URL",
    "price": "Prezzo (EUR)",
    "stock": "Scorte",
    "description": "Descrizione",
    "materials": "Materiali",
    "dimensions": "Dimensioni",
    "images": "Immagini",
    "uploadImage": "Carica immagine",
    "save": "Salva oggetto",
    "saving": "Salvataggio…",
    "delete": "Elimina",
    "edit": "Modifica",
    "cancel": "Annulla",
    "confirmDelete": "Eliminare questo oggetto? L'azione è irreversibile.",
    "noProducts": "Ancora nessun oggetto. Aggiungi il primo qui sopra.",
    "available": "Disponibile per la vendita"
  },
  "footer": {
    "newsletterTitle": "Notizie dallo studio",
    "newsletterBody": "Una parola occasionale quando una nuova piccola serie è pronta. Nient'altro nel frattempo.",
    "newsletterPlaceholder": "La tua email",
    "newsletterCta": "Iscriviti",
    "newsletterSuccess": "Iscritto — grazie.",
    "rights": "Tutti i diritti riservati.",
    "cookiePolicy": "Cookie Policy"
  },
  "common": {
    "loading": "Caricamento…",
    "currency": "€"
  },
  "collection": {
    "eyebrow": "Archivio",
    "title": "Libro della collezione",
    "intro": "Un registro di pezzi che hanno già trovato casa — conservato qui come archivio, non in vendita.",
    "empty": "Il libro della collezione è vuoto per ora.",
    "soldIn": "Venduto nel"
  },
  "cookies": {
    "message": "Questo sito utilizza un piccolo numero di cookie essenziali per mantenerti connesso(a) e ricordare il tuo carrello — nulla viene usato per pubblicità o tracciamento.",
    "learnMore": "Scopri di più",
    "accept": "Ho capito"
  },
  "cookiePolicy": {
    "title": "Cookie Policy",
    "lastUpdated": "Aggiornato nel 2026",
    "intro": "Questa pagina spiega, in modo semplice, quali cookie e tecnologie simili usa vkv.form e perché. Restiamo volutamente brevi, perché ne usiamo volutamente pochissimi.",
    "essentialTitle": "Cookie essenziali",
    "essentialBody": "Quando accedi, il nostro fornitore di autenticazione (Supabase) imposta un cookie sicuro affinché il sito sappia che sei connesso(a) mentre navighi tra le pagine. Questo cookie è strettamente necessario per il funzionamento del sito — senza di esso non potresti restare collegato(a) né vedere i tuoi ordini — quindi non richiede consenso ai sensi del GDPR, ma lo menzioniamo qui per trasparenza.",
    "localStorageTitle": "Il tuo carrello",
    "localStorageBody": "Gli articoli aggiunti al carrello sono salvati nella memoria locale del tuo browser, non in un cookie, e non sui nostri server, fino al completamento dell'ordine. Cancellare i dati del browser cancellerà anche il carrello.",
    "thirdPartyTitle": "Terze parti",
    "thirdPartyBody": "Non utilizziamo cookie pubblicitari, pixel di tracciamento o strumenti di analisi di terze parti. Al momento del pagamento vieni reindirizzato(a) alla pagina di pagamento sicura del nostro fornitore, soggetta alla sua propria informativa su cookie e privacy, non alla nostra.",
    "rightsTitle": "I tuoi diritti",
    "rightsBody": "Secondo il GDPR, puoi chiederci quali dati personali conserviamo su di te, chiederne la correzione o cancellazione, e opporti al loro trattamento. Poiché conserviamo pochissimi dati (email dell'account, storico ordini e ciò che hai esplicitamente salvato), la maggior parte delle richieste viene gestita rapidamente.",
    "contactTitle": "Contatti",
    "contactBody": "Domande su questa policy o sui tuoi dati possono essere inviate all'email dello studio indicata nella pagina Contatti."
  }
}
__VKV_PATCH_EOF__
echo "  updated: messages/it.json"

mkdir -p "messages"
cat > "messages/de.json" << '__VKV_PATCH_EOF__'
{
  "nav": {
    "home": "Start",
    "catalog": "Katalog",
    "about": "Über uns",
    "contact": "Kontakt",
    "account": "Konto",
    "cart": "Warenkorb",
    "search": "Suche",
    "collection": "Sammlungsbuch"
  },
  "home": {
    "heroEyebrow": "vkv.form — Objekte aus Ton, Gips und Stein",
    "heroTitle": "La superación convertida en forma.",
    "heroSubtitle": "Handgefertigte, skulpturale Objekte für durchdachte Innenräume. Jedes Stück wird von Hand gegossen, geschnitzt und veredelt, eines nach dem anderen, in einem kleinen Atelier.",
    "heroCta": "Zum Katalog",
    "philosophyEyebrow": "Philosophie",
    "philosophyTitle": "Wir glauben, dass wahre Stärke nicht immer sichtbar ist. Sie liegt in der Fähigkeit, weiterzumachen, sich selbst treu zu bleiben und eine neue Form anzunehmen, wenn die alte nicht mehr möglich ist.",
    "philosophyBody": "Wir glauben, dass wahre Stärke nicht immer sichtbar ist. Sie liegt in der Fähigkeit, weiterzumachen, sich selbst treu zu bleiben und eine neue Form anzunehmen, wenn die alte nicht mehr möglich ist.",
    "catalogEyebrow": "Die Kollektion",
    "catalogTitle": "Neueste Formen",
    "catalogCta": "Alle Objekte ansehen",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "Über uns",
    "authorEyebrow": "Die Macherin",
    "authorTitle": "Über die Autorin",
    "authorBody1": "Ich bin eine zeitgenössische Künstlerin, die skulpturale Gefäße und Formen schafft, die die Idee der Wiedergeburt offenbaren. Mein Schaffen richtet sich auf den Moment, in dem Verlust aufhört, ein Ende zu sein, und zum Beginn eines neuen Lebens wird.\n\nIm Zentrum meiner künstlerischen Praxis steht meine eigene Technik, Lacera, bei der die Materie während des Formungsprozesses ihre eigene Logik offenbart: Öffnungslinien entstehen und formen sich, mitunter unabhängig von der ursprünglichen Absicht, als fände die Form selbst ihren Weg zum Riss, zur Öffnung und zur anschließenden Verbindung. Risse, ausgefranste Kanten und Sprünge werden zu einem festen Bestandteil von Struktur und Bedeutung, wo eine neue Ganzheit nicht trotz der Veränderung, sondern durch sie entsteht.\n\nIch arbeite vorwiegend mit Materialien, die bereits einen vorherigen Lebenszyklus durchlaufen haben, und führe sie in neuer Gestalt in den künstlerischen Raum zurück. Meine eigene papierbasierte Verbundmasse, die den Brennvorgang vollständig ausschließt, gibt die Freiheit, Objekte mit einer visuell ursprünglichen, tief strukturierten Oberfläche zu schaffen. Das Material selbst wird Teil der künstlerischen Aussage: Die Idee der Wiedergeburt verkörpert sich nicht nur in der Form, sondern auch in der Materie, die eine neue Existenz erlangt.\n\nJedes Werk lädt zu einem stillen Dialog über menschliche Widerstandskraft, innere Zustände und leises Mitgefühl ein und offenbart die emotionale Natur des Menschen. In manchen Arbeiten wird die Komposition durch botanische Elemente ergänzt, die die Kontinuität des Lebens, die Fähigkeit zur Überwindung und zur Erneuerung symbolisieren.",
    "authorBody2": "",
    "philosophyEyebrow": "Philosophie",
    "philosophyTitle": "Warum wir tun, was wir tun",
    "philosophyBody1": "Moderne Räume sind voller Dinge, die Aufmerksamkeit verlangen. Wir wollten das Gegenteil schaffen — Objekte, die sich still in einen Raum einfügen und einen längeren Blick belohnen, nicht nur den ersten.",
    "philosophyBody2": "Das bedeutet Zurückhaltung in der Farbe, Ehrlichkeit im Material und kein Stück, das einem anderen perfekt gleicht. Ein leicht unebener Vasenrand ist kein Fehler, den man verstecken muss — er ist der Beweis, dass ein Mensch die Arbeit vollendet hat, nicht allein eine Gussform.",
    "philosophyBody3": "Wir arbeiten hauptsächlich mit drei Materialfamilien — unglasiertem Steinzeug, eingefärbtem Gips und weichem Naturstein — gewählt, weil sie gut altern und ihre Oberfläche sich über Jahre sanft mit Licht und Berührung verändert.",
    "journalEyebrow": "Journal",
    "journalTitle": "Notizen aus dem Atelier",
    "readMore": "Weiterlesen"
  },
  "catalog": {
    "title": "Katalog",
    "subtitle": "Alle Objekte, die derzeit im Atelier sind.",
    "empty": "Noch keine Form passt zu diesem Filter.",
    "priceLabel": "Preis",
    "viewProduct": "Objekt ansehen",
    "addToCart": "In den Warenkorb",
    "filterAll": "Alle"
  },
  "product": {
    "back": "Zurück zum Katalog",
    "descriptionLabel": "Beschreibung",
    "materialsLabel": "Materialien",
    "dimensionsLabel": "Maße",
    "careLabel": "Pflege",
    "addToCart": "In den Warenkorb",
    "adding": "Wird hinzugefügt…",
    "added": "Hinzugefügt",
    "outOfStock": "Derzeit nicht verfügbar",
    "quantityLabel": "Menge",
    "shippingNote": "Auf Bestellung in kleinen Serien gefertigt. Versand aus der EU innerhalb von 5–10 Werktagen.",
    "inStock": "Auf Lager",
    "like": "Merken",
    "liked": "Gemerkt",
    "orderNow": "Jetzt bestellen",
    "save": "Merken",
    "saved": "Gemerkt",
    "weightLabel": "Gewicht",
    "heightLabel": "Höhe",
    "circumferenceLabel": "Umfang",
    "depthLabel": "Tiefe",
    "widthLabel": "Breite"
  },
  "cart": {
    "title": "Ihr Warenkorb",
    "empty": "Ihr Warenkorb ist derzeit leer.",
    "continue": "Weiter stöbern",
    "subtotal": "Zwischensumme",
    "checkout": "Zur Kasse",
    "remove": "Entfernen",
    "quantity": "Menge",
    "taxNote": "Versand und anfallende Steuern werden an der Kasse berechnet."
  },
  "checkout": {
    "title": "Kasse",
    "redirecting": "Sie werden zur sicheren Kasse weitergeleitet…",
    "error": "Bei der Vorbereitung Ihrer Bestellung ist ein Fehler aufgetreten. Bitte versuchen Sie es erneut.",
    "emailLabel": "E-Mail",
    "payButton": "Jetzt bezahlen"
  },
  "contact": {
    "title": "Kontakt",
    "intro": "Bei Anfragen zu Atelierbesuchen, zur Presse, zu Händlern oder zu sonstigen Themen – bitte wenden Sie sich direkt an uns.",
    "formName": "Name",
    "formEmail": "E-Mail",
    "formMessage": "Nachricht",
    "formSubmit": "Nachricht senden",
    "formSuccess": "Danke — wir antworten innerhalb weniger Tage.",
    "formError": "Die Nachricht konnte nicht gesendet werden. Bitte versuchen Sie es erneut oder schreiben Sie uns direkt eine E-Mail.",
    "detailsTitle": "Atelier-Angaben",
    "companyName": "Unternehmen",
    "regNumber": "Registernummer",
    "vatNumber": "USt-IdNr.",
    "address": "Adresse",
    "email": "E-Mail",
    "follow": "Dem Atelier folgen",
    "phone": "Telefon"
  },
  "account": {
    "signInTitle": "Anmelden",
    "signUpTitle": "Konto erstellen",
    "email": "E-Mail",
    "password": "Passwort",
    "signIn": "Anmelden",
    "signUp": "Konto erstellen",
    "orSignUp": "Neu hier? Konto erstellen",
    "orSignIn": "Schon ein Konto? Anmelden",
    "signOut": "Abmelden",
    "ordersTitle": "Profil & Bestellungen",
    "noOrders": "Sie haben noch keine Bestellungen.",
    "orderNumber": "Bestellung",
    "orderStatus": "Status",
    "orderTotal": "Summe",
    "error": "Etwas ist schiefgelaufen. Bitte überprüfen Sie Ihre Angaben und versuchen Sie es erneut.",
    "activeOrdersTitle": "Aktive Bestellungen",
    "noActiveOrders": "Sie haben derzeit keine aktiven Bestellungen.",
    "pastOrdersTitle": "Bestellverlauf",
    "noPastOrders": "Ihr Bestellverlauf ist leer.",
    "savedTitle": "Gemerkte Objekte",
    "noSaved": "Sie haben noch nichts gemerkt.",
    "errors": {
      "invalidCredentials": "E-Mail oder Passwort ist falsch.",
      "emailNotConfirmed": "Bitte bestätigen Sie Ihre E-Mail, bevor Sie sich anmelden.",
      "alreadyRegistered": "Ein Konto mit dieser E-Mail existiert bereits — versuchen Sie sich anzumelden.",
      "weakPassword": "Das Passwort muss mindestens 6 Zeichen lang sein.",
      "rateLimited": "Zu viele Versuche — bitte warten Sie ein paar Minuten und versuchen Sie es erneut.",
      "generic": "Etwas ist schiefgelaufen. Bitte überprüfen Sie Ihre Angaben und versuchen Sie es erneut."
    },
    "signInRequired": "Bitte melden Sie sich zuerst an."
  },
  "admin": {
    "title": "Atelier-Verwaltung",
    "productsTab": "Objekte",
    "ordersTab": "Bestellungen",
    "newProduct": "Neues Objekt hinzufügen",
    "name": "Name",
    "slug": "URL-Slug",
    "price": "Preis (EUR)",
    "stock": "Bestand",
    "description": "Beschreibung",
    "materials": "Materialien",
    "dimensions": "Maße",
    "images": "Bilder",
    "uploadImage": "Bild hochladen",
    "save": "Objekt speichern",
    "saving": "Wird gespeichert…",
    "delete": "Löschen",
    "edit": "Bearbeiten",
    "cancel": "Abbrechen",
    "confirmDelete": "Dieses Objekt löschen? Das kann nicht rückgängig gemacht werden.",
    "noProducts": "Noch keine Objekte. Fügen Sie oben das erste hinzu.",
    "available": "Verfügbar zum Verkauf"
  },
  "footer": {
    "newsletterTitle": "Neuigkeiten aus dem Atelier",
    "newsletterBody": "Gelegentlich eine Nachricht, wenn eine neue kleine Serie bereit ist. Sonst nichts dazwischen.",
    "newsletterPlaceholder": "Ihre E-Mail",
    "newsletterCta": "Abonnieren",
    "newsletterSuccess": "Abonniert — danke.",
    "rights": "Alle Rechte vorbehalten.",
    "cookiePolicy": "Cookie-Richtlinie"
  },
  "common": {
    "loading": "Wird geladen…",
    "currency": "€"
  },
  "collection": {
    "eyebrow": "Archiv",
    "title": "Sammlungsbuch",
    "intro": "Ein Verzeichnis von Stücken, die bereits ein neues Zuhause gefunden haben — hier als Archiv geführt, nicht zum erneuten Verkauf.",
    "empty": "Das Sammlungsbuch ist derzeit leer.",
    "soldIn": "Verkauft im Jahr"
  },
  "cookies": {
    "message": "Diese Website verwendet eine kleine Anzahl notwendiger Cookies, um Sie angemeldet zu halten und Ihren Warenkorb zu merken — nichts wird für Werbung oder Tracking verwendet.",
    "learnMore": "Mehr erfahren",
    "accept": "Verstanden"
  },
  "cookiePolicy": {
    "title": "Cookie-Richtlinie",
    "lastUpdated": "Zuletzt aktualisiert 2026",
    "intro": "Diese Seite erklärt in einfacher Sprache, welche Cookies und ähnliche Technologien vkv.form verwendet und warum. Wir halten dies bewusst kurz, weil wir bewusst sehr wenige verwenden.",
    "essentialTitle": "Notwendige Cookies",
    "essentialBody": "Beim Anmelden setzt unser Authentifizierungsanbieter (Supabase) ein sicheres Cookie, damit die Website weiß, dass Sie angemeldet sind, während Sie zwischen Seiten wechseln. Dieses Cookie ist für die Funktion der Website unbedingt erforderlich — ohne es könnten Sie nicht angemeldet bleiben oder Ihre Bestellungen einsehen — daher erfordert es nach der DSGVO keine Einwilligung, wir erwähnen es hier jedoch aus Gründen der Transparenz.",
    "localStorageTitle": "Ihr Warenkorb",
    "localStorageBody": "Artikel, die Sie Ihrem Warenkorb hinzufügen, werden im lokalen Speicher Ihres Browsers gespeichert, nicht in einem Cookie und nicht auf unseren Servern, bis Sie zur Kasse gehen. Das Löschen Ihrer Browserdaten löscht auch Ihren Warenkorb.",
    "thirdPartyTitle": "Drittanbieter",
    "thirdPartyBody": "Wir verwenden keine Werbe-Cookies, Tracking-Pixel oder Analysetools von Drittanbietern. Bei der Bezahlung werden Sie zur eigenen sicheren Zahlungsseite unseres Zahlungsanbieters weitergeleitet, die dessen eigener Cookie- und Datenschutzrichtlinie unterliegt, nicht unserer.",
    "rightsTitle": "Ihre Rechte",
    "rightsBody": "Nach der DSGVO können Sie von uns erfragen, welche personenbezogenen Daten wir über Sie speichern, deren Berichtigung oder Löschung verlangen und der Verarbeitung widersprechen. Da wir sehr wenige Daten speichern (Konto-E-Mail, Bestellverlauf und das, was Sie ausdrücklich gespeichert haben), können die meisten Anfragen schnell bearbeitet werden.",
    "contactTitle": "Kontakt",
    "contactBody": "Fragen zu dieser Richtlinie oder Ihren Daten können an die auf unserer Kontaktseite angegebene Atelier-E-Mail gesendet werden."
  }
}
__VKV_PATCH_EOF__
echo "  updated: messages/de.json"

mkdir -p "messages"
cat > "messages/lv.json" << '__VKV_PATCH_EOF__'
{
  "nav": {
    "home": "Sākums",
    "catalog": "Katalogs",
    "about": "Par mums",
    "contact": "Kontakti",
    "account": "Konts",
    "cart": "Grozs",
    "search": "Meklēt",
    "collection": "Kolekcijas grāmata"
  },
  "home": {
    "heroEyebrow": "vkv.form — priekšmeti no māla, ģipša un akmens",
    "heroTitle": "Pārvarēšana, kas kļuvusi par formu.",
    "heroSubtitle": "Rokdarbā veidoti skulpturāli priekšmeti pārdomātām interjera telpām. Katrs darbs tiek liets, tēsts un apdarināts ar rokām nelielā darbnīcā, pa vienam.",
    "heroCta": "Skatīt katalogu",
    "philosophyEyebrow": "Filozofija",
    "philosophyTitle": "Mēs ticam, ka patiess spēks ne vienmēr ir redzams. Tas mīt spējā turpināt, palikt sev uzticīgam un iegūt jaunu formu, kad iepriekšējā vairs nav iespējama.",
    "philosophyBody": "Mēs ticam, ka patiess spēks ne vienmēr ir redzams. Tas mīt spējā turpināt, palikt sev uzticīgam un iegūt jaunu formu, kad iepriekšējā vairs nav iespējama.",
    "catalogEyebrow": "Kolekcija",
    "catalogTitle": "Jaunākās formas",
    "catalogCta": "Skatīt visus priekšmetus",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "Par mums",
    "authorEyebrow": "Autore",
    "authorTitle": "Par autori",
    "authorBody1": "Es esmu mūsdienu māksliniece, kas rada skulpturālus traukus un formas, kas atklāj atdzimšanas ideju. Mans darbs ir vērsts uz brīdi, kad zaudējums vairs nav noslēgums, bet kļūst par jaunas dzīves sākumu.\n\nManas mākslinieciskās prakses centrā ir mana autortehnika Lacera, kurā formas veidošanas procesā matērija atklāj savu iekšējo loģiku: atvēršanās līnijas rodas un veidojas, dažkārt neatkarīgi no sākotnējā nodoma, it kā pati forma atrastu savu ceļu uz plīsumu, atvēršanos un turpmāku savienošanos. Plīsumi, nelīdzenas malas un plaisas kļūst par neatņemamu struktūras un jēgas daļu, kur jauns veselums piedzimst nevis par spīti izmaiņām, bet gan to dēļ.\n\nEs strādāju galvenokārt ar materiāliem, kas jau pieredzējuši iepriekšēju dzīves ciklu, atgriežot tos mākslas telpā jaunā kvalitātē. Mana autora kompozītmāla uz papīra bāzes, kas pilnībā izslēdz apdedzināšanas posmu, dod brīvību radīt objektus ar vizuāli neskartu, dziļi tekstūrētu virsmu. Pats materiāls kļūst par mākslinieciskā izteikuma daļu: atdzimšanas ideja iemiesojas ne tikai formā, bet arī matērijā, kas iegūst jaunu esamību.\n\nKatrs darbs aicina uz klusu dialogu par cilvēka izturību, iekšējo stāvokli un klusu līdzjūtību, atklājot cilvēka emocionālo dabu. Dažos darbos kompozīciju papildina botāniski elementi, kas simbolizē dzīves turpinājumu, spēju pārvarēt grūtības un atjaunoties.",
    "authorBody2": "",
    "philosophyEyebrow": "Filozofija",
    "philosophyTitle": "Kāpēc mēs darām to, ko darām",
    "philosophyBody1": "Mūsdienu telpas ir pilnas ar lietām, kas prasa uzmanību. Mēs gribējām radīt pretējo — priekšmetus, kas telpā iekļaujas klusi un atalgo ilgāku skatienu, nevis pirmo ieskatu.",
    "philosophyBody2": "Tas nozīmē atturību krāsā, godīgumu materiālā un to, ka nav divu pilnīgi vienādu darbu. Vāzes nedaudz nelīdzenā mala nav kļūda, ko slēpt — tā ir pierādījums, ka darbu pabeidza cilvēks, nevis tikai forma.",
    "philosophyBody3": "Mēs galvenokārt strādājam ar trim materiālu grupām — negleznotu akmens masu, tonētu ģipsi un mīkstu dabisko akmeni — izvēlētiem tāpēc, ka tie skaisti noveco, un to virsma gadu gaitā maigi mainās gaismā un pieskārienā.",
    "journalEyebrow": "Žurnāls",
    "journalTitle": "Piezīmes no darbnīcas",
    "readMore": "Lasīt vairāk"
  },
  "catalog": {
    "title": "Katalogs",
    "subtitle": "Visi priekšmeti, kas šobrīd ir darbnīcā.",
    "empty": "Šim filtram pagaidām nekas neatbilst.",
    "priceLabel": "Cena",
    "viewProduct": "Skatīt priekšmetu",
    "addToCart": "Pievienot grozam",
    "filterAll": "Visi"
  },
  "product": {
    "back": "Atpakaļ uz katalogu",
    "descriptionLabel": "Apraksts",
    "materialsLabel": "Materiāli",
    "dimensionsLabel": "Izmēri",
    "careLabel": "Kopšana",
    "addToCart": "Pievienot grozam",
    "adding": "Pievieno…",
    "added": "Pievienots",
    "outOfStock": "Šobrīd nav pieejams",
    "quantityLabel": "Daudzums",
    "shippingNote": "Izgatavots pēc pasūtījuma nelielās sērijās. Piegāde no ES 5–10 darba dienu laikā.",
    "inStock": "Ir noliktavā",
    "like": "Saglabāt",
    "liked": "Saglabāts",
    "orderNow": "Pasūtīt tagad",
    "save": "Saglabāt",
    "saved": "Saglabāts",
    "weightLabel": "Svars",
    "heightLabel": "Augstums",
    "circumferenceLabel": "Apkārtmērs",
    "depthLabel": "Dziļums",
    "widthLabel": "Platums"
  },
  "cart": {
    "title": "Jūsu grozs",
    "empty": "Jūsu grozs pašlaik ir tukšs.",
    "continue": "Turpināt iepirkties",
    "subtotal": "Starpsumma",
    "checkout": "Doties uz apmaksu",
    "remove": "Noņemt",
    "quantity": "Daudz.",
    "taxNote": "Piegāde un piemērojamie nodokļi tiek aprēķināti apmaksas brīdī."
  },
  "checkout": {
    "title": "Apmaksa",
    "redirecting": "Novirzām jūs uz drošu apmaksu…",
    "error": "Sagatavojot jūsu pasūtījumu, radās kļūda. Lūdzu, mēģiniet vēlreiz.",
    "emailLabel": "E-pasts",
    "payButton": "Apmaksāt tagad"
  },
  "contact": {
    "title": "Kontakti",
    "intro": "Ja vēlaties apmeklēt mūsu darbnīcu, ja jums ir jautājumi par presi vai izplatītājiem, vai arī jebkādi citi jautājumi — lūdzu, rakstiet mums tieši.",
    "formName": "Vārds",
    "formEmail": "E-pasts",
    "formMessage": "Ziņa",
    "formSubmit": "Sūtīt ziņu",
    "formSuccess": "Paldies — atbildēsim dažu dienu laikā.",
    "formError": "Ziņu neizdevās nosūtīt. Mēģiniet vēlreiz vai rakstiet mums tieši uz e-pastu.",
    "detailsTitle": "Darbnīcas rekvizīti",
    "companyName": "Uzņēmums",
    "regNumber": "Reģ. Nr.",
    "vatNumber": "PVN Nr.",
    "address": "Adrese",
    "email": "E-pasts",
    "follow": "Sekojiet darbnīcai",
    "phone": "Tālrunis"
  },
  "account": {
    "signInTitle": "Pieslēgties",
    "signUpTitle": "Izveidot kontu",
    "email": "E-pasts",
    "password": "Parole",
    "signIn": "Pieslēgties",
    "signUp": "Izveidot kontu",
    "orSignUp": "Pirmo reizi šeit? Izveidot kontu",
    "orSignIn": "Jau ir konts? Pieslēgties",
    "signOut": "Izrakstīties",
    "ordersTitle": "Profils un pasūtījumi",
    "noOrders": "Jums vēl nav neviena pasūtījuma.",
    "orderNumber": "Pasūtījums",
    "orderStatus": "Statuss",
    "orderTotal": "Summa",
    "error": "Kaut kas nogāja greizi. Pārbaudiet datus un mēģiniet vēlreiz.",
    "activeOrdersTitle": "Aktīvie pasūtījumi",
    "noActiveOrders": "Jums šobrīd nav aktīvu pasūtījumu.",
    "pastOrdersTitle": "Pasūtījumu vēsture",
    "noPastOrders": "Jūsu pasūtījumu vēsture ir tukša.",
    "savedTitle": "Saglabātais",
    "noSaved": "Jūs vēl neko neesat saglabājis.",
    "errors": {
      "invalidCredentials": "Nepareizs e-pasts vai parole.",
      "emailNotConfirmed": "Lūdzu, apstipriniet e-pastu pirms pieslēgšanās.",
      "alreadyRegistered": "Konts ar šo e-pastu jau pastāv — mēģiniet pieslēgties.",
      "weakPassword": "Parolei jābūt vismaz 6 rakstzīmes garai.",
      "rateLimited": "Pārāk daudz mēģinājumu — lūdzu, uzgaidiet dažas minūtes un mēģiniet vēlreiz.",
      "generic": "Kaut kas nogāja greizi. Pārbaudiet datus un mēģiniet vēlreiz."
    },
    "signInRequired": "Vispirms lūdzu piesakieties."
  },
  "admin": {
    "title": "Darbnīcas administrēšana",
    "productsTab": "Priekšmeti",
    "ordersTab": "Pasūtījumi",
    "newProduct": "Pievienot jaunu priekšmetu",
    "name": "Nosaukums",
    "slug": "URL slug",
    "price": "Cena (EUR)",
    "stock": "Krājums",
    "description": "Apraksts",
    "materials": "Materiāli",
    "dimensions": "Izmēri",
    "images": "Attēli",
    "uploadImage": "Augšupielādēt attēlu",
    "save": "Saglabāt priekšmetu",
    "saving": "Saglabā…",
    "delete": "Dzēst",
    "edit": "Rediģēt",
    "cancel": "Atcelt",
    "confirmDelete": "Dzēst šo priekšmetu? To nevar atsaukt.",
    "noProducts": "Vēl nav priekšmetu. Pievienojiet pirmo augstāk.",
    "available": "Pieejams pārdošanai"
  },
  "footer": {
    "newsletterTitle": "Ziņas no darbnīcas",
    "newsletterBody": "Reizumis kāds vārds, kad gatava jauna neliela sērija. Nekā vairāk pa vidu.",
    "newsletterPlaceholder": "Jūsu e-pasts",
    "newsletterCta": "Abonēt",
    "newsletterSuccess": "Abonēts — paldies.",
    "rights": "Visas tiesības aizsargātas.",
    "cookiePolicy": "Sīkdatņu politika"
  },
  "common": {
    "loading": "Ielādē…",
    "currency": "€"
  },
  "collection": {
    "eyebrow": "Arhīvs",
    "title": "Kolekcijas grāmata",
    "intro": "Pieraksts par priekšmetiem, kas jau atraduši savas mājas — glabāts šeit kā arhīvs, nevis atkārtotai pārdošanai.",
    "empty": "Kolekcijas grāmata pagaidām ir tukša.",
    "soldIn": "Pārdots"
  },
  "cookies": {
    "message": "Šī vietne izmanto nelielu skaitu nepieciešamo sīkdatņu, lai saglabātu jūsu pieslēgšanos un grozu — nekas netiek izmantots reklāmai vai izsekošanai.",
    "learnMore": "Uzzināt vairāk",
    "accept": "Sapratu"
  },
  "cookiePolicy": {
    "title": "Sīkdatņu politika",
    "lastUpdated": "Atjaunināts 2026. gadā",
    "intro": "Šī lapa vienkāršā valodā skaidro, kādas sīkdatnes un līdzīgas tehnoloģijas izmanto vkv.form un kāpēc. Mēs apzināti to turam īsu, jo apzināti izmantojam ļoti maz.",
    "essentialTitle": "Nepieciešamās sīkdatnes",
    "essentialBody": "Kad piesakāties, mūsu autentifikācijas nodrošinātājs (Supabase) uzstāda drošu sīkdatni, lai vietne zinātu, ka esat pieslēdzies, pārvietojoties starp lapām. Šī sīkdatne ir absolūti nepieciešama vietnes darbībai — bez tās nevarētu palikt pieslēgts vai skatīt savus pasūtījumus — tāpēc saskaņā ar VDAR tā neprasa piekrišanu, bet mēs to pieminam šeit pārskatāmības labad.",
    "localStorageTitle": "Jūsu grozs",
    "localStorageBody": "Grozam pievienotie priekšmeti tiek glabāti jūsu pārlūkprogrammas lokālajā krātuvē, nevis sīkdatnē un nevis mūsu serveros, līdz pasūtījuma noformēšanai. Pārlūkprogrammas datu dzēšana dzēsīs arī jūsu grozu.",
    "thirdPartyTitle": "Trešās puses",
    "thirdPartyBody": "Mēs neizmantojam reklāmas sīkdatnes, izsekošanas pikseļus vai trešo pušu analītiku. Veicot apmaksu, jūs tiekat novirzīts uz mūsu maksājumu nodrošinātāja drošo apmaksas lapu, uz kuru attiecas viņu, nevis mūsu, sīkdatņu un privātuma politika.",
    "rightsTitle": "Jūsu tiesības",
    "rightsBody": "Saskaņā ar VDAR jūs varat pieprasīt no mums, kādus personas datus mēs par jums glabājam, lūgt tos labot vai dzēst, kā arī iebilst pret to apstrādi. Tā kā mēs glabājam ļoti maz datu (konta e-pastu, pasūtījumu vēsturi un to, ko esat skaidri saglabājis), lielākā daļa pieprasījumu tiek apstrādāti ātri.",
    "contactTitle": "Kontakti",
    "contactBody": "Jautājumus par šo politiku vai jūsu datiem var sūtīt uz darbnīcas e-pastu, kas norādīts mūsu Kontaktu lapā."
  }
}
__VKV_PATCH_EOF__
echo "  updated: messages/lv.json"

echo "Done. git add -A && git commit -m \"Redesign gallery layout, update About page text\" && git push"