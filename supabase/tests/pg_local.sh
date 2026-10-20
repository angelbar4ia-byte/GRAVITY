# shellcheck shell=bash
# GRAVITY · Postgres desechable para pruebas (se usa con `source`).
#
# Levanta un clúster temporal de PostgreSQL (initdb + pg_ctl) que solo escucha
# por un socket Unix en una carpeta temporal, y lo apaga y borra al salir.
#
# Variables opcionales:
#   GRAVITY_PG_URL  Usa un servidor que ya existe en lugar de crear un clúster
#                   (p. ej. postgresql://postgres:postgres@127.0.0.1:54322/postgres).
#                   Las bases de prueba se crean y se borran en ese servidor, y
#                   los roles anon, authenticated y service_role se crean ahí si
#                   no existen (ya existen en Supabase local).
#   PG_BIN          Carpeta con initdb y pg_ctl (si no están en el PATH).
#   GRAVITY_PG_TMP  Carpeta para el clúster temporal (por defecto /tmp; la ruta
#                   del socket debe ser corta).
#
# Funciones:
#   pg_local_iniciar      Deja listas PGHOST/PGPORT/PGUSER (o GRAVITY_PG_URL).
#   pg_local_crear_bd BD  Crea una base vacía.
#   pg_local_borrar_bd BD Borra una base.
#   pg_local_psql BD ...  Corre psql contra la base BD con ON_ERROR_STOP.
#   pg_local_url BD       Imprime la cadena de conexión de la base BD.

PG_LOCAL_DIR=""
PG_LOCAL_COMO=()
PG_LOCAL_BIN=""
PG_LOCAL_BASES=()

pg_local__buscar_bin() {
  if [[ -n "${PG_BIN:-}" && -x "$PG_BIN/initdb" ]]; then
    PG_LOCAL_BIN="$PG_BIN"; return 0
  fi
  if command -v initdb >/dev/null 2>&1; then
    PG_LOCAL_BIN="$(dirname "$(command -v initdb)")"; return 0
  fi
  if command -v pg_config >/dev/null 2>&1 && [[ -x "$(pg_config --bindir)/initdb" ]]; then
    PG_LOCAL_BIN="$(pg_config --bindir)"; return 0
  fi
  local d
  for d in $(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V -r); do
    if [[ -x "$d/initdb" ]]; then PG_LOCAL_BIN="$d"; return 0; fi
  done
  echo "No encontré initdb. Instala PostgreSQL (p. ej. apt-get install postgresql-16)" >&2
  echo "o define PG_BIN, o usa un servidor existente con GRAVITY_PG_URL." >&2
  return 1
}

pg_local_detener() {
  local bd
  if [[ -n "${GRAVITY_PG_URL:-}" ]]; then
    for bd in "${PG_LOCAL_BASES[@]}"; do
      psql -X -q -d "$GRAVITY_PG_URL" -c "drop database if exists \"$bd\" with (force)" >/dev/null 2>&1 || true
    done
    return 0
  fi
  if [[ -n "$PG_LOCAL_DIR" && -d "$PG_LOCAL_DIR" ]]; then
    if [[ "${GRAVITY_PG_MANTENER:-0}" == "1" ]]; then
      echo "Clúster conservado en $PG_LOCAL_DIR (socket; puerto $PGPORT). Para apagarlo:" >&2
      echo "  ${PG_LOCAL_COMO[*]} $PG_LOCAL_BIN/pg_ctl -D $PG_LOCAL_DIR/datos stop && rm -rf $PG_LOCAL_DIR" >&2
      return 0
    fi
    "${PG_LOCAL_COMO[@]}" "$PG_LOCAL_BIN/pg_ctl" -D "$PG_LOCAL_DIR/datos" -m immediate stop >/dev/null 2>&1 || true
    rm -rf "$PG_LOCAL_DIR"
  fi
}

pg_local_iniciar() {
  if [[ -n "${GRAVITY_PG_URL:-}" ]]; then
    psql -X -q -d "$GRAVITY_PG_URL" -c "select 1" >/dev/null
    trap pg_local_detener EXIT
    return 0
  fi
  pg_local__buscar_bin
  local base="${GRAVITY_PG_TMP:-/tmp}"
  PG_LOCAL_DIR="$(mktemp -d "$base/gravity-pg.XXXXXX")"
  if [[ "$(id -u)" == "0" ]]; then
    # initdb y postgres no corren como root: se usa el usuario postgres.
    if ! id postgres >/dev/null 2>&1; then
      echo "Corriendo como root y no existe el usuario postgres." >&2; return 1
    fi
    chown postgres "$PG_LOCAL_DIR"
    PG_LOCAL_COMO=(runuser -u postgres --)
  else
    PG_LOCAL_COMO=(env)
  fi
  trap pg_local_detener EXIT
  "${PG_LOCAL_COMO[@]}" "$PG_LOCAL_BIN/initdb" -D "$PG_LOCAL_DIR/datos" -U postgres \
    --auth=trust --encoding=UTF8 --no-locale >"$PG_LOCAL_DIR/initdb.log" 2>&1 || {
      cat "$PG_LOCAL_DIR/initdb.log" >&2; return 1; }
  export PGHOST="$PG_LOCAL_DIR" PGPORT=54329 PGUSER=postgres
  "${PG_LOCAL_COMO[@]}" "$PG_LOCAL_BIN/pg_ctl" -D "$PG_LOCAL_DIR/datos" -w \
    -l "$PG_LOCAL_DIR/postgres.log" \
    -o "-c listen_addresses='' -c unix_socket_directories='$PG_LOCAL_DIR' -p $PGPORT -c fsync=off -c full_page_writes=off" \
    start >/dev/null || { cat "$PG_LOCAL_DIR/postgres.log" >&2; return 1; }
}

pg_local_url() {
  local bd="$1"
  if [[ -n "${GRAVITY_PG_URL:-}" ]]; then
    # Reemplaza el nombre de la base al final de la URL (antes de ?parámetros).
    local sin_params="${GRAVITY_PG_URL%%\?*}" params=""
    [[ "$GRAVITY_PG_URL" == *\?* ]] && params="?${GRAVITY_PG_URL#*\?}"
    echo "${sin_params%/*}/$bd$params"
  else
    echo "postgresql:///$bd?host=$PGHOST&port=$PGPORT&user=$PGUSER"
  fi
}

pg_local_crear_bd() {
  local bd="$1"
  if [[ -n "${GRAVITY_PG_URL:-}" ]]; then
    psql -X -q -v ON_ERROR_STOP=1 -d "$GRAVITY_PG_URL" -c "create database \"$bd\"" >/dev/null
  else
    psql -X -q -v ON_ERROR_STOP=1 -d postgres -c "create database \"$bd\"" >/dev/null
  fi
  PG_LOCAL_BASES+=("$bd")
}

pg_local_borrar_bd() {
  local bd="$1"
  if [[ -n "${GRAVITY_PG_URL:-}" ]]; then
    psql -X -q -d "$GRAVITY_PG_URL" -c "drop database if exists \"$bd\" with (force)" >/dev/null
  else
    psql -X -q -d postgres -c "drop database if exists \"$bd\" with (force)" >/dev/null
  fi
}

pg_local_psql() {
  local bd="$1"; shift
  psql -X -q -v ON_ERROR_STOP=1 -d "$(pg_local_url "$bd")" "$@"
}
