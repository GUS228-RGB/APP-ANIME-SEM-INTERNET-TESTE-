#!/usr/bin/env bash
# Ajusta o projeto Android gerado pelo "flutter create": permissão de internet e nome do app.
set -euo pipefail
M="android/app/src/main/AndroidManifest.xml"
[ -f "$M" ] || { echo "Manifest não encontrado (rode 'flutter create' antes)."; exit 1; }
grep -q 'android.permission.INTERNET' "$M" || \
  sed -i '0,/<application/s//<uses-permission android:name="android.permission.INTERNET"\/>\n    <application/' "$M"
sed -i 's/android:label="[^"]*"/android:label="AnimeFlix"/' "$M"
echo "Android manifest ajustado."
