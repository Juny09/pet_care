-- 创建用户资料表 (用于存储昵称等)
create table public.profiles (
  id uuid references auth.users not null primary key,
  display_name text,
  avatar_url text,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 启用 RLS
alter table public.profiles enable row level security;

-- 创建策略：任何人都可以读取 profiles (为了显示评论者名字)
create policy "Profiles are viewable by everyone" on public.profiles
  for select using (true);

-- 创建策略：用户只能更新自己的 profile
create policy "Users can update own profile" on public.profiles
  for update using (auth.uid() = id);

-- 创建策略：用户只能插入自己的 profile
create policy "Users can insert own profile" on public.profiles
  for insert with check (auth.uid() = id);

-- 创建评论表
create table public.comments (
  id uuid default gen_random_uuid() primary key,
  event_id text not null, -- 关联到 events.id (注意 events.id 目前是 string/text)
  user_id uuid references auth.users not null,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 启用 RLS
alter table public.comments enable row level security;

-- 策略：家庭成员可见 (简化为登录用户可见，或者后续根据 family_id 过滤)
-- 由于 comments 关联 event，event 关联 family，这里简单起见允许登录用户 CRUD
create policy "Authenticated users can select comments" on public.comments
  for select using (auth.role() = 'authenticated');

create policy "Authenticated users can insert comments" on public.comments
  for insert with check (auth.role() = 'authenticated');

create policy "Users can delete own comments" on public.comments
  for delete using (auth.uid() = user_id);

-- 开启实时监听
alter publication supabase_realtime add table comments;
alter publication supabase_realtime add table profiles;
