#!/usr/bin/env bash
# Gera o APK do Android no Linux Mint. Baixa JDK 17 e o Android SDK (de linha de comando) se necessário.
set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="$HOME/flutter/bin:$PATH"
command -v flutter >/dev/null || { echo "Rode antes: bash scripts/install_linux.sh"; exit 1; }

sudo apt-get install -y openjdk-17-jdk unzip curl
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which javac)")")")"

export ANDROID_HOME="$HOME/android-sdk"
if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  curl -fL -o /tmp/cmdtools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q -o /tmp/cmdtools.zip -d "$ANDROID_HOME/cmdline-tools"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
fi
SDKM="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
yes | "$SDKM" --licenses >/dev/null || true
"$SDKM" "platform-tools" "platforms;android-34" "build-tools;34.0.0"

flutter config --android-sdk "$ANDROID_HOME" >/dev/null
yes | flutter doctor --android-licenses >/dev/null || true

if [ ! -d android ]; then
  rm -rf /tmp/animeflix_bak && mkdir /tmp/animeflix_bak
  cp -r lib pubspec.yaml /tmp/animeflix_bak/
  flutter create --platforms=linux,android --project-name animeflix --org com.animeflix .
  rm -rf lib && cp -r /tmp/animeflix_bak/lib lib && cp /tmp/animeflix_bak/pubspec.yaml pubspec.yaml
fi
bash scripts/patch_android.sh

flutter pub get
flutter build apk --release
APK="build/app/outputs/flutter-apk/app-release.apk"
cp "$APK" ./AnimeFlix.apk
echo "APK pronto: $(pwd)/AnimeFlix.apk"
echo "Copie para o celular e instale (permita 'fontes desconhecidas')."
