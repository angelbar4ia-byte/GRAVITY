#!/usr/bin/env bash
# Compara los archivos de voces ALOJADOS contra las huellas de docs/licencias-voces/verificadas.json.
# Uso: supabase/scripts/verificar-voces.sh <url_base> <id_modelo>...
#   url_base: dirección pública con la revisión fija, sin la barra final
#             (p. ej. https://<proyecto>.supabase.co/storage/v1/object/public/voces/2026-11-22)
#   id_modelo: p. ej. vits-piper-en_US-kristin-medium kokoro-int8-multi-lang-v1_1
# Descarga a un directorio temporal (se borra al terminar). Sale con 1 si algo no coincide.
set -euo pipefail
base="${1:?falta url_base}"; shift
json="$(dirname "$0")/../../docs/licencias-voces/verificadas.json"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fallos=0
for modelo in "$@"; do
  while IFS=$'\t' read -r nombre bytes sha; do
    destino="$tmp/$(basename "$nombre")"
    if ! curl -fsSL "$base/$modelo/$nombre" -o "$destino"; then echo "FALTA   $modelo/$nombre"; fallos=1; continue; fi
    [ "$(stat -c %s "$destino")" = "$bytes" ] || { echo "TAMAÑO  $modelo/$nombre"; fallos=1; }
    [ "$(sha256sum "$destino" | cut -d' ' -f1)" = "$sha" ] && echo "ok      $modelo/$nombre" || { echo "HUELLA  $modelo/$nombre"; fallos=1; }
    rm -f "$destino"
  done < <(python3 -I - "$json" "$modelo" <<'P'
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
m=next(x for x in d['modelos'] if x['id']==sys.argv[2])
for a in m['archivos']: print(f"{a['nombre']}\t{a['bytes']}\t{a['sha256']}")
P
)
done
exit $fallos
