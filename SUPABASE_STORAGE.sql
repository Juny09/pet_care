-- 开启 Storage 扩展 (通常默认开启)
-- 1. 创建 bucket (如果还没有)
insert into storage.buckets (id, name, public)
values ('pet_photos', 'pet_photos', true)
on conflict (id) do nothing;

-- 2. 允许公开读取 (Public Access)
create policy "Public Access"
  on storage.objects for select
  using ( bucket_id = 'pet_photos' );

-- 3. 允许认证用户上传 (Authenticated Upload)
create policy "Authenticated Upload"
  on storage.objects for insert
  to authenticated
  with check ( bucket_id = 'pet_photos' );

-- 4. 允许用户更新/删除自己的文件 (Optional)
create policy "Users can update own files"
  on storage.objects for update
  to authenticated
  using ( auth.uid() = owner );

create policy "Users can delete own files"
  on storage.objects for delete
  to authenticated
  using ( auth.uid() = owner );
