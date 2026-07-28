#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates (round 42 — real contact details + Google Map instead of the form)..."

mkdir -p "app/[locale]/contact"
cat > "app/[locale]/contact/page.tsx" << '__VKV_PATCH_EOF__'
import { getTranslations, unstable_setRequestLocale } from 'next-intl/server';
import { Reveal } from '@/components/Reveal';

export default async function ContactPage({
  params: { locale },
}: {
  params: { locale: string };
}) {
  unstable_setRequestLocale(locale);
  const t = await getTranslations('contact');

  // Fill these in .env.local — see README "Studio details" section.
  const details = {
    company: process.env.NEXT_PUBLIC_STUDIO_COMPANY_NAME || 'vkv.form SIA',
    reg: process.env.NEXT_PUBLIC_STUDIO_REG_NUMBER || 'add your registration number',
    vat: process.env.NEXT_PUBLIC_STUDIO_VAT_NUMBER || 'add your VAT number',
    address: process.env.NEXT_PUBLIC_STUDIO_ADDRESS || 'Burtnieku Street 33, Riga, Latvia',
    email: process.env.NEXT_PUBLIC_STUDIO_EMAIL || 'vkv.form.info@gmail.com',
    phone: process.env.NEXT_PUBLIC_STUDIO_PHONE || '+371 20509471',
  };

  const mapQuery = encodeURIComponent(details.address);

  return (
    <div className="mx-auto max-w-[1400px] px-6 py-20 md:px-10 md:py-28">
      <Reveal>
        <h1 className="font-display text-5xl italic text-ink md:text-6xl">{t('title')}</h1>
        <p className="mt-6 max-w-lg font-body text-base leading-relaxed text-stone">
          {t('intro')}
        </p>
      </Reveal>

      <div className="mt-16 grid gap-16 md:grid-cols-2 md:gap-24">
        <Reveal>
          <div className="relative aspect-[4/3] w-full overflow-hidden bg-sand md:aspect-square">
            <iframe
              title="Studio location"
              src={`https://www.google.com/maps?q=${mapQuery}&output=embed`}
              className="absolute inset-0 h-full w-full border-0"
              loading="lazy"
              referrerPolicy="no-referrer-when-downgrade"
            />
          </div>
        </Reveal>

        <Reveal delay={0.1}>
          <p className="font-mono text-[11px] uppercase tracking-widest2 text-stone">
            {t('detailsTitle')}
          </p>
          <dl className="mt-6 space-y-4 border-t border-line pt-6">
            <Row label={t('companyName')} value={details.company} />
            <Row label={t('regNumber')} value={details.reg} />
            <Row label={t('vatNumber')} value={details.vat} />
            <Row label={t('address')} value={details.address} />
            <Row
              label={t('email')}
              value={details.email}
              href={`mailto:${details.email}`}
            />
            <Row label={t('phone')} value={details.phone} href={`tel:${details.phone.replace(/\s+/g, '')}`} />
          </dl>

          <p className="mt-10 font-mono text-[11px] uppercase tracking-widest2 text-stone">
            {t('follow')}
          </p>
          <div className="mt-3 flex flex-col gap-1.5">
            <a
              href="https://www.instagram.com/vkv.form"
              target="_blank"
              rel="noreferrer"
              className="font-body text-sm text-ink underline underline-offset-4"
            >
              Instagram — @vkv.form
            </a>
          </div>
        </Reveal>
      </div>
    </div>
  );
}

function Row({ label, value, href }: { label: string; value: string; href?: string }) {
  return (
    <div className="flex gap-4">
      <dt className="w-32 shrink-0 font-mono text-[11px] uppercase tracking-widest2 text-taupe">
        {label}
      </dt>
      <dd className="font-body text-sm text-ink">
        {href ? (
          <a href={href} className="underline underline-offset-4 hover:text-stone">
            {value}
          </a>
        ) : (
          value
        )}
      </dd>
    </div>
  );
}
__VKV_PATCH_EOF__
echo "  updated: app/[locale]/contact/page.tsx"

cat > ".env.example" << '__VKV_PATCH_EOF__'
# ---- Supabase (Settings → API in your Supabase project) ----
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
# Service role key — server-only, NEVER expose to the browser, never prefix with NEXT_PUBLIC_
SUPABASE_SERVICE_ROLE_KEY=

# ---- Stripe (Developers → API keys) ----
STRIPE_SECRET_KEY=
# Developers → Webhooks → your endpoint → Signing secret
STRIPE_WEBHOOK_SECRET=
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=

# ---- Site ----
NEXT_PUBLIC_SITE_URL=http://localhost:3000

# ---- Studio details shown on /contact ("реквизиты") ----
NEXT_PUBLIC_STUDIO_COMPANY_NAME="vkv.form SIA"
NEXT_PUBLIC_STUDIO_REG_NUMBER=""
NEXT_PUBLIC_STUDIO_VAT_NUMBER=""
NEXT_PUBLIC_STUDIO_ADDRESS="Burtnieku Street 33, Riga, Latvia"
NEXT_PUBLIC_STUDIO_EMAIL="vkv.form.info@gmail.com"
NEXT_PUBLIC_STUDIO_PHONE="+371 20509471"

# ---- Automatic translation (admin panel translate-on-save) ----
# Sign up free at https://www.deepl.com/pro-api → choose "DeepL API Free"
# (no credit card needed). 500,000 characters/month, no monthly fee.
DEEPL_API_KEY=""
__VKV_PATCH_EOF__
echo "  updated: .env.example"

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
    "heroTitle": "Form follows\nquiet.",
    "heroSubtitle": "Handmade sculptural objects for considered interiors. Each piece is cast, carved and finished by hand in a small studio, one at a time.",
    "heroCta": "Enter the catalogue",
    "philosophyEyebrow": "Philosophy",
    "philosophyTitle": "An object should earn its place slowly.",
    "philosophyBody": "We work with raw, honest materials — unglazed clay, plaster, warm stone — and let their texture stay visible. Nothing is corrected into perfection. The imprint of the hand is the point, not the flaw.",
    "catalogEyebrow": "The Collection",
    "catalogTitle": "Recent forms",
    "catalogCta": "View all objects",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "About",
    "authorEyebrow": "The maker",
    "authorTitle": "About the author",
    "authorBody1": "vkv.form began as a series of studies in balance — small clay forms made between other work, kept on a windowsill rather than sold. Over time the studies became a practice, and the practice became a small studio producing objects in short, considered runs.",
    "authorBody2": "Every piece that leaves the studio has passed through the same hands that shaped it. Nothing is outsourced, nothing is mass-produced — which is also why each run is limited, and why some forms do not return once they are gone.",
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
    "intro": "For studio visits, press, stockist enquiries or anything else — write to us directly.",
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
    "ordersTitle": "Order history",
    "noOrders": "You have no orders yet.",
    "orderNumber": "Order",
    "orderStatus": "Status",
    "orderTotal": "Total",
    "error": "Something went wrong. Please check your details and try again.",
    "activeOrdersTitle": "Active orders",
    "noActiveOrders": "You have no active orders right now.",
    "pastOrdersTitle": "Order history",
    "savedTitle": "Saved items",
    "noSaved": "You haven't saved anything yet.",
    "errors": {
      "invalidCredentials": "Incorrect email or password.",
      "emailNotConfirmed": "Please confirm your email before signing in.",
      "alreadyRegistered": "An account with this email already exists — try signing in instead.",
      "weakPassword": "Password should be at least 6 characters.",
      "rateLimited": "Too many attempts — please wait a few minutes and try again.",
      "generic": "Something went wrong. Please check your details and try again."
    }
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
    "rights": "All rights reserved."
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
    "heroTitle": "Форма\nследует тишине.",
    "heroSubtitle": "Рукотворные скульптурные предметы для продуманных интерьеров. Каждое изделие отливается, вырезается и доводится вручную в небольшой мастерской — по одному.",
    "heroCta": "В каталог",
    "philosophyEyebrow": "Философия",
    "philosophyTitle": "Предмет должен заслужить своё место — не спеша.",
    "philosophyBody": "Мы работаем с честными, необработанными материалами — неглазурованной глиной, гипсом, тёплым камнем — и оставляем видимой их текстуру. Ничего не доводится до идеала. След руки — это суть, а не изъян.",
    "catalogEyebrow": "Коллекция",
    "catalogTitle": "Последние формы",
    "catalogCta": "Смотреть все предметы",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "О нас",
    "authorEyebrow": "Автор",
    "authorTitle": "Об авторе",
    "authorBody1": "vkv.form начался как серия этюдов о балансе — небольшие формы из глины, сделанные между другой работой и хранившиеся на подоконнике, а не продававшиеся. Со временем этюды переросли в практику, а практика — в небольшую мастерскую, выпускающую предметы малыми, продуманными партиями.",
    "authorBody2": "Каждое изделие, покидающее мастерскую, прошло через те же руки, что его создали. Ничего не отдаётся на аутсорс, ничего не производится массово — поэтому каждая партия ограничена, а некоторые формы больше не повторяются, когда заканчиваются.",
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
    "intro": "По вопросам визита в мастерскую, прессы, оптовых закупок и всего остального — напишите нам напрямую.",
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
    "ordersTitle": "История заказов",
    "noOrders": "У вас пока нет заказов.",
    "orderNumber": "Заказ",
    "orderStatus": "Статус",
    "orderTotal": "Сумма",
    "error": "Что-то пошло не так. Проверьте данные и попробуйте снова.",
    "activeOrdersTitle": "Активные заказы",
    "noActiveOrders": "Сейчас нет активных заказов.",
    "pastOrdersTitle": "История заказов",
    "savedTitle": "Сохранённое",
    "noSaved": "Вы пока ничего не сохранили.",
    "errors": {
      "invalidCredentials": "Неверный email или пароль.",
      "emailNotConfirmed": "Подтвердите email перед входом.",
      "alreadyRegistered": "Аккаунт с таким email уже существует — попробуйте войти.",
      "weakPassword": "Пароль должен содержать не менее 6 символов.",
      "rateLimited": "Слишком много попыток — подождите несколько минут и попробуйте снова.",
      "generic": "Что-то пошло не так. Проверьте данные и попробуйте снова."
    }
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
    "rights": "Все права защищены."
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
    "heroTitle": "La forme\nsuit le silence.",
    "heroSubtitle": "Objets sculpturaux faits main pour des intérieurs pensés. Chaque pièce est coulée, sculptée et finie à la main dans un petit atelier, une à une.",
    "heroCta": "Découvrir le catalogue",
    "philosophyEyebrow": "Philosophie",
    "philosophyTitle": "Un objet doit mériter sa place, lentement.",
    "philosophyBody": "Nous travaillons des matières brutes et honnêtes — argile non émaillée, plâtre, pierre chaude — et laissons leur texture visible. Rien n'est corrigé jusqu'à la perfection. La trace de la main est le propos, non le défaut.",
    "catalogEyebrow": "La collection",
    "catalogTitle": "Formes récentes",
    "catalogCta": "Voir tous les objets",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "À propos",
    "authorEyebrow": "La créatrice",
    "authorTitle": "À propos de l'auteure",
    "authorBody1": "vkv.form a commencé comme une série d'études sur l'équilibre — de petites formes en argile faites entre deux travaux, gardées sur un rebord de fenêtre plutôt que vendues. Avec le temps, ces études sont devenues une pratique, et la pratique un petit atelier produisant des objets en séries courtes et réfléchies.",
    "authorBody2": "Chaque pièce qui quitte l'atelier est passée entre les mêmes mains qui l'ont façonnée. Rien n'est sous-traité, rien n'est produit en série — c'est pourquoi chaque série est limitée, et certaines formes ne reviennent pas une fois épuisées.",
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
    "intro": "Pour une visite de l'atelier, la presse, une demande de revente ou toute autre question — écrivez-nous directement.",
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
    "ordersTitle": "Historique des commandes",
    "noOrders": "Vous n'avez pas encore de commande.",
    "orderNumber": "Commande",
    "orderStatus": "Statut",
    "orderTotal": "Total",
    "error": "Une erreur est survenue. Vérifiez vos informations et réessayez.",
    "activeOrdersTitle": "Commandes en cours",
    "noActiveOrders": "Vous n'avez aucune commande en cours.",
    "pastOrdersTitle": "Historique des commandes",
    "savedTitle": "Objets enregistrés",
    "noSaved": "Vous n'avez encore rien enregistré.",
    "errors": {
      "invalidCredentials": "Email ou mot de passe incorrect.",
      "emailNotConfirmed": "Veuillez confirmer votre email avant de vous connecter.",
      "alreadyRegistered": "Un compte existe déjà avec cet email — essayez de vous connecter.",
      "weakPassword": "Le mot de passe doit contenir au moins 6 caractères.",
      "rateLimited": "Trop de tentatives — veuillez patienter quelques minutes et réessayer.",
      "generic": "Une erreur est survenue. Vérifiez vos informations et réessayez."
    }
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
    "rights": "Tous droits réservés."
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
    "heroTitle": "La forma\nsigue al silencio.",
    "heroSubtitle": "Objetos escultóricos hechos a mano para interiores pensados con cuidado. Cada pieza se moldea, talla y termina a mano en un pequeño taller, una a una.",
    "heroCta": "Entrar al catálogo",
    "philosophyEyebrow": "Filosofía",
    "philosophyTitle": "Un objeto debe ganarse su lugar, despacio.",
    "philosophyBody": "Trabajamos con materiales honestos y sin pulir — arcilla sin esmaltar, yeso, piedra cálida — dejando visible su textura. Nada se corrige hasta la perfección. La huella de la mano es la esencia, no el defecto.",
    "catalogEyebrow": "La colección",
    "catalogTitle": "Formas recientes",
    "catalogCta": "Ver todos los objetos",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "Sobre nosotros",
    "authorEyebrow": "La autora",
    "authorTitle": "Sobre la autora",
    "authorBody1": "vkv.form comenzó como una serie de estudios sobre el equilibrio — pequeñas formas de arcilla hechas entre otros trabajos, guardadas en un alféizar en lugar de venderse. Con el tiempo, los estudios se convirtieron en una práctica, y la práctica en un pequeño taller que produce objetos en tiradas cortas y meditadas.",
    "authorBody2": "Cada pieza que sale del taller ha pasado por las mismas manos que la moldearon. Nada se subcontrata, nada se produce en masa — por eso cada tirada es limitada, y algunas formas no vuelven una vez agotadas.",
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
    "intro": "Para visitas al taller, prensa, consultas de distribución o cualquier otra cosa — escríbenos directamente.",
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
    "ordersTitle": "Historial de pedidos",
    "noOrders": "Todavía no tienes pedidos.",
    "orderNumber": "Pedido",
    "orderStatus": "Estado",
    "orderTotal": "Total",
    "error": "Algo salió mal. Revisa tus datos e inténtalo de nuevo.",
    "activeOrdersTitle": "Pedidos activos",
    "noActiveOrders": "No tienes pedidos activos por ahora.",
    "pastOrdersTitle": "Historial de pedidos",
    "savedTitle": "Guardados",
    "noSaved": "Todavía no has guardado nada.",
    "errors": {
      "invalidCredentials": "Email o contraseña incorrectos.",
      "emailNotConfirmed": "Confirma tu email antes de iniciar sesión.",
      "alreadyRegistered": "Ya existe una cuenta con este email — intenta iniciar sesión.",
      "weakPassword": "La contraseña debe tener al menos 6 caracteres.",
      "rateLimited": "Demasiados intentos — espera unos minutos y vuelve a intentarlo.",
      "generic": "Algo salió mal. Revisa tus datos e inténtalo de nuevo."
    }
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
    "rights": "Todos los derechos reservados."
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
    "heroTitle": "La forma\nsegue il silenzio.",
    "heroSubtitle": "Oggetti scultorei fatti a mano per interni curati. Ogni pezzo viene colato, scolpito e rifinito a mano in un piccolo studio, uno alla volta.",
    "heroCta": "Entra nel catalogo",
    "philosophyEyebrow": "Filosofia",
    "philosophyTitle": "Un oggetto deve guadagnarsi il suo posto, lentamente.",
    "philosophyBody": "Lavoriamo materiali grezzi e onesti — argilla non smaltata, gesso, pietra calda — lasciandone visibile la texture. Nulla viene corretto fino alla perfezione. Il segno della mano è il punto, non il difetto.",
    "catalogEyebrow": "La collezione",
    "catalogTitle": "Forme recenti",
    "catalogCta": "Vedi tutti gli oggetti",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "Chi siamo",
    "authorEyebrow": "L'autrice",
    "authorTitle": "Chi è l'autrice",
    "authorBody1": "vkv.form è nato come una serie di studi sull'equilibrio — piccole forme in argilla realizzate tra un lavoro e l'altro, tenute su un davanzale invece che vendute. Col tempo gli studi sono diventati una pratica, e la pratica un piccolo studio che produce oggetti in serie brevi e ponderate.",
    "authorBody2": "Ogni pezzo che lascia lo studio è passato tra le stesse mani che lo hanno modellato. Nulla è esternalizzato, nulla è prodotto in serie — per questo ogni serie è limitata, e alcune forme non tornano una volta esaurite.",
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
    "intro": "Per visite allo studio, stampa, richieste di rivendita o altro — scrivici direttamente.",
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
    "ordersTitle": "Storico ordini",
    "noOrders": "Non hai ancora nessun ordine.",
    "orderNumber": "Ordine",
    "orderStatus": "Stato",
    "orderTotal": "Totale",
    "error": "Qualcosa è andato storto. Controlla i dati e riprova.",
    "activeOrdersTitle": "Ordini attivi",
    "noActiveOrders": "Non hai ordini attivi al momento.",
    "pastOrdersTitle": "Storico ordini",
    "savedTitle": "Salvati",
    "noSaved": "Non hai ancora salvato nulla.",
    "errors": {
      "invalidCredentials": "Email o password errati.",
      "emailNotConfirmed": "Conferma la tua email prima di accedere.",
      "alreadyRegistered": "Esiste già un account con questa email — prova ad accedere.",
      "weakPassword": "La password deve contenere almeno 6 caratteri.",
      "rateLimited": "Troppi tentativi — attendi qualche minuto e riprova.",
      "generic": "Qualcosa è andato storto. Controlla i dati e riprova."
    }
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
    "rights": "Tutti i diritti riservati."
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
    "heroTitle": "Form folgt\nder Stille.",
    "heroSubtitle": "Handgefertigte, skulpturale Objekte für durchdachte Innenräume. Jedes Stück wird von Hand gegossen, geschnitzt und veredelt, eines nach dem anderen, in einem kleinen Atelier.",
    "heroCta": "Zum Katalog",
    "philosophyEyebrow": "Philosophie",
    "philosophyTitle": "Ein Objekt sollte sich seinen Platz langsam verdienen.",
    "philosophyBody": "Wir arbeiten mit rohen, ehrlichen Materialien — unglasiertem Ton, Gips, warmem Stein — und lassen ihre Textur sichtbar. Nichts wird bis zur Perfektion korrigiert. Die Spur der Hand ist der Sinn, nicht der Makel.",
    "catalogEyebrow": "Die Kollektion",
    "catalogTitle": "Neueste Formen",
    "catalogCta": "Alle Objekte ansehen",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "Über uns",
    "authorEyebrow": "Die Macherin",
    "authorTitle": "Über die Autorin",
    "authorBody1": "vkv.form begann als eine Reihe von Studien zum Gleichgewicht — kleine Tonformen, entstanden neben anderer Arbeit und auf einer Fensterbank aufbewahrt statt verkauft. Mit der Zeit wurden aus den Studien eine Praxis und aus der Praxis ein kleines Atelier, das Objekte in kurzen, durchdachten Serien fertigt.",
    "authorBody2": "Jedes Stück, das das Atelier verlässt, ist durch dieselben Hände gegangen, die es geformt haben. Nichts wird ausgelagert, nichts wird massenproduziert — deshalb ist jede Serie begrenzt, und manche Formen kehren nach ihrem Verkauf nicht zurück.",
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
    "intro": "Für Atelierbesuche, Presse, Handelsanfragen oder alles andere — schreiben Sie uns direkt.",
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
    "ordersTitle": "Bestellverlauf",
    "noOrders": "Sie haben noch keine Bestellungen.",
    "orderNumber": "Bestellung",
    "orderStatus": "Status",
    "orderTotal": "Summe",
    "error": "Etwas ist schiefgelaufen. Bitte überprüfen Sie Ihre Angaben und versuchen Sie es erneut.",
    "activeOrdersTitle": "Aktive Bestellungen",
    "noActiveOrders": "Sie haben derzeit keine aktiven Bestellungen.",
    "pastOrdersTitle": "Bestellverlauf",
    "savedTitle": "Gemerkte Objekte",
    "noSaved": "Sie haben noch nichts gemerkt.",
    "errors": {
      "invalidCredentials": "E-Mail oder Passwort ist falsch.",
      "emailNotConfirmed": "Bitte bestätigen Sie Ihre E-Mail, bevor Sie sich anmelden.",
      "alreadyRegistered": "Ein Konto mit dieser E-Mail existiert bereits — versuchen Sie sich anzumelden.",
      "weakPassword": "Das Passwort muss mindestens 6 Zeichen lang sein.",
      "rateLimited": "Zu viele Versuche — bitte warten Sie ein paar Minuten und versuchen Sie es erneut.",
      "generic": "Etwas ist schiefgelaufen. Bitte überprüfen Sie Ihre Angaben und versuchen Sie es erneut."
    }
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
    "rights": "Alle Rechte vorbehalten."
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
    "heroTitle": "Forma\nseko klusumam.",
    "heroSubtitle": "Rokdarbā veidoti skulpturāli priekšmeti pārdomātām interjera telpām. Katrs darbs tiek liets, tēsts un apdarināts ar rokām nelielā darbnīcā, pa vienam.",
    "heroCta": "Skatīt katalogu",
    "philosophyEyebrow": "Filozofija",
    "philosophyTitle": "Priekšmetam sava vieta jāizpelnās lēni.",
    "philosophyBody": "Mēs strādājam ar godīgiem, neapstrādātiem materiāliem — negleznotu mālu, ģipsi, siltu akmeni — un ļaujam to faktūrai palikt redzamai. Nekas netiek pilnveidots līdz perfekcijai. Rokas nospiedums ir jēga, nevis defekts.",
    "catalogEyebrow": "Kolekcija",
    "catalogTitle": "Jaunākās formas",
    "catalogCta": "Skatīt visus priekšmetus",
    "featuredEyebrow": "01 — 03"
  },
  "about": {
    "title": "Par mums",
    "authorEyebrow": "Autore",
    "authorTitle": "Par autori",
    "authorBody1": "vkv.form aizsākās kā virkne pētījumu par līdzsvaru — mazas māla formas, kas tapa starp citu darbu un tika glabātas uz palodzes, nevis pārdotas. Laika gaitā šie pētījumi kļuva par praksi, bet prakse — par nelielu darbnīcu, kas ražo priekšmetus īsās, pārdomātās sērijās.",
    "authorBody2": "Katrs priekšmets, kas atstāj darbnīcu, ir gājis cauri tām pašām rokām, kas to veidoja. Nekas netiek nodots ārpakalpojumā, nekas netiek ražots masveidā — tāpēc katra sērija ir ierobežota, un dažas formas pēc izpārdošanas vairs neatgriežas.",
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
    "intro": "Lai apmeklētu darbnīcu, presei, vairumtirdzniecības jautājumiem vai jebkam citam — rakstiet mums tieši.",
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
    "ordersTitle": "Pasūtījumu vēsture",
    "noOrders": "Jums vēl nav neviena pasūtījuma.",
    "orderNumber": "Pasūtījums",
    "orderStatus": "Statuss",
    "orderTotal": "Summa",
    "error": "Kaut kas nogāja greizi. Pārbaudiet datus un mēģiniet vēlreiz.",
    "activeOrdersTitle": "Aktīvie pasūtījumi",
    "noActiveOrders": "Jums šobrīd nav aktīvu pasūtījumu.",
    "pastOrdersTitle": "Pasūtījumu vēsture",
    "savedTitle": "Saglabātais",
    "noSaved": "Jūs vēl neko neesat saglabājis.",
    "errors": {
      "invalidCredentials": "Nepareizs e-pasts vai parole.",
      "emailNotConfirmed": "Lūdzu, apstipriniet e-pastu pirms pieslēgšanās.",
      "alreadyRegistered": "Konts ar šo e-pastu jau pastāv — mēģiniet pieslēgties.",
      "weakPassword": "Parolei jābūt vismaz 6 rakstzīmes garai.",
      "rateLimited": "Pārāk daudz mēģinājumu — lūdzu, uzgaidiet dažas minūtes un mēģiniet vēlreiz.",
      "generic": "Kaut kas nogāja greizi. Pārbaudiet datus un mēģiniet vēlreiz."
    }
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
    "rights": "Visas tiesības aizsargātas."
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
  }
}
__VKV_PATCH_EOF__
echo "  updated: messages/lv.json"

echo "Done. Restart npm run dev after this."