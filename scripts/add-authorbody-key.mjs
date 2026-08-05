// Safe, one-off patch: adds messages/en.json → about.authorBody (built-in
// fallback text) ONLY if it's missing. Never touches anything else.
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const filePath = path.join(__dirname, '..', 'messages', 'en.json');

const fallback =
  "I am a contemporary artist who creates sculptural vessels and forms that embody the idea of rebirth. In my work, I focus on that moment when loss ceases to be an end and becomes the beginning of a new life. At the heart of my artistic practice lies my own technique, \u2018Lacera\u2019, in which, during the process of creating a form, the material undergoes controlled tearing and re-joining.\n\nTears, ragged edges and cracks are an integral part of the structure and meaning, where a new wholeness is born not in spite of change, but thanks to it. I mainly work with materials that have already undergone a previous life cycle, returning them to the artistic realm in a new capacity.\n\nThe paper-based composite clay developed by the artist, which completely eliminates the firing stage, offers the freedom to create objects with a visually pristine, deeply textured surface. The material itself becomes part of the artistic expression: the idea of rebirth is embodied not only in form, but also in the very matter itself, which takes on a new existence.\n\nEach work invites a silent dialogue about human resilience, inner states and quiet empathy, revealing its emotional essence. In some works, the composition is complemented by botanical elements, symbolising the continuity of life, the ability to overcome difficulties and renewal.";

const data = JSON.parse(readFileSync(filePath, 'utf-8'));
if (!data.about) data.about = {};

if (data.about.authorBody === undefined) {
  data.about.authorBody = fallback;
  writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n', 'utf-8');
  console.log('Added about.authorBody to messages/en.json.');
} else {
  console.log('about.authorBody already exists — left untouched.');
}
