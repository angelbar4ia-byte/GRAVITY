#!/usr/bin/env bash
# =============================================================================
# GRAVITY · Corre las pruebas SQL de las reglas por rol (RLS)
# =============================================================================
# Crea una base desechable, aplica la emulación de Supabase, las migraciones
# (cada una en su transacción, como la CLI de Supabase), el seed y los
# ayudantes; luego corre cada archivo NN_*.sql (NN de 10 a 99). Cada archivo
# de prueba corre dentro de begin/rollback, así que no afecta a los demás.
#
# Uso:
#   supabase/tests/correr.sh            Resumen por archivo.
#   supabase/tests/correr.sh -v         Muestra cada afirmación.
#   supabase/tests/correr.sh 20_*.sql   Solo los archivos indicados.
#
# Variables: GRAVITY_PG_URL (usar un servidor existente), PG_BIN,
# GRAVITY_PG_MANTENER=1 (no apagar el clúster al terminar). Ver pg_local.sh.
#
# Sale con 0 si todo pasa; 1 si algo falla.
# =============================================================================
set -euo pipefail

DIR_PRUEBAS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR_SUPABASE="$(cd "$DIR_PRUEBAS/.." && pwd)"
# shellcheck source=supabase/tests/pg_local.sh
source "$DIR_PRUEBAS/pg_local.sh"

DETALLE=0
ARCHIVOS=()
for arg in "$@"; do
  case "$arg" in
    -v|--detalle) DETALLE=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) ARCHIVOS+=("$arg") ;;
  esac
done

if [[ ${#ARCHIVOS[@]} -eq 0 ]]; then
  for f in "$DIR_PRUEBAS"/[1-9][0-9]_*.sql; do ARCHIVOS+=("$(basename "$f")"); done
fi

BD="gravity_pruebas_$$"

echo "GRAVITY · pruebas SQL"
pg_local_iniciar
pg_local_crear_bd "$BD"
echo "Servidor: $(pg_local_psql "$BD" -At -c 'show server_version')"

aplicar() {
  local etiqueta="$1"; shift
  local salida
  if ! salida="$(pg_local_psql "$BD" -o /dev/null "$@" 2>&1)"; then
    echo "  [ERROR] $etiqueta"
    echo "$salida" | sed 's/^/    /'
    exit 1
  fi
  echo "  [ok] $etiqueta"
}

echo "Preparando la base:"
aplicar "emulación de Supabase" -f "$DIR_PRUEBAS/00_emulacion_supabase.sql"
shopt -s nullglob
MIGRACIONES=("$DIR_SUPABASE"/migrations/*.sql)
shopt -u nullglob
if [[ ${#MIGRACIONES[@]} -eq 0 ]]; then
  echo "  [ERROR] no hay migraciones en $DIR_SUPABASE/migrations"; exit 1
fi
for m in "${MIGRACIONES[@]}"; do
  aplicar "migración $(basename "$m")" --single-transaction -f "$m"
done
aplicar "seed.sql" --single-transaction -f "$DIR_SUPABASE/seed.sql"
aplicar "ayudantes de prueba" -f "$DIR_PRUEBAS/01_utilidades.sql"

echo "Pruebas:"
TOTAL_OK=0
FALLAS=0
for nombre in "${ARCHIVOS[@]}"; do
  archivo="$DIR_PRUEBAS/$(basename "$nombre")"
  if [[ ! -f "$archivo" ]]; then
    echo "  [FALLA] $nombre: no existe"; FALLAS=$((FALLAS + 1)); continue
  fi
  if salida="$(pg_local_psql "$BD" -o /dev/null -v VERBOSITY=terse -f "$archivo" 2>&1)"; then
    estado=0
  else
    estado=$?
  fi
  oks="$(grep -c 'NOTICE:  ok - ' <<<"$salida" || true)"
  TOTAL_OK=$((TOTAL_OK + oks))
  if [[ $estado -eq 0 ]]; then
    printf '  [ok]    %-36s %3d afirmaciones\n' "$(basename "$archivo")" "$oks"
    if [[ $DETALLE -eq 1 ]]; then
      grep 'NOTICE:  ok - ' <<<"$salida" | sed 's/.*NOTICE:  ok - /          - /'
    fi
  else
    FALLAS=$((FALLAS + 1))
    printf '  [FALLA] %-36s %3d afirmaciones antes de fallar\n' "$(basename "$archivo")" "$oks"
    grep -v 'NOTICE:  ok - ' <<<"$salida" | sed 's/^/          /'
  fi
done

echo
if [[ $FALLAS -eq 0 ]]; then
  echo "Resultado: TODO PASA · ${#ARCHIVOS[@]} archivos, $TOTAL_OK afirmaciones."
  exit 0
fi
echo "Resultado: $FALLAS archivo(s) con fallas · $TOTAL_OK afirmaciones correctas."
exit 1
