-- Chekni bekor qilish endi to'liq to'g'irlanadi:
-- - qarzga sotuv bo'lsa, mijoz qarzi kamayadi
-- - naqd/karta sotuv bo'lsa, kassadagi avtomatik kirim yozuvi o'chadi
create or replace function public.fn_sale_cancel_restore_stock()
returns trigger as $$
begin
  if new.is_cancelled = true and old.is_cancelled = false then
    update public.products p
       set stock = p.stock + si.qty
      from public.sale_items si
     where si.sale_id = new.id and p.id = si.product_id;

    if new.payment_type = 'qarz' and new.customer_id is not null then
      update public.customers
         set total_debt = total_debt - new.total
       where id = new.customer_id;
    else
      delete from public.cash_transactions where sale_id = new.id;
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer;

-- Admin xato/test cheklarni butunlay o'chira olishi uchun
drop policy if exists "sales_admin_delete" on public.sales;
create policy "sales_admin_delete" on public.sales
  for delete using (public.is_admin());

-- Admin xato to'lov yozuvini o'chira olishi uchun
drop policy if exists "debt_payments_admin_delete" on public.debt_payments;
create policy "debt_payments_admin_delete" on public.debt_payments
  for delete using (public.is_admin());
