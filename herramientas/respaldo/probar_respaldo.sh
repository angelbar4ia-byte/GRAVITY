#!/usr/bin/env bash
# =============================================================================
# GRAVITY · Prueba del respaldo y la restauración contra una base local (Linux)
# =============================================================================
# 1. Levanta un Postgres desechable (supabase/tests/pg_local.sh) y crea la base
#    "origen" con la emulación de Supabase, las migraciones, el seed y actividad
#    extra (texto con saltos de línea, acentos y barras; bajas; invitaciones).
# 2. Corre respaldo_diario.ps1 (con pwsh) contra "origen": dos ubicaciones,
#    cifrado AES-256 con 7-Zip, retención, segunda ubicación caída y falta de clave.
# 3. Corre restaurar.ps1 en una base "destino" vacía (solo migraciones) y compara
#    tabla por tabla (filas y huella MD5) con "origen"; comprueba que las reglas
#    por rol siguen funcionando, que no restaura sobre una base con datos, que
#    rechaza una clave equivocada y que exige el esquema.
# 4. Repite respaldo y restauración con la alternativa ZIP + GnuPG.
# Sin pwsh, corre una réplica en bash del flujo básico (volcado, 7-Zip, carga
# con replica y comparación) y avisa que la prueba completa necesita pwsh.
#
# Requisitos: PostgreSQL (initdb, pg_ctl, psql, pg_dump), 7z; pwsh y gpg para
# la prueba completa. Uso: herramientas/respaldo/probar_respaldo.sh [--bash]
# Sale con 0 si todo pasa.
# =============================================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIZ="$(cd "$DIR/../.." && pwd)"
SUPA="$RAIZ/supabase"
# shellcheck source=supabase/tests/pg_local.sh
source "$SUPA/tests/pg_local.sh"

MODO=auto
[[ "${1:-}" == "--bash" ]] && MODO=bash
if [[ $MODO == auto ]]; then
  if command -v pwsh >/dev/null 2>&1; then MODO=pwsh; else MODO=bash; fi
fi
SIETE="$(command -v 7z || command -v 7zz || command -v 7za || true)"
if [[ -z "$SIETE" ]]; then echo "Falta 7-Zip (7z). En Ubuntu: apt-get install 7zip" >&2; exit 1; fi

TRABAJO="$(mktemp -d "${GRAVITY_PG_TMP:-/tmp}/gravity-respaldo-prueba.XXXXXX")"
limpiar() { pg_local_detener; rm -rf "$TRABAJO"; }
pg_local_iniciar || exit 1
trap limpiar EXIT

PASAN=0
FALLAS=0
ok()    { echo "  [ok]    $1"; PASAN=$((PASAN + 1)); }
falla() { echo "  [FALLA] $1"; FALLAS=$((FALLAS + 1)); }
afirmar() { local d="$1"; shift; if "$@"; then ok "$d"; else falla "$d"; fi; }

# Clave aleatoria de prueba (nunca se guarda).
CLAVE="prueba-$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"

preparar_bd() {   # preparar_bd BD [con_seed]
  local bd="$1"
  pg_local_crear_bd "$bd"
  pg_local_psql "$bd" -o /dev/null -f "$SUPA/tests/00_emulacion_supabase.sql"
  local m
  for m in "$SUPA"/migrations/*.sql; do pg_local_psql "$bd" -o /dev/null -1 -f "$m"; done
  if [[ "${2:-}" == "con_seed" ]]; then pg_local_psql "$bd" -o /dev/null -1 -f "$SUPA/seed.sql"; fi
}

# Huella de cada tabla de public y de auth.users: "tabla|filas|md5".
huella() {
  pg_local_psql "$1" -At <<'SQL'
select format(
  'select %L || ''|'' || count(*) || ''|'' || md5(coalesce(string_agg(t::text, E''\n'' order by t::text), '''')) from %s t',
  nombre, nombre)
from (select format('%I.%I', n.nspname, c.relname) as nombre
        from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where (n.nspname = 'public' and c.relkind in ('r', 'p'))
          or (n.nspname = 'auth' and c.relname in ('users', 'identities') and c.relkind = 'r')
       order by 1) as tablas
\gexec
SQL
}

# Cuenta filas de finanzas_muestra como una persona (por su id de cuenta).
dinero_visible_para() {
  pg_local_psql "$1" -At <<SQL | tail -n 1
begin;
select set_config('role', 'authenticated', true), set_config('request.jwt.claim.sub', '$2', true) \g /dev/null
select count(*) from public.finanzas_muestra;
rollback;
SQL
}

echo "GRAVITY · prueba de respaldo y restauración (modo: $MODO)"
echo "Preparando la base origen:"
preparar_bd origen con_seed
pg_local_psql origen -o /dev/null <<'SQL'
-- Actividad extra hecha como lo haría la app (con RLS).
begin;
select set_config('role', 'authenticated', true),
       set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000001', true);
insert into public.finanzas_muestra (hogar_id, descripcion, monto_centavos) values
  ('b0000000-0000-4000-8000-000000000001',
   E'Texto difícil: línea 1\nlínea 2\ttab \\ barra «comillas» ñandú', 12345);
insert into public.bitacora (hogar_id, accion, ocurrido_en)
  values ('b0000000-0000-4000-8000-000000000001', 'registro_sin_conexion', now() - interval '3 hours');
update public.membresias set activa = false, hasta = now()
 where persona_id = (select id from public.personas where nombre_visible = 'Diana Cuidadora');
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000007', true);
select public.aceptar_invitacion('token-de-ejemplo-solo-local');
commit;
SQL
HUELLA_ORIGEN="$(huella origen)"
echo "  [ok] origen con $(wc -l <<<"$HUELLA_ORIGEN") tablas"

D1="$TRABAJO/local"; D2="$TRABAJO/disco_externo"
export GRAVITY_RESPALDO_CLAVE="$CLAVE"
export GRAVITY_DB_URL; GRAVITY_DB_URL="$(pg_local_url origen)"

# ----------------------------------------------------------------------------- modo bash
if [[ $MODO == bash ]]; then
  echo "Respaldo (réplica en bash del flujo de respaldo_diario.ps1):"
  mkdir -p "$D1" "$TRABAJO/tmp/gravity_respaldo_prueba"
  C="$TRABAJO/tmp/gravity_respaldo_prueba"
  pg_dump --no-owner --no-privileges "--dbname=$GRAVITY_DB_URL" --schema-only --schema=public --file="$C/esquema_public.sql"
  pg_dump --no-owner --no-privileges "--dbname=$GRAVITY_DB_URL" --data-only '--table=public.*' \
    --table=auth.users --table=auth.identities --exclude-table-data=public.permisos_rol --file="$C/datos.sql"
  "$SIETE" a -t7z -mx=9 -mhe=on "-p$CLAVE" -bso0 -bsp0 -- "$D1/gravity_respaldo_prueba.7z" "$C" >/dev/null
  rm -rf "$TRABAJO/tmp"
  ARCHIVO="$D1/gravity_respaldo_prueba.7z"
  afirmar "Se creó el archivo cifrado" test -s "$ARCHIVO"
  afirmar "Con otra clave no se abre (nombres cifrados)" bash -c "! '$SIETE' l -pclave-incorrecta '$ARCHIVO' >/dev/null 2>&1"
  afirmar "Los datos no se leen en claro dentro del archivo" bash -c "! grep -aq 'Despensa' '$ARCHIVO'"
  echo "Restauración:"
  preparar_bd destino
  mkdir -p "$TRABAJO/ext"
  "$SIETE" x "-p$CLAVE" "-o$TRABAJO/ext" -y -bso0 -bsp0 -- "$ARCHIVO" >/dev/null
  psql -X -q -v ON_ERROR_STOP=1 --single-transaction -d "$(pg_local_url destino)" \
    -c 'SET session_replication_role = replica' -f "$TRABAJO/ext/gravity_respaldo_prueba/datos.sql" >/dev/null
  afirmar "La base restaurada es idéntica a la original (tabla por tabla)" \
    test "$(huella destino)" == "$HUELLA_ORIGEN"
  afirmar "Tras restaurar, el dueño ve el dinero" \
    test "$(dinero_visible_para destino a0000000-0000-4000-8000-000000000001)" == 3
  afirmar "Tras restaurar, el familiar no ve el dinero" \
    test "$(dinero_visible_para destino a0000000-0000-4000-8000-000000000003)" == 0
  echo
  echo "AVISO: la prueba completa (scripts .ps1, retención, segunda ubicación, gpg) necesita pwsh."
  echo "Resultado: $PASAN correctas, $FALLAS fallas."
  [[ $FALLAS -eq 0 ]]; exit $?
fi

# ----------------------------------------------------------------------------- modo pwsh
respaldar() { pwsh -NoProfile -NonInteractive -File "$DIR/respaldo_diario.ps1" "$@" >"$TRABAJO/ultimo.log" 2>&1; }
restaurar() { pwsh -NoProfile -NonInteractive -File "$DIR/restaurar.ps1" -Confirmar "$@" >"$TRABAJO/ultimo.log" 2>&1; }
mostrar_log() { sed 's/^/          /' "$TRABAJO/ultimo.log"; }
en_log() { grep -qF -- "$1" "$TRABAJO/ultimo.log"; }

echo "Respaldo (respaldo_diario.ps1):"
respaldar -Destino "$D1" -DestinoSecundario "$D2" -DiasRetencion 30 -MinimoConservar 2
codigo=$?
afirmar "respaldo_diario.ps1 termina con código 0" test $codigo -eq 0 || true
[[ $codigo -ne 0 ]] && mostrar_log
ARCHIVO="$(ls "$D1"/gravity_respaldo_*.7z 2>/dev/null | tail -n 1)"
afirmar "Se creó el archivo cifrado en la carpeta local" test -n "$ARCHIVO" -a -s "${ARCHIVO:-/nada}"
afirmar "La copia de la segunda ubicación es idéntica" \
  cmp -s "$ARCHIVO" "$D2/$(basename "$ARCHIVO")"
afirmar "Con otra clave no se abre (nombres cifrados)" bash -c "! '$SIETE' l -pclave-incorrecta '$ARCHIVO' >/dev/null 2>&1"
afirmar "Los datos no se leen en claro dentro del archivo" bash -c "! grep -aq 'Despensa' '$ARCHIVO'"
afirmar "Con la clave contiene datos, esquema, manifiesto y LEEME" bash -c \
  "'$SIETE' l -p'$CLAVE' '$ARCHIVO' | grep -q datos.sql && '$SIETE' l -p'$CLAVE' '$ARCHIVO' | grep -q esquema_public.sql && '$SIETE' l -p'$CLAVE' '$ARCHIVO' | grep -q manifiesto.json && '$SIETE' l -p'$CLAVE' '$ARCHIVO' | grep -q LEEME.txt"
afirmar "El registro (respaldo.log) existe y no contiene la clave" \
  bash -c "test -s '$D1/respaldo.log' && ! grep -q -- '$CLAVE' '$D1/respaldo.log'"
afirmar "No quedan datos sin cifrar en la carpeta temporal" \
  bash -c "! ls -d \"\${TMPDIR:-/tmp}\"/gravity_respaldo_* >/dev/null 2>&1"

echo "Retención:"
for f in gravity_respaldo_20200101_000000.7z gravity_respaldo_20200102_000000.7z; do
  touch "$D1/$f" "$D2/$f"
done
touch "$D1/otro_archivo.txt"
sleep 1
respaldar -Destino "$D1" -DestinoSecundario "$D2" -DiasRetencion 30 -MinimoConservar 10
afirmar "Con mínimo 10, las copias viejas se conservan" test -e "$D1/gravity_respaldo_20200101_000000.7z"
sleep 1
respaldar -Destino "$D1" -DestinoSecundario "$D2" -DiasRetencion 30 -MinimoConservar 2
afirmar "Con mínimo 2, las copias de más de 30 días se borran (local)" \
  bash -c "! ls '$D1'/gravity_respaldo_2020* >/dev/null 2>&1"
afirmar "… y también en la segunda ubicación" bash -c "! ls '$D2'/gravity_respaldo_2020* >/dev/null 2>&1"
afirmar "Las copias recientes se conservan (3)" test "$(ls "$D1"/gravity_respaldo_*.7z | wc -l)" -eq 3
afirmar "Otros archivos de la carpeta no se tocan" test -e "$D1/otro_archivo.txt"

echo "Fallas controladas:"
touch "$TRABAJO/no_es_carpeta"
sleep 1
respaldar -Destino "$D1" -DestinoSecundario "$TRABAJO/no_es_carpeta/sub"
afirmar "Segunda ubicación caída: código 2 y el respaldo local sí se hace" \
  bash -c "test $? -eq 2 && test \$(ls '$D1'/gravity_respaldo_*.7z | wc -l) -eq 4"
afirmar "… con aviso en el registro" en_log 'Segunda ubicación:'
sleep 1
respaldar -Destino "$D1"
afirmar "Sin segunda ubicación configurada: código 2 (aviso)" test $? -eq 2
afirmar "… con aviso en el registro" en_log 'No hay segunda ubicación'
GRAVITY_RESPALDO_CLAVE="" respaldar -Destino "$D1" -DestinoSecundario "$D2"
afirmar "Sin clave de cifrado: código 1" test $? -eq 1
afirmar "… porque falta GRAVITY_RESPALDO_CLAVE" en_log 'Falta la variable de entorno GRAVITY_RESPALDO_CLAVE'
GRAVITY_DB_URL="postgresql:///no_existe?host=$PGHOST&port=$PGPORT&user=$PGUSER" \
  respaldar -Destino "$D1" -DestinoSecundario "$D2"
afirmar "Base inaccesible: código 1" test $? -eq 1
afirmar "… porque psql no conecta" en_log 'psql terminó con código'

echo "Restauración (restaurar.ps1):"
preparar_bd destino
GRAVITY_DB_URL_DESTINO="$(pg_local_url destino)" restaurar -Archivo "$ARCHIVO"
codigo=$?
afirmar "restaurar.ps1 termina con código 0" test $codigo -eq 0
[[ $codigo -ne 0 ]] && mostrar_log
afirmar "La base restaurada es idéntica a la original (tabla por tabla, filas y MD5)" \
  test "$(huella destino)" == "$HUELLA_ORIGEN"
afirmar "Tras restaurar, el dueño ve el dinero (3 filas)" \
  test "$(dinero_visible_para destino a0000000-0000-4000-8000-000000000001)" == 3
afirmar "Tras restaurar, el familiar no ve el dinero" \
  test "$(dinero_visible_para destino a0000000-0000-4000-8000-000000000003)" == 0
afirmar "La bitácora conserva sus fechas originales" test "$(pg_local_psql destino -At -c \
  "select count(*) from public.bitacora where accion = 'registro_sin_conexion' and ocurrido_en < registrado_en - interval '2 hours'")" == 1

GRAVITY_DB_URL_DESTINO="$(pg_local_url destino)" restaurar -Archivo "$ARCHIVO"
afirmar "No restaura sobre una base con datos (código 1)" test $? -eq 1
afirmar "… porque no está vacía" en_log 'no está vacía'
afirmar "… y la base queda igual" test "$(huella destino)" == "$HUELLA_ORIGEN"

preparar_bd destino_b
GRAVITY_RESPALDO_CLAVE="clave-equivocada-123" GRAVITY_DB_URL_DESTINO="$(pg_local_url destino_b)" \
  restaurar -Archivo "$ARCHIVO"
afirmar "Con la clave equivocada no restaura (código 1)" test $? -eq 1
afirmar "… porque 7-Zip no abre el archivo" en_log 'Wrong password'
pg_local_crear_bd sin_esquema
pg_local_psql sin_esquema -o /dev/null -f "$SUPA/tests/00_emulacion_supabase.sql"
GRAVITY_DB_URL_DESTINO="$(pg_local_url sin_esquema)" restaurar -Archivo "$ARCHIVO"
afirmar "Sin migraciones aplicadas en el destino no restaura (código 1)" test $? -eq 1
afirmar "… porque falta el esquema" en_log 'no tiene el esquema de GRAVITY'

echo "Alternativa ZIP + GnuPG:"
if command -v gpg >/dev/null 2>&1; then
  D3="$TRABAJO/gpg"
  export GNUPGHOME="$TRABAJO/gnupg"; mkdir -p -m 700 "$GNUPGHOME"
  respaldar -Destino "$D3" -DestinoSecundario "$TRABAJO/gpg2" -Cifrador gpg
  afirmar "respaldo_diario.ps1 -Cifrador gpg termina con código 0" test $? -eq 0
  ARCHIVO_GPG="$(ls "$D3"/gravity_respaldo_*.zip.gpg 2>/dev/null | tail -n 1)"
  afirmar "Se creó el .zip.gpg y no se lee en claro" \
    bash -c "test -s '${ARCHIVO_GPG:-/nada}' && ! grep -aq 'Despensa' '${ARCHIVO_GPG:-/nada}'"
  GRAVITY_DB_URL_DESTINO="$(pg_local_url destino_b)" restaurar -Archivo "$ARCHIVO_GPG"
  afirmar "restaurar.ps1 con .zip.gpg termina con código 0" test $? -eq 0
  afirmar "La base restaurada desde gpg es idéntica a la original" \
    test "$(huella destino_b)" == "$HUELLA_ORIGEN"
else
  echo "  (gpg no está instalado: se omite)"
fi

echo
if [[ $FALLAS -eq 0 ]]; then
  echo "Resultado: TODO PASA · $PASAN comprobaciones."
  exit 0
fi
echo "Resultado: $FALLAS falla(s) · $PASAN correctas."
exit 1
