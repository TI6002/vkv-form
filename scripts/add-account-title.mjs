// Safe, one-off patch: adds account.title to every locale file ONLY if
// it's missing. Never overwrites anything else.
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const messagesDir = path.join(__dirname, '..', 'messages');

const titles = {
  en: 'Profile & Orders',
  ru: 'Профиль и заказы',
  fr: 'Profil et commandes',
  es: 'Perfil y pedidos',
  it: 'Profilo e ordini',
  de: 'Profil und Bestellungen',
  lv: 'Profils un pasūtījumi',
};

for (const [locale, title] of Object.entries(titles)) {
  const filePath = path.join(messagesDir, `${locale}.json`);
  let data;
  try {
    data = JSON.parse(readFileSync(filePath, 'utf-8'));
  } catch (err) {
    console.error(`Skipping ${locale}.json:`, err.message);
    continue;
  }
  if (!data.account) data.account = {};
  if (data.account.title === undefined) {
    data.account.title = title;
    writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n', 'utf-8');
    console.log(`${locale}.json — added account.title.`);
  } else {
    console.log(`${locale}.json — account.title already exists, left untouched.`);
  }
}
