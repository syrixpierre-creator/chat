#!/usr/bin/env bash
set -e

echo "=== 1/6 Dependances systeme ==="
apt-get update -y
apt-get install -y curl git unzip xz-utils zip openjdk-17-jdk libglu1-mesa

echo "=== 2/6 Flutter SDK ==="
if [ ! -d /opt/flutter ]; then
  git clone https://github.com/flutter/flutter.git -b stable /opt/flutter
fi
export PATH="/opt/flutter/bin:$PATH"
if ! grep -q "/opt/flutter/bin" /etc/profile.d/flutter.sh 2>/dev/null; then
  echo 'export PATH="/opt/flutter/bin:$PATH"' > /etc/profile.d/flutter.sh
  chmod +x /etc/profile.d/flutter.sh
fi

echo "=== 3/6 Android SDK (command-line tools) ==="
ANDROID_SDK_ROOT="/opt/android-sdk"
mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
if [ ! -d "$ANDROID_SDK_ROOT/cmdline-tools/latest" ]; then
  cd /tmp
  curl -fsSL -o cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q cmdline-tools.zip
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  mv cmdline-tools/* "$ANDROID_SDK_ROOT/cmdline-tools/latest/"
  rm -rf cmdline-tools cmdline-tools.zip
fi

if ! grep -q "ANDROID_SDK_ROOT" /etc/profile.d/flutter.sh 2>/dev/null; then
  {
    echo "export ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"
    echo 'export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"'
  } >> /etc/profile.d/flutter.sh
fi

export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

echo "=== 4/6 Acceptation des licences + composants Android ==="
yes | sdkmanager --licenses >/dev/null || true
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

echo "=== 5/6 Configuration Flutter ==="
flutter config --android-sdk "$ANDROID_SDK_ROOT"
flutter config --no-analytics
flutter doctor

echo "=== 6/6 Termine ==="
echo ""
echo "Ouvre un NOUVEAU terminal (ou lance: source /etc/profile.d/flutter.sh)"
echo "pour que les commandes 'flutter' et 'sdkmanager' soient reconnues."
echo ""
echo "Etape suivante :"
echo "  cd apps/mobile"
echo "  flutter create ."
echo "  flutter pub get"
