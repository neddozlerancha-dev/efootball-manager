-- V10: realistic match centre + reliable tournament creation
alter table public.matches add column if not exists screenshot_url text;
alter table public.matches add column if not exists home_shots integer default 0;
alter table public.matches add column if not exists away_shots integer default 0;
alter table public.matches add column if not exists home_possession integer default 0;
alter table public.matches add column if not exists away_possession integer default 0;

create or replace function public.create_competition(
 p_name text,p_type text,p_format text,p_max_players integer,p_start_date date default null,p_end_date date default null
) returns uuid language plpgsql security definer set search_path=public as $$
declare new_id uuid;
begin
 if auth.uid() is null then raise exception 'You must be logged in.'; end if;
 if length(trim(p_name))<2 then raise exception 'Competition name is required.'; end if;
 insert into public.competitions(name,type,format,creator_id,max_players,start_date,end_date)
 values(trim(p_name),p_type::public.competition_type,p_format::public.competition_format,auth.uid(),greatest(2,least(coalesce(p_max_players,8),64)),p_start_date,p_end_date)
 returning id into new_id;
 insert into public.competition_members(competition_id,user_id) values(new_id,auth.uid());
 return new_id;
end $$;
grant execute on function public.create_competition(text,text,text,integer,date,date) to authenticated;

insert into storage.buckets(id,name,public) values('match-screenshots','match-screenshots',true)
on conflict (id) do nothing;

drop policy if exists "match screenshots upload" on storage.objects;
create policy "match screenshots upload" on storage.objects for insert to authenticated
with check (bucket_id='match-screenshots' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists "match screenshots read" on storage.objects;
create policy "match screenshots read" on storage.objects for select to public
using (bucket_id='match-screenshots');
