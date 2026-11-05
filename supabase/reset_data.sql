-- =====================================================================
-- BARCHA DO'KON MA'LUMOTLARINI O'CHIRISH (QAYTARIB BO'LMAYDI)
-- =====================================================================
-- Supabase Dashboard -> SQL Editor -> New query -> Run
--
-- O'chiriladi: savdolar, savdo qatorlari, kassa (kirim-chiqim), qarz
-- to'lovlari, mijozlar, mahsulotlar, kategoriyalar, xato jurnali.
-- QOLADI: profiles va auth.users (admin/xodim hisoblari) — aks holda
-- ilovaga kirib bo'lmay qoladi.
--
-- TRUNCATE qator triggerlarini ishga tushirmaydi, shuning uchun qoldiq
-- va qarz qayta hisoblanmaydi. Identity (id) hisoblagichlari 1 dan boshlanadi.

truncate table
  public.sale_items,
  public.cash_transactions,
  public.debt_payments,
  public.debt_entries,
  public.sales,
  public.customers,
  public.products,
  public.categories,
  public.app_error_logs
restart identity;

-- Tekshiruv: hammasi 0 bo'lishi kerak
select 'sales' t, count(*) from public.sales
union all select 'sale_items', count(*) from public.sale_items
union all select 'cash_transactions', count(*) from public.cash_transactions
union all select 'debt_payments', count(*) from public.debt_payments
union all select 'customers', count(*) from public.customers
union all select 'products', count(*) from public.products
union all select 'categories', count(*) from public.categories
union all select 'app_error_logs', count(*) from public.app_error_logs;
