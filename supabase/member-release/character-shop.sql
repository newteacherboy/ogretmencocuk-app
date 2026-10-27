begin;
create table if not exists public.turkce_owned_characters (
 user_id uuid not null references public.turkce_profiles(id) on delete cascade,
 character_id text not null check(character_id in ('girl-1','girl-2','girl-3','boy-1','boy-2','boy-3')),
 paid_gold integer not null check(paid_gold>=0), purchased_at timestamptz not null default now(),
 primary key(user_id,character_id)
);
create table if not exists public.turkce_character_selection (
 user_id uuid primary key references public.turkce_profiles(id) on delete cascade,
 character_id text not null,updated_at timestamptz not null default now(),
 foreign key(user_id,character_id) references public.turkce_owned_characters(user_id,character_id) on delete cascade
);
alter table public.turkce_owned_characters enable row level security;
alter table public.turkce_character_selection enable row level security;
revoke all on public.turkce_owned_characters,public.turkce_character_selection from public,anon,authenticated;
grant all on public.turkce_owned_characters,public.turkce_character_selection to service_role;
create or replace function public.turkce_shop_request(actor uuid,op text,p jsonb default '{}') returns jsonb
language plpgsql security invoker set search_path=public,pg_temp as $$
declare balance bigint;item text;cost integer;result jsonb;was_owned boolean;catalog jsonb:='[{"id":"girl-1","gender":"girl","price":300},{"id":"girl-2","gender":"girl","price":450},{"id":"girl-3","gender":"girl","price":600},{"id":"boy-1","gender":"boy","price":300},{"id":"boy-2","gender":"boy","price":450},{"id":"boy-3","gender":"boy","price":600}]';
begin
 if actor is null or not exists(select 1 from public.turkce_profiles where id=actor and not disabled) then raise exception 'Aktif öğrenci hesabı gerekli.';end if;
 if op not in ('state','buy','equip','avatars') then raise exception 'İşlem bulunamadı.';end if;
 if op='avatars' then
  if jsonb_typeof(p->'usernames') is distinct from 'array' then raise exception 'Geçersiz liste.';end if;
  if jsonb_array_length(p->'usernames')>100 then raise exception 'En fazla 100 öğrenci.';end if;
  return jsonb_build_object('ok',true,'avatars',coalesce((select jsonb_object_agg(u.username,s.character_id) from public.turkce_profiles u join public.turkce_character_selection s on s.user_id=u.id where not u.disabled and (u.id=actor or u.join_leagues or exists(select 1 from public.turkce_friendships f where f.accepted_at is not null and ((f.requester=actor and f.recipient=u.id) or(f.recipient=actor and f.requester=u.id)))) and u.username in(select jsonb_array_elements_text(p->'usernames'))),'{}'::jsonb));
 end if;
 -- Uses the same economy row lock as parkur/game rewards and admin balance edits.
 select gold into balance from public.turkce_economy where user_id=actor for update;
 if not found then raise exception 'Hesap bakiyesi bulunamadı.';end if;
 if op in ('buy','equip') then
  item:=p->>'character_id';
  select (x->>'price')::integer into cost from jsonb_array_elements(catalog)x where x->>'id'=item;
  if cost is null then raise exception 'Karakter bulunamadı.';end if;
  select exists(select 1 from public.turkce_owned_characters where user_id=actor and character_id=item) into was_owned;
  if op='buy' and not was_owned then
   if balance<cost then raise exception 'Bu karakter için yeterli altının yok.';end if;
   update public.turkce_economy set gold=gold-cost,updated_at=now() where user_id=actor returning gold into balance;
   insert into public.turkce_owned_characters(user_id,character_id,paid_gold) values(actor,item,cost);
  elsif op='equip' and not was_owned then raise exception 'Önce bu karakteri satın almalısın.';
  end if;
  insert into public.turkce_character_selection(user_id,character_id) values(actor,item) on conflict(user_id) do update set character_id=excluded.character_id,updated_at=now();
 end if;
 return jsonb_build_object('ok',true,'gold',balance,'catalog',catalog,'owned',coalesce((select jsonb_agg(character_id order by purchased_at,character_id) from public.turkce_owned_characters where user_id=actor),'[]'::jsonb),'selected_avatar',(select character_id from public.turkce_character_selection where user_id=actor),'already_owned',coalesce(was_owned,false));
end $$;
revoke all on function public.turkce_shop_request(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.turkce_shop_request(uuid,text,jsonb) to service_role;
commit;
