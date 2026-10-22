-- Diji Medu Türkçe rights cleanup, 2026-10-04. Content only; no student/result changes.
-- Run after the original assets have been deployed.
begin;
update public.activities
set content=jsonb_set(content,'{questions}', '[
 {"siraNo":1,"dogruCevap":"dogru","gorselLink":"https://ogretmencocuk.com/ozgun/diji-robot.svg","dinlemeMetni":"Hello. I am Diji."},
 {"siraNo":2,"dogruCevap":"yanlis","gorselLink":"https://ogretmencocuk.com/ozgun/rota-gezgin.svg","dinlemeMetni":"Hello. I am Lina."},
 {"siraNo":3,"dogruCevap":"dogru","gorselLink":"https://ogretmencocuk.com/ozgun/lina-botanik.svg","dinlemeMetni":"Hello. I am Lina."},
 {"siraNo":4,"dogruCevap":"dogru","gorselLink":"https://ogretmencocuk.com/ozgun/rota-gezgin.svg","dinlemeMetni":"Hello. I am Rota."},
 {"siraNo":5,"dogruCevap":"dogru","gorselLink":"https://ogretmencocuk.com/ozgun/sayi-3.svg","dinlemeMetni":"Three."},
 {"siraNo":6,"dogruCevap":"dogru","gorselLink":"https://ogretmencocuk.com/ozgun/sayi-2.svg","dinlemeMetni":"Two."},
 {"siraNo":7,"dogruCevap":"yanlis","gorselLink":"https://ogretmencocuk.com/ozgun/sayi-3.svg","dinlemeMetni":"One."}
]'::jsonb)
where code='dogru_yanlis_1' and content::text ~ '(Monty|Maskman|gorseller/[1-6]\.png)';
-- All 183 remote pictures were decorative gorselLink fields, not questions.
update public.lesson_topics
set content=jsonb_set(content,'{gorselLink}',to_jsonb('https://ogretmencocuk.com/ozgun/ders-atolyesi.svg'::text))
where content->>'gorselLink' like 'https://images.unsplash.com/%';
commit;
