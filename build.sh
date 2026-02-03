#!/bin/bash

# 1. 获取当前版本号 (从 pubspec.yaml)
VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //')

# 2. 获取当前日期
DATE=$(date +"%Y%m%d")

# 3. 运行 Flutter 构建
echo "🏗️  开始构建 Release APK (Version: $VERSION)..."
flutter build apk --release --no-tree-shake-icons

# 检查构建是否成功
if [ $? -eq 0 ]; then
    # 4. 重命名并移动 APK
    SOURCE="build/app/outputs/flutter-apk/app-release.apk"
    TARGET="build/app/outputs/flutter-apk/pet_care_v${VERSION}_${DATE}.apk"
    
    mv "$SOURCE" "$TARGET"
    
    echo "✅ 构建成功!"
    echo "📂 APK 文件已生成: $TARGET"
    
    # 自动打开文件夹 (Mac)
    open build/app/outputs/flutter-apk/
else
    echo "❌ 构建失败"
    exit 1
fi
