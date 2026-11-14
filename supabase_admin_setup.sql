-- THE LEELA CAFE: secure ordering RPC + admin access
-- Run once in Supabase SQL Editor AFTER the 3 base tables and 100 menu rows exist.
-- Admin email is pre-approved. Create its Auth account from the website Admin Login panel.

create table if not exists public.admin_users (
  email text primary key
);

alter table public.admin_users enable row level security;
insert into public.admin_users(email)
values ('theleelacafe2000@gmail.com')
on conflict (email) do nothing;

drop policy if exists "Customers can place orders" on public.orders;
drop policy if exists "Customers can add order items" on public.order_items;

revoke insert on public.orders from anon, authenticated;
revoke insert on public.order_items from anon, authenticated;

drop policy if exists "Admins can read orders" on public.orders;
drop policy if exists "Admins can update orders" on public.orders;
drop policy if exists "Admins can read order items" on public.order_items;
drop policy if exists "Admins can manage menu" on public.menu_items;
drop policy if exists "Admin can read own admin record" on public.admin_users;

create policy "Admin can read own admin record"
on public.admin_users for select to authenticated
using (email = (select auth.jwt()->>'email'));

create policy "Admins can read orders"
on public.orders for select to authenticated
using (exists (select 1 from public.admin_users a where a.email = (select auth.jwt()->>'email')));

create policy "Admins can update orders"
on public.orders for update to authenticated
using (exists (select 1 from public.admin_users a where a.email = (select auth.jwt()->>'email')))
with check (exists (select 1 from public.admin_users a where a.email = (select auth.jwt()->>'email')));

create policy "Admins can read order items"
on public.order_items for select to authenticated
using (exists (select 1 from public.admin_users a where a.email = (select auth.jwt()->>'email')));

create policy "Admins can manage menu"
on public.menu_items for all to authenticated
using (exists (select 1 from public.admin_users a where a.email = (select auth.jwt()->>'email')))
with check (exists (select 1 from public.admin_users a where a.email = (select auth.jwt()->>'email')));

grant select on public.admin_users to authenticated;
grant select, update on public.orders to authenticated;
grant select on public.order_items to authenticated;
grant select, insert, update on public.menu_items to authenticated;

create or replace function public.place_order(
  p_customer_name text,
  p_phone text,
  p_order_type text,
  p_address text,
  p_payment_method text,
  p_items jsonb
) returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subtotal numeric(10,2) := 0;
  v_delivery numeric(10,2) := 0;
  v_total numeric(10,2);
  v_order_id bigint;
  v_item jsonb;
  v_menu public.menu_items%rowtype;
  v_qty integer;
begin
  if length(trim(coalesce(p_customer_name,''))) < 2 then
    raise exception 'Please enter your name';
  end if;
  if length(regexp_replace(coalesce(p_phone,''), '\D', '', 'g')) < 10 then
    raise exception 'Please enter a valid mobile number';
  end if;
  if p_order_type not in ('delivery','takeaway') then
    raise exception 'Invalid order type';
  end if;
  if p_order_type = 'delivery' and length(trim(coalesce(p_address,''))) < 5 then
    raise exception 'Please enter your delivery address';
  end if;
  if p_payment_method <> 'cash' then
    raise exception 'UPI payment is not enabled yet';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Your cart is empty';
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_qty := (v_item->>'quantity')::integer;
    if v_qty < 1 or v_qty > 20 then raise exception 'Invalid item quantity'; end if;
    select * into v_menu from public.menu_items
      where id = (v_item->>'menu_item_id')::bigint and available = true;
    if not found then raise exception 'A selected menu item is unavailable'; end if;
    v_subtotal := v_subtotal + v_menu.price * v_qty;
  end loop;

  if p_order_type = 'delivery' and v_subtotal < 300 then v_delivery := 50; end if;
  v_total := v_subtotal + v_delivery;

  insert into public.orders(customer_name,phone,order_type,address,payment_method,subtotal,delivery_fee,total,status)
  values(trim(p_customer_name),trim(p_phone),p_order_type,nullif(trim(coalesce(p_address,'')),''),p_payment_method,v_subtotal,v_delivery,v_total,'new')
  returning id into v_order_id;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_qty := (v_item->>'quantity')::integer;
    select * into v_menu from public.menu_items
      where id = (v_item->>'menu_item_id')::bigint and available = true;
    insert into public.order_items(order_id,item_name,quantity,price)
    values(v_order_id,v_menu.name,v_qty,v_menu.price);
  end loop;

  return v_order_id;
end;
$$;

revoke all on function public.place_order(text,text,text,text,text,jsonb) from public;
grant execute on function public.place_order(text,text,text,text,text,jsonb) to anon, authenticated;
