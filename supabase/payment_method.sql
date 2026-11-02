-- =====================================================================
-- TO'LOV TURI (naqd / karta) — kassa qoldig'ini aniq ajratish uchun
-- =====================================================================
-- Supabase Dashboard -> SQL Editor -> New query -> Run
--
-- cash_transactions va debt_payments'ga payment_method ustuni qo'shiladi
-- (standart: naqd). Savdodan avtomatik yoziladigan kirim savdo to'lov
-- turini oladi, qarz to'lovidan yoziladigan kirim esa to'lov turini
-- debt_payments'dan oladi.

alter table public.cash_transactions
  add column if not exists payment_method text not null default 'naqd';
alter table public.cash_transactions
  drop constraint if exists cash_transactions_payment_method_check;
alter table public.cash_transactions
  add constraint cash_transactions_payment_method_check
  check (payment_method in ('naqd', 'karta'));

alter table public.debt_payments
  add column if not exists payment_method text not null default 'naqd';
alter table public.debt_payments
  drop constraint if exists debt_payments_payment_method_check;
alter table public.debt_payments
  add constraint debt_payments_payment_method_check
  check (payment_method in ('naqd', 'karta'));

-- Eski karta savdolaridan yozilgan kirimlarni to'g'rilash
update public.cash_transactions ct
   set payment_method = 'karta'
  from public.sales s
 where ct.sale_id = s.id and s.payment_type = 'karta';

create or replace function public.fn_sale_after_insert()
returns trigger as $$
begin
  if new.payment_type in ('naqd', 'karta') then
    insert into public.cash_transactions
      (type, amount, category, note, sale_id, created_by, payment_method)
    values
      ('kirim', new.total, 'savdo', 'Savdo #' || new.id, new.id, new.cashier_id,
       new.payment_type::text);
  elsif new.payment_type = 'qarz' and new.customer_id is not null then
    update public.customers
       set total_debt = total_debt + new.total
     where id = new.customer_id;
  end if;
  return new;
end;
$$ language plpgsql security definer;

create or replace function public.fn_debt_payment_after_insert()
returns trigger as $$
begin
  update public.customers
     set total_debt = total_debt - new.amount
   where id = new.customer_id;

  insert into public.cash_transactions
    (type, amount, category, note, debt_payment_id, created_by, payment_method)
  values
    ('kirim', new.amount, 'qarz_tolovi', coalesce(new.note, 'Qarz to''lovi'),
     new.id, new.created_by, new.payment_method);
  return new;
end;
$$ language plpgsql security definer;
