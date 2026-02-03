# 宠物护理 App 部署指南

本指南将帮助你将 App 部署到 Web、Android 和 iOS 平台。

## 1. 准备工作：Supabase 配置 (非常重要！)

在部署之前，你必须确保 Supabase 后台允许你的生产环境 URL 进行跳转。

1.  登录 [Supabase Dashboard](https://supabase.com/dashboard)。
2.  进入 **Authentication** -> **URL Configuration**。
3.  **Site URL**: 设置为你的主要网站地址（例如 Vercel 分配的域名）。
4.  **Redirect URLs**: 添加所有允许跳转的地址：
    *   `io.supabase.petcare://login-callback/` (App 必备)
    *   `https://<your-project>.vercel.app/` (Web 生产环境)
    *   `http://localhost:8080/` (本地开发)

---

## 2. Web 部署 (最简单)

推荐使用 Vercel 或 Netlify，它们对 Flutter Web 支持很好且免费。

### 步骤：
1.  **构建 Web 版本**：
    在终端运行：
    ```bash
    flutter build web --release --no-tree-shake-icons
    ```
    *注意：如果遇到 Icon 报错，必须加上 `--no-tree-shake-icons` 参数。*
    构建产物在 `build/web` 目录下。

2.  **部署到 Vercel (推荐)**：
    *   注册/登录 [Vercel](https://vercel.com)。
    *   安装 Vercel CLI: `npm i -g vercel` (或直接在网页上传)。
    *   在项目根目录运行 `vercel`。
    *   一路回车，Vercel 会自动检测并部署。
    *   部署完成后，Vercel 会给你一个域名 (例如 `pet-care-app.vercel.app`)。
    *   **关键**：把这个域名添加到 Supabase 的 **Redirect URLs** 中。

---

## 3. Android 部署

### 步骤：
1.  **构建 APK (安装包)**：
    ```bash
    flutter build apk --release --no-tree-shake-icons
    ```
    *注意：如果遇到 Icon 报错，必须加上 `--no-tree-shake-icons` 参数。*
    产物路径：`build/app/outputs/flutter-apk/app-release.apk`。
    你可以直接把这个 APK 发给朋友安装。

2.  **构建 App Bundle (发布到 Google Play)**：
    ```bash
    flutter build appbundle --release --no-tree-shake-icons
    ```
    产物路径：`build/app/outputs/bundle/release/app-release.aab`。

### 注意事项：
*   如果要发布到 Google Play，你需要创建一个 Keystore 并配置签名。
*   你需要支付 **$25 (一次性)** 注册 Google Play Developer 账号。

### 详细发布步骤 (Google Play Store):

1.  **创建密钥库 (Keystore)**:
    在 Mac 终端运行：
    ```bash
    keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
    ```
    *请妥善保管这个文件和密码，丢失后无法更新 App！*

2.  **配置签名**:
    创建 `android/key.properties` 文件，填入：
    ```
    storePassword=<你的密码>
    keyPassword=<你的密码>
    keyAlias=upload
    storeFile=/Users/<你的用户名>/upload-keystore.jks
    ```
    并在 `android/app/build.gradle` 中引用它 (Flutter 默认配置通常需要手动修改，参考官方文档)。

3.  **上传到 Google Play Console**:
    *   登录 [Google Play Console](https://play.google.com/console)。
    *   创建新应用。
    *   在 "App releases" 中创建新版本，上传 `app-release.aab` 文件。
    *   填写商店信息 (截图、描述、隐私政策等)。
    *   提交审核 (通常需要 1-3 天)。

---

## 4. iOS 部署 (需要 Mac 和 Xcode)

### 步骤：
1.  **准备环境**：
    确保你安装了 Xcode 和 CocoaPods。
    确保项目已包含 iOS 平台支持：`flutter create . --platforms ios`

2.  **构建 iOS 包**：
    ```bash
    flutter build ios --release --no-tree-shake-icons
    ```
    *注意：如果遇到 Icon 报错，必须加上 `--no-tree-shake-icons` 参数。*

3.  **配置 Deep Link (Supabase 登录必须)**：
    确保 `ios/Runner/Info.plist` 中包含以下配置：
    ```xml
    <key>CFBundleURLTypes</key>
    <array>
      <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
          <string>io.supabase.petcare</string>
        </array>
      </dict>
    </array>
    ```

4.  **归档与发布**：
    *   打开 `ios/Runner.xcworkspace` (使用 Xcode)。
    *   选择目标设备为 `Any iOS Device (arm64)`。
    *   点击菜单栏 `Product` -> `Archive`。
    *   归档完成后，点击 `Distribute App` 上传到 App Store Connect。

### 详细发布步骤 (Apple App Store):

1.  **注册账号**:
    你需要注册 [Apple Developer Program](https://developer.apple.com/)，费用为 **$99/年**。

2.  **App Store Connect**:
    *   登录 [App Store Connect](https://appstoreconnect.apple.com/)。
    *   点击 "My Apps" -> "+" -> "New App"。
    *   填写 App 名称、语言、Bundle ID (必须与 Xcode 中一致，如 `io.supabase.petcare`)。

3.  **上传构建**:
    *   在 Xcode 中完成 Archive 后，点击 "Distribute App" -> "App Store Connect" -> "Upload"。
    *   等待上传成功。

4.  **提交审核**:
    *   回到 App Store Connect，选择你刚才上传的构建版本。
    *   填写所有元数据 (截图、描述、关键词、支持 URL)。
    *   **注意**：如果是测试版，可以使用 TestFlight 邀请用户测试。
    *   点击 "Submit for Review" (审核通常需要 1-2 天)。

