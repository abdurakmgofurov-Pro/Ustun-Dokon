-- =====================================================================
-- MIJOZGA PUL QAYTARISH (qarz to'langach tovar qaytarilganda)
-- =====================================================================
-- Supabase Dashboard -> SQL Editor -> New query -> Run
--
-- Qarzga olingan tovar uchun qarz to'lanib, keyin sotuv bekor qilinsa
-- (tovar qaytarilsa), mijozning total_debt'i manfiy bo'ladi: do'kon mijozga
-- shuncha qarz. Bu funksiya (faqat admin) pulni qaytaradi: kassaga rashod
-- yozadi (kategoriya 'qaytarish') va mijoz qoldig'ini shuncha oshiradi.

create or replace function public.refund_customer(
  p_customer_id bigint,
  p_amount numeric,
  p_method text default 'naqd'
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_debt numeric;
begin
  if not public.is_admin() then
    raise exception 'Faqat admin pulni qaytara oladi';
  end if;
  if p_method not in ('naqd', 'karta') then
    raise exception 'To''lov turi noto''g''ri';
  end if;

  select total_debt into v_debt
    from public.customers where id = p_customer_id for update;
  if v_debt is null then
    raise exception 'Mijoz topilmadi';
  end if;
  if p_amount <= 0 or p_amount > -v_debt then
    raise exception 'Summa noto''g''ri (qaytariladigan: %)', -v_debt;
  end if;

  update public.customers
     set total_debt = total_debt + p_amount
   where id = p_customer_id;

  insert into public.cash_transactions
    (type, amount, category, note, created_by, payment_method)
  values
    ('rashod', p_amount, 'qaytarish', 'Mijozga pul qaytarildi', auth.uid(), p_method);
end;
$$;

revoke all on function public.refund_customer(bigint, numeric, text) from public, anon;
grant execute on function public.refund_customer(bigint, numeric, text) to authenticated;
