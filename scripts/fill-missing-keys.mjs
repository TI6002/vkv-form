// One-off, safe patch: adds ONLY missing keys to messages/*.json.
// Never overwrites a key that already has a value — your own manual
// translations/customizations are left completely untouched.
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const messagesDir = path.join(__dirname, '..', 'messages');

const additions = {
  en: {
    product: { inStock: 'In stock', save: 'Save', saved: 'Saved', orderNow: 'Order now' },
    account: {
      activeOrdersTitle: 'Active orders',
      noActiveOrders: 'You have no active orders right now.',
      pastOrdersTitle: 'Order history',
      savedTitle: 'Saved items',
      noSaved: "You haven't saved anything yet.",
    },
  },
  ru: {
    product: { inStock: 'В наличии', save: 'Сохранить', saved: 'Сохранено', orderNow: 'Заказать' },
    account: {
      activeOrdersTitle: 'Активные заказы',
      noActiveOrders: 'Сейчас нет активных заказов.',
      pastOrdersTitle: 'История заказов',
      savedTitle: 'Сохранённое',
      noSaved: 'Вы пока ничего не сохранили.',
    },
  },
  fr: {
    product: { inStock: 'En stock', save: 'Enregistrer', saved: 'Enregistré', orderNow: 'Commander' },
    account: {
      activeOrdersTitle: 'Commandes en cours',
      noActiveOrders: "Vous n'avez aucune commande en cours.",
      pastOrdersTitle: 'Historique des commandes',
      savedTitle: 'Objets enregistrés',
      noSaved: "Vous n'avez encore rien enregistré.",
    },
  },
  es: {
    product: { inStock: 'En stock', save: 'Guardar', saved: 'Guardado', orderNow: 'Pedir ahora' },
    account: {
      activeOrdersTitle: 'Pedidos activos',
      noActiveOrders: 'No tienes pedidos activos por ahora.',
      pastOrdersTitle: 'Historial de pedidos',
      savedTitle: 'Guardados',
      noSaved: 'Todavía no has guardado nada.',
    },
  },
  it: {
    product: { inStock: 'Disponibile', save: 'Salva', saved: 'Salvato', orderNow: 'Ordina ora' },
    account: {
      activeOrdersTitle: 'Ordini attivi',
      noActiveOrders: 'Non hai ordini attivi al momento.',
      pastOrdersTitle: 'Storico ordini',
      savedTitle: 'Salvati',
      noSaved: 'Non hai ancora salvato nulla.',
    },
  },
  de: {
    product: { inStock: 'Auf Lager', save: 'Merken', saved: 'Gemerkt', orderNow: 'Jetzt bestellen' },
    account: {
      activeOrdersTitle: 'Aktive Bestellungen',
      noActiveOrders: 'Sie haben derzeit keine aktiven Bestellungen.',
      pastOrdersTitle: 'Bestellverlauf',
      savedTitle: 'Gemerkte Objekte',
      noSaved: 'Sie haben noch nichts gemerkt.',
    },
  },
  lv: {
    product: { inStock: 'Ir noliktavā', save: 'Saglabāt', saved: 'Saglabāts', orderNow: 'Pasūtīt tagad' },
    account: {
      activeOrdersTitle: 'Aktīvie pasūtījumi',
      noActiveOrders: 'Jums šobrīd nav aktīvu pasūtījumu.',
      pastOrdersTitle: 'Pasūtījumu vēsture',
      savedTitle: 'Saglabātais',
      noSaved: 'Jūs vēl neko neesat saglabājis.',
    },
  },
};

let totalAdded = 0;

for (const [locale, sections] of Object.entries(additions)) {
  const filePath = path.join(messagesDir, `${locale}.json`);
  let data;
  try {
    data = JSON.parse(readFileSync(filePath, 'utf-8'));
  } catch (err) {
    console.error(`Skipping ${locale}.json — could not read/parse it:`, err.message);
    continue;
  }

  let addedHere = 0;
  for (const [section, keys] of Object.entries(sections)) {
    if (!data[section]) data[section] = {};
    for (const [key, value] of Object.entries(keys)) {
      if (data[section][key] === undefined) {
        data[section][key] = value;
        addedHere++;
      }
    }
  }

  writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n', 'utf-8');
  console.log(`${locale}.json — added ${addedHere} missing key(s), everything else left untouched.`);
  totalAdded += addedHere;
}

console.log(`\nDone. ${totalAdded} key(s) added in total across all languages.`);
