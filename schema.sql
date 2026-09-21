-- eFootball Manager V9 - full database setup
create extension if not exists pgcrypto;

do $$ begin create type public.user_role as enum ('admin','member'); exception when duplicate_object then null; end $$;
do $$ begin create type public.competition_type as enum ('league','tournament'); exception when duplicate_object then null; end $$;
do $$ begin create type public.competition_format as enum ('round_robin','home_away','knockout'); exception when duplicate_object then null; end $$;

create table if not exists public.profiles (id uuid primary key references auth.users(id) on delete cascade,display_name text not null,role public.user_role not null default 'member',created_at timestamptz not null default now());
create table if not exists public.competitions (id uuid primary key default gen_random_uuid(),name text not null,type public.competition_type not null,format public.competition_format not null,creator_id uuid not null references public.profiles(id),status text not null default 'open' check(status in ('draft','open','active','completed')),max_players integer not null check(max_players between 2 and 64),start_date date,end_date date,created_at timestamptz not null default now());
create table if not exists public.competition_members (competition_id uuid references public.competitions(id) on delete cascade,user_id uuid references public.profiles(id) on delete cascade,joined_at timestamptz not null default now(),primary key(competition_id,user_id));
create table if not exists public.availability (id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,available_date date not null,start_time time not null,end_time time not null,created_at timestamptz not null default now(),constraint valid_time_range check(end_time>start_time));
create table if not exists public.matches (id uuid primary key default gen_random_uuid(),competition_id uuid references public.competitions(id) on delete cascade,home_player uuid not null references public.profiles(id),away_player uuid not null references public.profiles(id),match_date date not null,start_time time not null,end_time time not null,status text not null default 'upcoming' check(status in ('upcoming','completed','cancelled')),home_score integer,away_score integer,round_no integer,group_name text,submitted_by uuid references public.profiles(id),submitted_at timestamptz,created_at timestamptz not null default now(),constraint different_players check(home_player<>away_player),constraint valid_scores check((home_score is null and away_score is null) or(home_score>=0 and away_score>=0)));

create table if not exists public.teams (id uuid primary key default gen_random_uuid(),owner_id uuid not null unique references public.profiles(id) on delete cascade,name text not null unique,budget numeric(12,2) not null default 1000000 check(budget>=0),created_at timestamptz not null default now());
create table if not exists public.team_players (team_id uuid references public.teams(id) on delete cascade,user_id uuid primary key references public.profiles(id) on delete cascade,position text not null default 'CF',rating integer not null default 70 check(rating between 1 and 99),joined_at timestamptz not null default now());
create table if not exists public.staff (id uuid primary key default gen_random_uuid(),team_id uuid not null references public.teams(id) on delete cascade,name text not null,role text not null,level integer not null default 1 check(level between 1 and 10),salary numeric(12,2) not null default 10000 check(salary>=0),created_at timestamptz not null default now());
create table if not exists public.transfer_listings (id uuid primary key default gen_random_uuid(),player_id uuid not null unique references public.profiles(id) on delete cascade,from_team_id uuid not null references public.teams(id) on delete cascade,asking_price numeric(12,2) not null check(asking_price>=0),status text not null default 'open' check(status in ('open','sold','cancelled')),created_at timestamptz not null default now());
create table if not exists public.transfers (id uuid primary key default gen_random_uuid(),listing_id uuid not null references public.transfer_listings(id),player_id uuid not null references public.profiles(id),seller_team_id uuid not null references public.teams(id),buyer_team_id uuid not null references public.teams(id),price numeric(12,2) not null check(price>=0),created_at timestamptz not null default now());

alter table public.profiles enable row level security;
alter table public.competitions enable row level security;
alter table public.competition_members enable row level security;
alter table public.availability enable row level security;
alter table public.matches enable row level security;
alter table public.teams enable row level security;
alter table public.team_players enable row level security;
alter table public.staff enable row level security;
alter table public.transfer_listings enable row level security;
alter table public.transfers enable row level security;

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from public.profiles where id=auth.uid() and role='admin')$$;
create or replace function public.is_comp_member(cid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from public.competition_members where competition_id=cid and user_id=auth.uid())$$;
create or replace function public.is_comp_creator(cid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from public.competitions where id=cid and creator_id=auth.uid())$$;
create or replace function public.my_team_id() returns uuid language sql stable security definer set search_path=public as $$select id from public.teams where owner_id=auth.uid() limit 1$$;

-- Existing policies are dropped so this script can be safely re-run.
do $$ declare r record; begin for r in select policyname,tablename from pg_policies where schemaname='public' and tablename in ('profiles','competitions','competition_members','availability','matches','teams','team_players','staff','transfer_listings','transfers') loop execute format('drop policy if exists %I on public.%I',r.policyname,r.tablename); end loop; end $$;

create policy "profiles read" on public.profiles for select to authenticated using(true);
create policy "profiles own insert" on public.profiles for insert to authenticated with check(id=auth.uid());
create policy "own profile update" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "competitions read" on public.competitions for select to authenticated using(true);
create policy "competition create" on public.competitions for insert to authenticated with check(creator_id=auth.uid());
create policy "competition creator update" on public.competitions for update to authenticated using(creator_id=auth.uid() or public.is_admin()) with check(creator_id=auth.uid() or public.is_admin());
create policy "competition creator delete" on public.competitions for delete to authenticated using(creator_id=auth.uid() or public.is_admin());
create policy "members read" on public.competition_members for select to authenticated using(true);
create policy "members join" on public.competition_members for insert to authenticated with check(user_id=auth.uid() and exists(select 1 from public.competitions c where c.id=competition_id and c.status='open'));
create policy "creator/admin manage members" on public.competition_members for delete to authenticated using(public.is_comp_creator(competition_id) or public.is_admin() or user_id=auth.uid());
create policy "availability read" on public.availability for select to authenticated using(true);
create policy "availability own insert" on public.availability for insert to authenticated with check(user_id=auth.uid());
create policy "availability own update" on public.availability for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "availability own delete" on public.availability for delete to authenticated using(user_id=auth.uid());
create policy "matches read" on public.matches for select to authenticated using(public.is_comp_member(competition_id) or public.is_admin());
create policy "matches create" on public.matches for insert to authenticated with check(public.is_comp_creator(competition_id) or public.is_admin());
create policy "matches creator update" on public.matches for update to authenticated using(public.is_comp_creator(competition_id) or public.is_admin()) with check(public.is_comp_creator(competition_id) or public.is_admin());
create policy "player submit result" on public.matches for update to authenticated using((home_player=auth.uid() or away_player=auth.uid()) and public.is_comp_member(competition_id)) with check((home_player=auth.uid() or away_player=auth.uid()) and public.is_comp_member(competition_id) and status='completed' and home_score is not null and away_score is not null and submitted_by=auth.uid());

create policy "teams read" on public.teams for select to authenticated using(true);
create policy "teams create own" on public.teams for insert to authenticated with check(owner_id=auth.uid());
create policy "teams update own" on public.teams for update to authenticated using(owner_id=auth.uid() or public.is_admin()) with check(owner_id=auth.uid() or public.is_admin());
create policy "teams delete own" on public.teams for delete to authenticated using(owner_id=auth.uid() or public.is_admin());
create policy "team players read" on public.team_players for select to authenticated using(true);
create policy "team players owner manage" on public.team_players for all to authenticated using(team_id=public.my_team_id() or public.is_admin()) with check(team_id=public.my_team_id() or public.is_admin());
create policy "staff read" on public.staff for select to authenticated using(true);
create policy "staff owner manage" on public.staff for all to authenticated using(team_id=public.my_team_id() or public.is_admin()) with check(team_id=public.my_team_id() or public.is_admin());
create policy "listings read" on public.transfer_listings for select to authenticated using(true);
create policy "list own player" on public.transfer_listings for insert to authenticated with check(from_team_id=public.my_team_id() and player_id=auth.uid());
create policy "cancel own listing" on public.transfer_listings for update to authenticated using(from_team_id=public.my_team_id() or public.is_admin()) with check(from_team_id=public.my_team_id() or public.is_admin());
create policy "transfers read" on public.transfers for select to authenticated using(true);

create or replace function public.buy_player(listing uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare l public.transfer_listings%rowtype; buyer uuid; buyer_budget numeric; begin
  buyer:=public.my_team_id(); if buyer is null then raise exception 'Create your team first.'; end if;
  select * into l from public.transfer_listings where id=listing and status='open' for update;
  if not found then raise exception 'Transfer listing is no longer available.'; end if;
  if l.from_team_id=buyer then raise exception 'You cannot buy your own player.'; end if;
  select budget into buyer_budget from public.teams where id=buyer for update;
  if buyer_budget < l.asking_price then raise exception 'Not enough budget.'; end if;
  update public.teams set budget=budget-l.asking_price where id=buyer;
  update public.teams set budget=budget+l.asking_price where id=l.from_team_id;
  delete from public.team_players where user_id=l.player_id;
  insert into public.team_players(team_id,user_id,position,rating) values(buyer,l.player_id,'CF',70);
  update public.transfer_listings set status='sold' where id=l.id;
  insert into public.transfers(listing_id,player_id,seller_team_id,buyer_team_id,price) values(l.id,l.player_id,l.from_team_id,buyer,l.asking_price);
  return jsonb_build_object('ok',true,'price',l.asking_price);
end $$;

grant execute on function public.buy_player(uuid) to authenticated;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$begin insert into public.profiles(id,display_name) values(new.id,coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1))) on conflict(id) do nothing; return new; end$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- Optional: promote your account to admin after you know its auth.users UUID.
-- update public.profiles set role='admin' where id='YOUR_AUTH_USER_UUID';
