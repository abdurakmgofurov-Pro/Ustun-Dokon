-- =====================================================================
-- QO'LDA QARZ QO'SHISH (savdosiz, masalan eski daftar qarzlari)
-- =====================================================================
-- Supabase Dashboard -> SQL Editor -> New query -> Run
--
-- debt_entries — mijozga qo'lda qo'shilgan qarzlar tarixi. Qo'shish faqat
-- add_customer_debt funksiyasi orqali (faqat admin): mijoz total_debt'i
-- oshadi va yozuv tarixga tushadi. Kassaga ta'sir qilmaydi (pul harakati yo'q).

create table if not exists public.debt_entries (
  id bigint generated always as identity primary key,
  customer_id bigint not null references public.customers(id),
  amount numeric(14,2) not null check (amount > 0),
  note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_debt_entries_customer
  on public.debt_entries(customer_id);

alter table public.debt_entries enable row level security;

drop policy if exists "debt_entries_select" on public.debt_entries;
create policy "debt_entries_select" on public.debt_entries
  for select using (auth.role() = 'authenticated');

create or replace function public.add_customer_debt(
  p_customer_id bigint,
  p_amount numeric,
  p_note text default null
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Faqat admin qarz qo''sha oladi';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Summa noto''g''ri';
  end if;

  update public.customers
     set total_debt = total_debt + p_amount
   where id = p_customer_id;
  if not found then
    raise exception 'Mijoz topilmadi';
  end if;

  insert into public.debt_entries (customer_id, amount, note, created_by)
  values (p_customer_id, p_amount, nullif(trim(p_note), ''), auth.uid());
end;
$$;

revoke all on function public.add_customer_debt(bigint, numeric, text) from public, anon;
grant execute on function public.add_customer_debt(bigint, numeric, text) to authenticated;
