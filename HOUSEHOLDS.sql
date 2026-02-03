-- 1. 创建 households 表
create table public.households (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  owner_id uuid references auth.users not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. 创建 household_members 表
create table public.household_members (
  id uuid default gen_random_uuid() primary key,
  household_id uuid references public.households on delete cascade not null,
  user_id uuid references auth.users not null,
  role text default 'member', -- 'owner', 'admin', 'member'
  joined_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(household_id, user_id)
);

-- 3. 开启 RLS
alter table public.households enable row level security;
alter table public.household_members enable row level security;

-- 4. RLS 策略

-- Households: 成员可见
create policy "Households are visible to members"
  on public.households for select
  using (
    exists (
      select 1 from public.household_members
      where household_id = public.households.id
      and user_id = auth.uid()
    )
    or owner_id = auth.uid()
  );

-- Households: 只有 owner 可以插入/更新/删除 (简化逻辑：允许所有认证用户创建)
create policy "Authenticated users can create households"
  on public.households for insert
  to authenticated
  with check ( owner_id = auth.uid() );

-- Household Members: 成员可见
create policy "Members are visible to members"
  on public.household_members for select
  using (
    exists (
      select 1 from public.household_members as hm
      where hm.household_id = public.household_members.household_id
      and hm.user_id = auth.uid()
    )
  );

-- Household Members: 只有家庭成员可以邀请(插入)其他人 (或者简化为只要是家庭成员就可以加人)
create policy "Members can add members"
  on public.household_members for insert
  to authenticated
  with check (
    exists (
      select 1 from public.household_members
      where household_id = public.household_members.household_id
      and user_id = auth.uid()
    )
    or
    -- 允许用户自己加入 (通过邀请码等逻辑，这里先宽泛一点，或者由前端控制)
    -- 为了安全，通常应该由 owner 邀请，或者后端函数处理。
    -- 这里为了简化 MVP，允许认证用户自己把自己加进去 (加入逻辑)
    user_id = auth.uid() 
  );
  
-- 允许用户删除自己 (退出) 或 Owner 删除成员
create policy "Members can leave or Owner can remove"
  on public.household_members for delete
  using (
    user_id = auth.uid() -- 退出
    or 
    exists ( -- Owner 删除
      select 1 from public.households
      where id = public.household_members.household_id
      and owner_id = auth.uid()
    )
  );

-- 5. 修改 pets 表，添加 household_id
-- 注意：这需要迁移现有数据。
-- 这里的逻辑是：如果 pet.family_id 是 user_id，那么它是私有的（或者默认家庭）。
-- 为了兼容旧逻辑，我们可以把 family_id 视为 household_id。
-- 但为了区分“个人”和“共享”，我们建议：
-- 个人宠物：family_id = user_id (现状)
-- 共享宠物：family_id = household_id (UUID)
-- 这样其实逻辑是一样的，只是我们需要一个 UI 来管理这些 ID。

-- 为了支持“选择哪个宠物共享”，我们需要一个“移动宠物”的功能，把 pet.family_id 从 user_id 改为 household_id。
