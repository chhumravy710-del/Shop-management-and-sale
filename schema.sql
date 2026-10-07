-- Supabase SQL: run this once in SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  price numeric(12,2) not null default 0,
  cost numeric(12,2) not null default 0,
  stock integer not null default 0,
  min_stock integer not null default 5,
  created_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  phone text default '',
  address text default '',
  created_at timestamptz not null default now()
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  amount numeric(12,2) not null default 0,
  expense_date date not null default current_date,
  note text default '',
  created_at timestamptz not null default now()
);

create table if not exists public.shop_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  shop_name text not null default 'ហាងរបស់ខ្ញុំ',
  phone text default '',
  address text default '',
  currency text not null default '$',
  updated_at timestamptz not null default now()
);

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  invoice text not null,
  customer_id uuid references public.customers(id) on delete set null,
  customer_name text not null default 'អតិថិជនទូទៅ',
  sale_date date not null default current_date,
  total numeric(12,2) not null default 0,
  profit numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id),
  product_name text not null,
  qty integer not null check(qty > 0),
  price numeric(12,2) not null,
  cost numeric(12,2) not null default 0
);

alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.expenses enable row level security;
alter table public.shop_settings enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;

create policy "own products" on public.products for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "own customers" on public.customers for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "own expenses" on public.expenses for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "own settings" on public.shop_settings for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "own sales" on public.sales for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "own sale items" on public.sale_items for all using (auth.uid()=user_id) with check (auth.uid()=user_id);

create or replace function public.create_sale(p_customer_id uuid, p_customer_name text, p_items jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_sale uuid;
  v_total numeric(12,2) := 0;
  v_profit numeric(12,2) := 0;
  i jsonb;
  p record;
  q integer;
  pr numeric(12,2);
begin
  if v_user is null then raise exception 'Not authenticated'; end if;
  if jsonb_array_length(p_items)=0 then raise exception 'No items'; end if;

  insert into sales(user_id,invoice,customer_id,customer_name)
  values(v_user,'INV-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS'),p_customer_id,coalesce(nullif(p_customer_name,''),'អតិថិជនទូទៅ'))
  returning id into v_sale;

  for i in select * from jsonb_array_elements(p_items) loop
    q := (i->>'qty')::integer;
    pr := (i->>'price')::numeric;
    select * into p from products where id=(i->>'product_id')::uuid and user_id=v_user for update;
    if not found then raise exception 'Product not found'; end if;
    if q <= 0 or p.stock < q then raise exception 'Insufficient stock: %',p.name; end if;

    insert into sale_items(sale_id,user_id,product_id,product_name,qty,price,cost)
    values(v_sale,v_user,p.id,p.name,q,pr,p.cost);

    update products set stock=stock-q where id=p.id and user_id=v_user;
    v_total := v_total + q*pr;
    v_profit := v_profit + q*(pr-p.cost);
  end loop;

  update sales set total=v_total,profit=v_profit where id=v_sale;
  return v_sale;
end;
$$;

revoke all on function public.create_sale(uuid,text,jsonb) from public;
grant execute on function public.create_sale(uuid,text,jsonb) to authenticated;
