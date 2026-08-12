-- =====================================================================
-- APP_ERROR_LOGS — ilova xatoliklarini masofadan kuzatish uchun jadval
-- =====================================================================
-- Supabase Dashboard -> SQL Editor -> New query -> Run

create table public.app_error_logs (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  user_id uuid references auth.users(id) on delete set null,
  platform text,        -- ios, android, web, macos ...
  screen text,           -- xato qayerda yuz berdi: masalan "auth_signin", "pos_checkout"
  message text not null,
  stack_trace text,
  extra jsonb
);

create index idx_app_error_logs_created on public.app_error_logs(created_at desc);

alter table public.app_error_logs enable row level security;

-- Har kim (login qilmagan bo'lsa ham, masalan kirish xatosi) yozuv qo'sha oladi
create policy "app_error_logs_insert" on public.app_error_logs
  for insert with check (true);

-- Faqat admin o'qiy oladi
create policy "app_error_logs_admin_select" on public.app_error_logs
  for select using (public.is_admin());

-- Faqat admin tozalay (o'chira) oladi
create policy "app_error_logs_admin_delete" on public.app_error_logs
  for delete using (public.is_admin());
