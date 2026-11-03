-- =====================================================================
-- KASSA YOZUVINI O'CHIRISH — FAQAT ASOSIY ADMIN (owner)
-- =====================================================================
-- Supabase Dashboard -> SQL Editor -> New query -> Run
-- (avval protect_owner.sql ishga tushirilgan bo'lishi kerak: is_owner ustuni)
--
-- cash_transactions'dan o'chirish huquqi oddiy adminlardan olinadi va faqat
-- asosiy adminga beriladi. Savdo bekor qilinganda kassa yozuvini o'chiradigan
-- trigger (security definer) bundan ta'sirlanmaydi.

create or replace function public.is_owner()
returns boolean as $$
  select exists (
    select 1 from public.profiles
     where id = auth.uid() and is_owner = true and is_active = true
  );
$$ language sql security definer stable set search_path = public, pg_temp;

drop policy if exists "cash_tx_admin_delete" on public.cash_transactions;
drop policy if exists "cash_tx_owner_delete" on public.cash_transactions;
create policy "cash_tx_owner_delete" on public.cash_transactions
  for delete using (public.is_owner());
