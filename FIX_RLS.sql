-- 1. 创建一个 Security Definer 函数来检查成员资格
-- 这个函数会以创建者(管理员)权限运行，从而绕过 RLS 递归检查
create or replace function public.is_member_of(_household_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from household_members
    where household_id = _household_id
    and user_id = auth.uid()
  );
$$;

-- 2. 删除旧的可能导致递归的策略
drop policy if exists "Households are visible to members" on public.households;
drop policy if exists "Members are visible to members" on public.household_members;

-- 3. 创建新策略，使用上面的函数

-- Households: 成员可见 (或 Owner)
create policy "Households are visible to members"
  on public.households for select
  using (
    public.is_member_of(id)
    or owner_id = auth.uid()
  );

-- Household Members: 成员可见
-- 允许查看自己，或者查看自己所在家庭的其他成员
create policy "Members are visible to members"
  on public.household_members for select
  using (
    public.is_member_of(household_id) 
    or user_id = auth.uid() -- 总是允许看自己，防止极端情况
  );

-- 4. 确保其他策略不受影响 (INSERT/DELETE 策略通常不涉及自身 SELECT 递归，但最好检查)
-- Members can add members: check 逻辑里也用了 exists subquery，也建议改用函数
drop policy if exists "Members can add members" on public.household_members;
create policy "Members can add members"
  on public.household_members for insert
  to authenticated
  with check (
    public.is_member_of(household_id)
    or user_id = auth.uid() -- 允许自建家庭时把自己加进去
  );
