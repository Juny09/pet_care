insert into public.app_versions (
  version, 
  download_url, 
  release_notes, 
  force_update
) values (
  '1.0.5', 
  'https://your-apk-download-url.com/app-release.apk', -- 请替换为实际的下载链接 
  '修复了家庭共享和登录问题，优化了网络连接体验。', 
  false
);
