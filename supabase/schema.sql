-- =====================================================================
-- Oziq-ovqat do'koni boshqaruv dasturi — Supabase (PostgreSQL) sxemasi
-- =====================================================================
-- Ushbu faylni Supabase loyihangizda SQL Editor orqali to'liq ishga
-- tushiring (Supabase Dashboard -> SQL Editor -> New query -> Run).

-- ---------------------------------------------------------------------
-- 1. PROFILES (foydalanuvchilar va rollar)
-- ---------------------------------------------------------------------
create type user_role as enum ('admin', 'sotuvchi');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role user_role not null default 'sotuvchi',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Yangi auth.users yozuvi yaratilganda avtomatik profiles yozuvi qo'shish
create function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    coalesce((new.raw_user_meta_data->>'role')::public.user_role, 'sotuvchi'::public.user_role)
  );
  return new;
end;
$$ language plpgsql security definer set search_path = public, auth, pg_temp;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------------------------------------------------------------------
-- 2. CATEGORIES (tovar kategoriyalari)
-- ---------------------------------------------------------------------
create table public.categories (
  id bigint generated always as identity primary key,
  name text not null unique,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3. PRODUCTS (tovarlar)
-- ---------------------------------------------------------------------
create table public.products (
  id bigint generated always as identity primary key,
  name text not null,
  category_id bigint references public.categories(id) on delete set null,
  unit text not null default 'dona',        -- dona, kg, litr, quti ...
  barcode text unique,
  buy_price numeric(14,2) not null default 0,
  sell_price numeric(14,2) not null default 0,
  stock numeric(14,3) not null default 0,
  min_stock numeric(14,3) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_products_name on public.products using gin (to_tsvector('simple', name));

-- ---------------------------------------------------------------------
-- 4. CUSTOMERS (mijozlar / qarzdorlar)
-- ---------------------------------------------------------------------
create table public.customers (
  id bigint generated always as identity primary key,
  full_name text not null,
  phone text,
  note text,
  total_debt numeric(14,2) not null default 0,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 5. SALES (savdo cheklari) va SALE_ITEMS (chek tarkibi)
-- ---------------------------------------------------------------------
create type payment_type as enum ('naqd', 'karta', 'qarz');

create table public.sales (
  id bigint generated always as identity primary key,
  cashier_id uuid references public.profiles(id),
  customer_id bigint references public.customers(id),
  total numeric(14,2) not null default 0,
  payment_type payment_type not null default 'naqd',
  is_cancelled boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.sale_items (
  id bigint generated always as identity primary key,
  sale_id bigint not null references public.sales(id) on delete cascade,
  product_id bigint not null references public.products(id),
  qty numeric(14,3) not null,
  price numeric(14,2) not null,          -- savdo vaqtidagi narx (tarixiy)
  created_at timestamptz not null default now()
);

create index idx_sale_items_sale on public.sale_items(sale_id);
create index idx_sales_created on public.sales(created_at);

-- ---------------------------------------------------------------------
-- 6. DEBT_PAYMENTS (qarz to'lovlari)
-- ---------------------------------------------------------------------
create table public.debt_payments (
  id bigint generated always as identity primary key,
  customer_id bigint not null references public.customers(id),
  amount numeric(14,2) not null,
  note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 7. CASH_TRANSACTIONS (prihod-rashod / kirim-chiqim)
-- ---------------------------------------------------------------------
create type cash_type as enum ('kirim', 'rashod');

create table public.cash_transactions (
  id bigint generated always as identity primary key,
  type cash_type not null,
  amount numeric(14,2) not null,
  category text not null default 'boshqa',   -- ijaraq, ish haqi, kommunal, tovar xaridi, savdo, boshqa
  note text,
  sale_id bigint references public.sales(id),        -- savdodan avtomatik yozuv bo'lsa
  debt_payment_id bigint references public.debt_payments(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create index idx_cash_tx_created on public.cash_transactions(created_at);

-- =====================================================================
-- TRIGGERLAR: biznes logikasini avtomatlashtirish
-- =====================================================================

-- 1) Savdo qatori (sale_item) qo'shilganda tovar qoldig'ini kamaytirish
create function public.fn_sale_item_apply_stock()
returns trigger as $$
begin
  update public.products
     set stock = stock - new.qty,
         updated_at = now()
   where id = new.product_id;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_sale_item_apply_stock
  after insert on public.sale_items
  for each row execute procedure public.fn_sale_item_apply_stock();

-- Chek bekor qilinsa (is_cancelled true bo'lsa): qoldiqni qaytarish,
-- qarz bo'lsa mijoz qarzini kamaytirish, naqd/karta bo'lsa kassadagi
-- avtomatik kirim yozuvini o'chirish.
create function public.fn_sale_cancel_restore_stock()
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

create trigger trg_sale_cancel_restore_stock
  after update on public.sales
  for each row execute procedure public.fn_sale_cancel_restore_stock();

-- 2) Savdo yaratilganda: naqd/karta bo'lsa kassaga kirim, qarz bo'lsa mijoz qarzini oshirish
create function public.fn_sale_after_insert()
returns trigger as $$
begin
  if new.payment_type in ('naqd', 'karta') then
    insert into public.cash_transactions (type, amount, category, note, sale_id, created_by)
    values ('kirim', new.total, 'savdo', 'Savdo #' || new.id, new.id, new.cashier_id);
  elsif new.payment_type = 'qarz' and new.customer_id is not null then
    update public.customers
       set total_debt = total_debt + new.total
     where id = new.customer_id;
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_sale_after_insert
  after insert on public.sales
  for each row execute procedure public.fn_sale_after_insert();

-- 3) Qarz to'lovi kiritilganda: mijoz qarzini kamaytirish + kassaga kirim yozish
create function public.fn_debt_payment_after_insert()
returns trigger as $$
begin
  update public.customers
     set total_debt = total_debt - new.amount
   where id = new.customer_id;

  insert into public.cash_transactions (type, amount, category, note, debt_payment_id, created_by)
  values ('kirim', new.amount, 'qarz_tolovi', coalesce(new.note, 'Qarz to''lovi'), new.id, new.created_by);
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_debt_payment_after_insert
  after insert on public.debt_payments
  for each row execute procedure public.fn_debt_payment_after_insert();

-- 4) create_sale: bitta savdo chekini va uning tarkibini bitta tranzaksiyada
--    atomik tarzda yaratadi, qoldiq yetarli emasligini oldindan tekshiradi.
--    p_items misoli: [{"product_id": 1, "qty": 2, "price": 15000}, ...]
create function public.create_sale(
  p_payment_type payment_type,
  p_customer_id bigint,
  p_items jsonb
) returns bigint
language plpgsql
security definer
as $$
declare
  v_sale_id bigint;
  v_total numeric(14,2) := 0;
  v_item jsonb;
  v_stock numeric(14,3);
  v_name text;
begin
  if not public.is_active_user() then
    raise exception 'Foydalanuvchi faol emas';
  end if;

  if p_payment_type = 'qarz' and p_customer_id is null then
    raise exception 'Qarzga savdo uchun mijoz tanlanishi shart';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'Chekda kamida bitta tovar bo''lishi kerak';
  end if;

  -- qoldiqni oldindan tekshirish
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select stock, name into v_stock, v_name
      from public.products
     where id = (v_item->>'product_id')::bigint
     for update;

    if v_stock is null then
      raise exception 'Tovar topilmadi';
    end if;
    if v_stock < (v_item->>'qty')::numeric then
      raise exception 'Omborda "%" uchun yetarli qoldiq yo''q (bor: %)', v_name, v_stock;
    end if;

    v_total := v_total + (v_item->>'qty')::numeric * (v_item->>'price')::numeric;
  end loop;

  insert into public.sales (cashier_id, customer_id, total, payment_type)
  values (auth.uid(), p_customer_id, v_total, p_payment_type)
  returning id into v_sale_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    insert into public.sale_items (sale_id, product_id, qty, price)
    values (
      v_sale_id,
      (v_item->>'product_id')::bigint,
      (v_item->>'qty')::numeric,
      (v_item->>'price')::numeric
    );
  end loop;

  return v_sale_id;
end;
$$;

grant execute on function public.create_sale(payment_type, bigint, jsonb) to authenticated;

-- =====================================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================================
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.debt_payments enable row level security;
alter table public.cash_transactions enable row level security;

-- Yordamchi funksiya: joriy foydalanuvchi admin ekanini tekshirish
create function public.is_admin()
returns boolean as $$
  select exists (
    select 1 from public.profiles
     where id = auth.uid() and role = 'admin' and is_active = true
  );
$$ language sql security definer stable;

-- Joriy foydalanuvchi faol (is_active) profilga ega ekanini tekshirish
create function public.is_active_user()
returns boolean as $$
  select exists (
    select 1 from public.profiles
     where id = auth.uid() and is_active = true
  );
$$ language sql security definer stable;

-- PROFILES: har kim o'zinikini ko'radi, admin — hammasini
create policy "profiles_select" on public.profiles
  for select using (id = auth.uid() or public.is_admin());
create policy "profiles_admin_all" on public.profiles
  for all using (public.is_admin()) with check (public.is_admin());

-- CATEGORIES: hamma login qilgan o'qiydi, faqat admin yozadi
create policy "categories_select" on public.categories
  for select using (auth.role() = 'authenticated');
create policy "categories_admin_write" on public.categories
  for insert with check (public.is_admin());
create policy "categories_admin_update" on public.categories
  for update using (public.is_admin());
create policy "categories_admin_delete" on public.categories
  for delete using (public.is_admin());

-- PRODUCTS: hamma login qilgan o'qiydi, faqat admin yozadi/o'zgartiradi/o'chiradi
create policy "products_select" on public.products
  for select using (auth.role() = 'authenticated');
create policy "products_admin_write" on public.products
  for insert with check (public.is_admin());
create policy "products_admin_update" on public.products
  for update using (public.is_admin());
create policy "products_admin_delete" on public.products
  for delete using (public.is_admin());

-- CUSTOMERS: hamma login qilgan o'qiydi va qo'sha oladi, faqat admin o'chiradi
create policy "customers_select" on public.customers
  for select using (auth.role() = 'authenticated');
create policy "customers_insert" on public.customers
  for insert with check (public.is_active_user());
create policy "customers_update" on public.customers
  for update using (public.is_active_user());
create policy "customers_admin_delete" on public.customers
  for delete using (public.is_admin());

-- SALES: hamma login qilgan ko'radi va o'zi savdo kirita oladi; bekor qilish faqat admin
create policy "sales_select" on public.sales
  for select using (auth.role() = 'authenticated');
create policy "sales_insert" on public.sales
  for insert with check (public.is_active_user() and cashier_id = auth.uid());
create policy "sales_admin_update" on public.sales
  for update using (public.is_admin());
create policy "sales_admin_delete" on public.sales
  for delete using (public.is_admin());

-- SALE_ITEMS: hamma login qilgan ko'radi va qo'sha oladi
create policy "sale_items_select" on public.sale_items
  for select using (auth.role() = 'authenticated');
create policy "sale_items_insert" on public.sale_items
  for insert with check (public.is_active_user());

-- DEBT_PAYMENTS: hamma login qilgan ko'radi va qo'sha oladi
create policy "debt_payments_select" on public.debt_payments
  for select using (auth.role() = 'authenticated');
create policy "debt_payments_insert" on public.debt_payments
  for insert with check (public.is_active_user() and created_by = auth.uid());
create policy "debt_payments_admin_delete" on public.debt_payments
  for delete using (public.is_admin());

-- CASH_TRANSACTIONS: faqat admin ko'radi va qo'lda yozuv qo'sha oladi
create policy "cash_tx_admin_select" on public.cash_transactions
  for select using (public.is_admin());
create policy "cash_tx_admin_insert" on public.cash_transactions
  for insert with check (public.is_admin());
create policy "cash_tx_admin_update" on public.cash_transactions
  for update using (public.is_admin());
create policy "cash_tx_admin_delete" on public.cash_transactions
  for delete using (public.is_admin());

-- =====================================================================
-- BOSHLANG'ICH MA'LUMOTLAR (ixtiyoriy)
-- =====================================================================
insert into public.categories (name) values
  ('Ichimliklar'), ('Non mahsulotlari'), ('Sut mahsulotlari'),
  ('Gigiyena'), ('Konserva'), ('Boshqa');
