-- Enable the three social settings requested by the site owner.
-- Existing private activity history is not republished by this migration.
alter table public.turkce_profiles alter column share_activity set default true;
alter table public.turkce_profiles alter column show_online set default true;
alter table public.turkce_profiles alter column join_leagues set default true;
update public.turkce_profiles set share_activity=true,show_online=true,join_leagues=true,updated_at=now()
where not (share_activity and show_online and join_leagues);
