#!/usr/bin/env bash
# Instala dependências, compila e instala o AnimeFlix no Linux Mint (Ubuntu/Debian).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Dependências do sistema (pede senha de administrador)"
sudo apt-get update
sudo apt-get install -y git curl unzip xz-utils zip clang cmake ninja-build pkg-config \
  libgtk-3-dev libmpv-dev mpv libsqlite3-dev zenity libglu1-mesa

if ! command -v flutter >/dev/null 2>&1; then
  echo "==> Instalando Flutter em ~/flutter"
  [ -d "$HOME/flutter" ] || git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
  grep -q 'flutter/bin' "$HOME/.bashrc" || echo 'export PATH="$HOME/flutter/bin:$PATH"' >> "$HOME/.bashrc"
fi

flutter config --enable-linux-desktop >/dev/null

if [ ! -d linux ]; then
  echo "==> Gerando arquivos de plataforma (linux + android)"
  rm -rf /tmp/animeflix_bak && mkdir /tmp/animeflix_bak
  cp -r lib pubspec.yaml /tmp/animeflix_bak/
  flutter create --platforms=linux,android --project-name animeflix --org com.animeflix .
  rm -rf lib && cp -r /tmp/animeflix_bak/lib lib && cp /tmp/animeflix_bak/pubspec.yaml pubspec.yaml
fi
bash scripts/patch_android.sh

echo "==> Baixando pacotes e compilando (demora alguns minutos)"
flutter pub get
flutter build linux --release

echo "==> Instalando em ~/.local/share/animeflix"
DEST="$HOME/.local/share/animeflix"
rm -rf "$DEST"; mkdir -p "$DEST" "$HOME/.local/bin" "$HOME/.local/share/applications"
cp -r build/linux/*/release/bundle/* "$DEST/"
ln -sf "$DEST/animeflix" "$HOME/.local/bin/animeflix"
cat > "$HOME/.local/share/applications/animeflix.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=AnimeFlix
Comment=Plataforma de animes com modo offline
Exec=$DEST/animeflix
Terminal=false
Categories=AudioVideo;Video;
EOF
echo "Pronto! Abra pelo menu (AnimeFlix) ou rode: animeflix"
