-- eFootball Tournament Hub: delete + safe join support
-- The existing schema already has ON DELETE CASCADE for competition members and matches,
-- and an RLS delete policy for competition creators/admins.
-- The app now checks membership before inserting, so duplicate-key join errors are avoided.
-- No destructive SQL migration is required for this fix.

-- Allow tournament creators/admins to reset fixtures/results.
create policy "creator/admin delete matches" on public.matches for delete to authenticated using(public.is_comp_creator(competition_id) or public.is_admin());
