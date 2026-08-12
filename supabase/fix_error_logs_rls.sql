-- =====================================================================
-- app_error_logs uchun RLS'ni ishonchli qayta o'rnatish
-- =====================================================================
-- Muammo: yozuv qo'shishda "new row violates row-level security policy"
-- xatosi chiqayotgan edi — policy noto'g'ri/yarim o'rnatilgan bo'lishi
-- mumkin. Bu fayl avvalgi policy'larni o'chirib, ishonchli qayta yaratadi.
-- Supabase Dashboard -> SQL Editor -> New query -> Run

drop policy if exists "app_error_logs_insert" on public.app_error_logs;
drop policy if exists "app_error_logs_admin_select" on public.app_error_logs;
drop policy if exists "app_error_logs_admin_delete" on public.app_error_logs;

alter table public.app_error_logs enable row level security;

create policy "app_error_logs_insert" on public.app_error_logs
  for insert
  to anon, authenticated
  with check (true);

create policy "app_error_logs_admin_select" on public.app_error_logs
  for select
  to authenticated
  using (public.is_admin());

create policy "app_error_logs_admin_delete" on public.app_error_logs
  for delete
  to authenticated
  using (public.is_admin());

grant insert on public.app_error_logs to anon, authenticated;
grant select, delete on public.app_error_logs to authenticated;
