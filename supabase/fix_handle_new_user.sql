create or replace function public.handle_new_user()
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
