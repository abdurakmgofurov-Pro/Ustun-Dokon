-- =====================================================================
-- ASOSIY ADMINNI (owner) HIMOYA QILISH
-- =====================================================================
-- Supabase Dashboard -> SQL Editor -> New query -> Run
--
-- Asosiy admin boshqa adminlar tomonidan o'chirilmaydi, faolsizlantirilmaydi
-- va roli o'zgartirilmaydi; "owner" belgisini hech kim API orqali
-- o'zgartira olmaydi. Himoya ilova (API) so'rovlariga ishlaydi; SQL Editor
-- (postgres) orqali o'zgartirish mumkin — bu favqulodda yo'l.
-- Xodimni butunlay o'chirish (auth.users) esa manage-employee Edge Function
-- ichida ham tekshiriladi (u service_role bilan ishlagani uchun).

alter table public.profiles
  add column if not exists is_owner boolean not null default false;

-- Asosiy admin: Abdurahim (abdurakmgofurov@gmail.com)
update public.profiles
   set is_owner = true
 where id = '056d631c-ef42-4703-94c1-c70deab5b91d';

create or replace function public.fn_protect_owner()
returns trigger as $$
begin
  -- auth.uid() null bo'lsa — SQL Editor yoki service_role (ilova foydalanuvchisi emas)
  if auth.uid() is null then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if tg_op = 'DELETE' then
    if old.is_owner then
      raise exception 'Asosiy adminni o''chirib bo''lmaydi';
    end if;
    return old;
  end if;

  if new.is_owner is distinct from old.is_owner then
    raise exception 'Asosiy admin belgisini o''zgartirib bo''lmaydi';
  end if;
  if old.is_owner and (new.role is distinct from old.role
                       or new.is_active is distinct from old.is_active) then
    raise exception 'Asosiy adminning roli va holatini o''zgartirib bo''lmaydi';
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public, pg_temp;

drop trigger if exists trg_protect_owner on public.profiles;
create trigger trg_protect_owner
  before update or delete on public.profiles
  for each row execute procedure public.fn_protect_owner();
