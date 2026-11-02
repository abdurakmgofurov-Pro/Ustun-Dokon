-- =====================================================================
-- SOTUVCHI (sotuvchi roli) RLS TUZATISHLARI
-- =====================================================================
-- Supabase Dashboard -> SQL Editor -> New query -> Run
--
-- Muammolar:
--  1) customers_update: har qanday faol foydalanuvchi mijozning total_debt'ini
--     to'g'ridan-to'g'ri o'zgartira olardi (qarzni 0 qilish mumkin edi).
--  2) sales_insert / sale_items_insert: create_sale funksiyasini chetlab o'tib,
--     to'g'ridan-to'g'ri INSERT qilish mumkin edi (triggerlar security definer
--     bo'lgani uchun qoldiq, kassa va qarz buzilardi).
--  3) debt_payments_insert: manfiy yoki nol summa tekshirilmasdi.
--
-- Ilova bu amallarni to'g'ridan-to'g'ri ishlatmaydi: savdo create_sale RPC
-- orqali, mijoz faqat INSERT bilan yaratiladi, qarz to'lovi debt_payments INSERT.
-- create_sale va triggerlar security definer — RLS'ni chetlab o'tadi.

-- 1) Mijozni tahrirlash — faqat admin
drop policy if exists "customers_update" on public.customers;
drop policy if exists "customers_admin_update" on public.customers;
create policy "customers_admin_update" on public.customers
  for update using (public.is_admin());

-- 2) Savdoni faqat create_sale orqali yaratish (to'g'ridan-to'g'ri INSERT yo'q)
drop policy if exists "sales_insert" on public.sales;
drop policy if exists "sale_items_insert" on public.sale_items;

-- 3) Qarz to'lovi summasi musbat bo'lishi shart
alter table public.debt_payments
  drop constraint if exists debt_payments_amount_positive;
alter table public.debt_payments
  add constraint debt_payments_amount_positive check (amount > 0);
