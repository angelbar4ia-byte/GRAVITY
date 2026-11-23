#!/usr/bin/env bash
# Prepara la carpeta lista para subir al bucket público `voces` de Supabase (arrastrar al panel).
# Descarga de los releases de sherpa-onnx, VERIFICA cada archivo contra las huellas medidas el 22/nov/2026
# (docs/licencias-voces/verificadas.json), extrae solo los 3 archivos útiles por voz (sin espeak-ng-data) y
# deja:  <salida>/2026-11-22/<voz>/{modelo.onnx, tokens.txt, lexicon-en-us.txt}
# Uso (Git Bash en Windows, Linux o macOS; necesita curl, tar con bzip2 y sha256sum):
#   bash supabase/scripts/preparar-voces.sh [carpeta_de_salida]      (por omisión ./voces-para-subir)
# No sube nada y no usa credenciales. Pesa unos 280 MB y la descarga son unos 285 MB.
set -euo pipefail
salida="${1:-./voces-para-subir}"; rev="2026-11-22"
base="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
huella() { sha256sum "$1" | cut -d' ' -f1; }
tam() { wc -c < "$1" | tr -d ' '; }
comprobar() { # archivo bytes sha256 etiqueta
  [ "$(tam "$1")" = "$2" ] && [ "$(huella "$1")" = "$3" ] || { echo "ERROR: $4 no coincide con la huella verificada. No se sube." >&2; exit 1; }
  echo "  ok  $4"
}
echo "Léxicon (se copia a cada voz)"
curl -fsSL "$base/lexicon-en-us.txt" -o "$tmp/lexicon-en-us.txt"
comprobar "$tmp/lexicon-en-us.txt" 6305773 8b67ae549a465eee78f92ecb74644ad90c3c58ce65f19c68baf85878a10ef73a lexicon-en-us.txt
while IFS='|' read -r id tarsha onnx obytes osha tbytes tsha; do
  [ -n "$id" ] || continue
  echo "$id"
  curl -fSL "$base/$id.tar.bz2" -o "$tmp/$id.tar.bz2"
  [ "$(huella "$tmp/$id.tar.bz2")" = "$tarsha" ] || { echo "ERROR: $id.tar.bz2 no coincide" >&2; exit 1; }
  mkdir -p "$tmp/x"; tar -xjf "$tmp/$id.tar.bz2" -C "$tmp/x" "$id/$onnx" "$id/tokens.txt"
  dest="$salida/$rev/$id"; mkdir -p "$dest"
  cp "$tmp/x/$id/$onnx" "$dest/$onnx"; cp "$tmp/x/$id/tokens.txt" "$dest/tokens.txt"; cp "$tmp/lexicon-en-us.txt" "$dest/lexicon-en-us.txt"
  comprobar "$dest/$onnx" "$obytes" "$osha" "$id/$onnx"
  comprobar "$dest/tokens.txt" "$tbytes" "$tsha" "$id/tokens.txt"
  comprobar "$dest/lexicon-en-us.txt" 6305773 8b67ae549a465eee78f92ecb74644ad90c3c58ce65f19c68baf85878a10ef73a "$id/lexicon-en-us.txt"
  rm -rf "$tmp/x" "$tmp/$id.tar.bz2"
done <<'VOCES'
vits-piper-en_US-kristin-medium|c2206f572df2956c50b1ae3367eebce3853c663e890cba8048cd62b1e4dbe6c7|en_US-kristin-medium.onnx|63531507|f9a5c375c70ddc33ccdb3969c76a4d7cc5255ac08119a312b0034a1d07041be6|940|ef3a7e4a8d1af0c9d4dc45aaae1a6242ebe24a7ed6f3d025a49eb29682784c6d
vits-piper-en_US-john-medium|d90362cfa48e429d3096f644785184446145b6e38216f2eaf4c0601b8aad5a36|en_US-john-medium.onnx|63152970|4fb0dd1c34ec1add55e71a1ea84166f798922867bd4609e0a094ce4a285f940e|940|ef3a7e4a8d1af0c9d4dc45aaae1a6242ebe24a7ed6f3d025a49eb29682784c6d
vits-piper-en_US-norman-medium|1f32065d480abe9abc7c7f91442125d0b34c1cc065d1e600466cac408eabf3b8|en_US-norman-medium.onnx|63531507|fa06b6b8b280e176b17f8424e05ca12d0223eeac9a31c87230937fe7120fbe2a|940|ef3a7e4a8d1af0c9d4dc45aaae1a6242ebe24a7ed6f3d025a49eb29682784c6d
vits-piper-en_GB-cori-medium|49c9a5361bbdd95d7ca9687c4de11e5908481f65e7c7c368960df79949fdac2b|en_GB-cori-medium.onnx|63531507|8b0d3cdd77f2878e0aa2048103eabb4d01b334783f99629f042bcf703aeba487|940|ef3a7e4a8d1af0c9d4dc45aaae1a6242ebe24a7ed6f3d025a49eb29682784c6d
VOCES
echo
echo "Listo: $salida/$rev  (4 carpetas, 3 archivos cada una). Arrastra la carpeta $rev al bucket 'voces'."
