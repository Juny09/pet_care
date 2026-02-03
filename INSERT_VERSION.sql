insert into public.app_versions (
  version, 
  download_url, 
  release_notes, 
  force_update
) values (
  '1.0.5', 
  
  -- 方式 3 (GitHub Releases - 推荐且免费):
  -- 1. 在 GitHub 仓库页面点击右侧 "Releases" -> "Draft a new release"
  -- 2. Tag version 填 "v1.0.5", Title 填 "v1.0.5"
  -- 3. 在下方 "Attach binaries..." 处上传你的 APK 文件
  -- 4. 发布 Release
  -- 5. 右键点击上传后的 APK 链接，选择 "复制链接地址"
  -- 链接格式通常为: https://github.com/Juny09/pet_care/releases/download/v1.0.5/app-release.apk
  'https://github.com/Juny09/pet_care/releases/download/v1.0.5/app-release.apk', 
  
  '修复了家庭共享和登录问题，优化了网络连接体验。', 
  false
);
