#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Downloading Flutter..."
if [ -d "flutter" ]; then
  cd flutter
  git pull
  cd ..
else
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

export PATH="$PATH:`pwd`/flutter/bin"

echo "Flutter version:"
flutter --version

echo "Enabling Web..."
flutter config --enable-web

echo "Getting dependencies..."
flutter pub get

echo "Building Web..."
flutter build web --release --no-tree-shake-icons
