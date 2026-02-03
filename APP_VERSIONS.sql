-- 创建 App 版本表
create table public.app_versions (
  id uuid default gen_random_uuid() primary key,
  version text not null, -- 例如 '1.0.3'
  download_url text not null, -- 新版本下载链接
  force_update boolean default false, -- 是否强制更新
  release_notes text, -- 更新日志
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 开启 RLS
alter table public.app_versions enable row level security;

-- 允许所有人读取版本信息 (无需登录)
create policy "Allow public read access"
  on public.app_versions for select
  using ( true );

-- 仅允许 Service Role (或管理员) 插入/修改
-- (在 Supabase Dashboard 手动操作，或者通过 Service Role Key 操作)
-- 这里不需要给普通用户写权限

-- 示例：插入一个新版本 (请在 SQL Editor 中运行)
-- insert into public.app_versions (version, download_url, release_notes)
-- values ('1.0.4', 'https://example.com/app-release.apk', '修复了一些 bug，优化了体验。');
