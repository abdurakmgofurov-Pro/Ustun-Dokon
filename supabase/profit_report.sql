-- =====================================================================
-- FOYDA HISOBOTI — sale_items'ga tannarx (cost) ustunini qo'shish
-- =====================================================================
-- Supabase Dashboard -> SQL Editor -> New query -> Run
--
-- sale_items.price — sotilgan paytdagi SOTISH narxini saqlaydi (mavjud).
-- Foyda (sotish - tannarx) hisoblash uchun sotilgan paytdagi KIRIM
-- narxini ham saqlash kerak, chunki mahsulotning joriy buy_price'i
-- keyinchalik o'zgarishi mumkin (o'tgan oylar hisoboti buzilib qolmasligi
-- uchun tarixiy qiymat saqlanadi).

alter table public.sale_items
  add column if not exists cost numeric(14,2) not null default 0;

-- Eski (ushbu ustun qo'shilishidan oldingi) yozuvlar uchun eng yaqin
-- taxmin sifatida mahsulotning hozirgi kirim narxini qo'yamiz.
update public.sale_items si
   set cost = p.buy_price
  from public.products p
 where si.product_id = p.id
   and si.cost = 0;

-- create_sale funksiyasini cost'ni ham yozadigan qilib yangilaymiz
create or replace function public.create_sale(
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
  v_buy_price numeric(14,2);
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
    select buy_price into v_buy_price
      from public.products
     where id = (v_item->>'product_id')::bigint;

    insert into public.sale_items (sale_id, product_id, qty, price, cost)
    values (
      v_sale_id,
      (v_item->>'product_id')::bigint,
      (v_item->>'qty')::numeric,
      (v_item->>'price')::numeric,
      coalesce(v_buy_price, 0)
    );
  end loop;

  return v_sale_id;
end;
$$;
