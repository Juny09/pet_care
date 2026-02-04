-- UPDATE_SCHEMA_V3.sql
-- Run this script in your Supabase SQL Editor to add tables for Health, Finance, and Inventory features

-- 1. Weight Logs Table
create table public.weight_logs (
  id uuid default gen_random_uuid() primary key,
  pet_id text not null, -- Assuming pet_id is string based on previous code, or use uuid if pets table exists
  weight numeric not null,
  date timestamp with time zone default timezone('utc'::text, now()) not null,
  note text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Vaccinations Table
create table public.vaccinations (
  id uuid default gen_random_uuid() primary key,
  pet_id text not null,
  vaccine_name text not null,
  date_administered timestamp with time zone not null,
  next_due_date timestamp with time zone,
  vet_name text,
  notes text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Vet Visits Table
create table public.vet_visits (
  id uuid default gen_random_uuid() primary key,
  pet_id text not null,
  visit_date timestamp with time zone not null,
  clinic_name text,
  reason text,
  diagnosis text,
  prescription text,
  cost numeric,
  notes text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. Expenses Table
create table public.expenses (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  pet_id text, -- Optional: link to specific pet
  amount numeric not null,
  category text not null, -- 'Food', 'Toys', 'Vet', 'Grooming', 'Other'
  date timestamp with time zone default timezone('utc'::text, now()) not null,
  note text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. Inventory Table
create table public.inventory (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  item_name text not null,
  quantity numeric not null,
  unit text, -- 'cans', 'kg', 'bags', etc.
  threshold numeric, -- Alert when quantity <= threshold
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.weight_logs enable row level security;
alter table public.vaccinations enable row level security;
alter table public.vet_visits enable row level security;
alter table public.expenses enable row level security;
alter table public.inventory enable row level security;

-- Policies (Assuming authenticated users can read/write their own data)
-- For simplicity in this demo, we'll allow authenticated users to access all data linked to their pets/user_id
-- Ideally, policies should check pet ownership.

-- Weight Logs
create policy "Users can view weight logs" on public.weight_logs
  for select using (auth.role() = 'authenticated');
create policy "Users can insert weight logs" on public.weight_logs
  for insert with check (auth.role() = 'authenticated');
create policy "Users can update weight logs" on public.weight_logs
  for update using (auth.role() = 'authenticated');
create policy "Users can delete weight logs" on public.weight_logs
  for delete using (auth.role() = 'authenticated');

-- Vaccinations
create policy "Users can view vaccinations" on public.vaccinations
  for select using (auth.role() = 'authenticated');
create policy "Users can insert vaccinations" on public.vaccinations
  for insert with check (auth.role() = 'authenticated');
create policy "Users can update vaccinations" on public.vaccinations
  for update using (auth.role() = 'authenticated');
create policy "Users can delete vaccinations" on public.vaccinations
  for delete using (auth.role() = 'authenticated');

-- Vet Visits
create policy "Users can view vet visits" on public.vet_visits
  for select using (auth.role() = 'authenticated');
create policy "Users can insert vet visits" on public.vet_visits
  for insert with check (auth.role() = 'authenticated');
create policy "Users can update vet visits" on public.vet_visits
  for update using (auth.role() = 'authenticated');
create policy "Users can delete vet visits" on public.vet_visits
  for delete using (auth.role() = 'authenticated');

-- Expenses
create policy "Users can manage their own expenses" on public.expenses
  for all using (auth.uid() = user_id);

-- Inventory
create policy "Users can manage their own inventory" on public.inventory
  for all using (auth.uid() = user_id);
