-- Replace the About page author copy with the exact supplied Russian and English text.
-- The application reads this content from public.about_content via lib/content.ts.

insert into public.about_content (key, value, updated_at)
values (
  'authorBody',
  jsonb_build_object(
    'ru', $$Я - современный скульптор, создающий эволюционирующие формы ,раскрывающие идею перерождения. Моё творчество обращено к моменту, когда утрата перестаёт быть завершением и становится началом новой жизни.

В основе моей художественной практики лежит авторская техника Lacera,где скульптурная форма говорит о силе внутреннего духа,способности быть несмотря ни на что, о воле найти в себе возможность продолжать,даже когда прежняя форма уже невозможна.

В процессе формирования материя проявляет собственную логику: линии раскрытия возникают и формируются порой независимо от первоначального замысла, словно сама форма находит свой путь к нахождению разломов на поверхности произведения. Разрывы, рваные края и трещины становятся неотъемлемой частью структуры и смысла, где новая целостность рождается не вопреки изменениям, а благодаря им.

Я работаю преимущественно с материалами, прошедшими предыдущий жизненный цикл, возвращая их в художественное пространство в новом качестве. Авторская композитная целлюлозно-керамическая глина, исключающая стадию обжига, даёт свободу создавать объекты с визуально первозданной, глубоко текстурированной поверхностью. Сам материал становится частью художественного высказывания: идея перерождения воплощается не только в форме, но и в материи, обретающей новое существование.

Каждое произведение приглашает к безмолвному диалогу о человеческой стойкости, внутреннем состоянии и тихом сопереживании, раскрывая эмоциональную природу человека. В отдельных работах композицию дополняют ботанические элементы, символизирующие продолжение жизни, способность к преодолению и обновлению.$$,
    'en', $$Artist Statement:
I am a contemporary sculptor creating evolving forms that explore the idea of rebirth. My work is concerned with the moment when loss ceases to be an ending and becomes the beginning of a new life.

At the core of my artistic practice is my proprietary Lacera technique, in which the sculptural form speaks of the strength of the inner spirit, the ability to exist despite everything, and the will to find within oneself the possibility to continue, even when the previous form is no longer possible.

In the process of formation, matter reveals its own logic: lines of opening emerge and take shape, sometimes independently of the initial intention, as though the form itself finds its way toward discovering fractures on the surface of the work. Breaks, torn edges, and cracks become an integral part of the structure and meaning, where a new wholeness is born not in spite of change, but through it.

I work predominantly with materials that have undergone a previous life cycle, returning them to the artistic space in a new form. My proprietary composite cellulose-ceramic clay, which eliminates the firing stage, gives me the freedom to create objects with a visually primordial, deeply textured surface. The material itself becomes part of the artistic statement: the idea of rebirth is embodied not only in the form, but also in matter acquiring a new existence.

Each work invites a silent dialogue about human resilience, inner states, and quiet empathy, revealing the emotional nature of the human being. In some works, botanical elements complement the composition, symbolizing the continuation of life, the capacity to overcome, and renewal.$$
  ),
  now()
)
on conflict (key) do update
set value = excluded.value,
    updated_at = now();
