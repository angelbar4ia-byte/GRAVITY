#!/usr/bin/env python3
"""Compara las respuestas de un revisor a ciegas con la clave de los ejemplos patrón.

Sustituye a la orden `comparar` mientras no exista (paquete P1.2c del plan,
`docs/specs/fase-8-ingles-plan.md`). Cuando exista, esta carpeta se borra.

Uso, desde la raíz del repositorio (necesita PyYAML):
    python3 herramientas/ingles/transitorio/comparar_ronda.py docs/revisiones/ingles/ronda-3-calidad-d.yaml

Lee la clave de los ejemplos en su estado actual, así que solo vale para una
ronda hecha sobre el cuaderno vigente: si una fuente cambió después, las letras
de opción múltiple pueden no coincidir. Sale con 1 si hay alguna disputa.

Reglas (sección 9 del formato):
- Opción múltiple y oraciones omitidas: la respuesta del revisor debe ser igual a la clave.
- Respuestas escritas: cada respuesta del revisor, normalizada, debe estar en `aceptadas`.
  Se normaliza sin distinguir mayúsculas, sin espacios repetidos, con apóstrofo recto o
  curvo y sin el punto o el signo de interrogación finales.
- Completar palabras: la lista del revisor debe ser igual a la de la clave, en orden.
- Toda `otras_validas` que no esté ya en `aceptadas` es una disputa. En opción múltiple,
  toda `otras_validas` es una disputa.
- `archivos_abiertos` no vacío se reporta como aviso.
"""
import io
import re
import sys
from pathlib import Path

import yaml

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
import cuaderno_ejemplos  # noqa: E402


def normalizar(texto):
    t = str(texto).replace('’', "'").replace('‘', "'").strip()
    t = re.sub(r'\s+', ' ', t)
    t = re.sub(r'[.?!]+$', '', t)
    return t.casefold()


def comparar_pregunta(ident, clave, resp):
    """Devuelve (coincide, motivo)."""
    respuesta = resp.get('respuesta')
    otras = resp.get('otras_validas') or []
    if isinstance(clave, str):  # opción múltiple
        if str(respuesta).strip().upper() != clave:
            return False, f'responde {respuesta}, la clave es {clave}'
        if otras:
            return False, f'defiende otras respuestas: {otras}'
        return True, ''
    if isinstance(clave, dict):  # oraciones omitidas
        mia = {str(k): str(v).strip().upper() for k, v in (respuesta or {}).items()}
        esperada = {str(k): v for k, v in clave.items()}
        if mia != esperada:
            return False, f'responde {mia}, la clave es {esperada}'
        if otras:
            return False, f'defiende otras respuestas: {otras}'
        return True, ''
    # lista: respuestas escritas o completar palabras
    aceptadas = [normalizar(x) for x in clave]
    mias = [normalizar(x) for x in (respuesta if isinstance(respuesta, list) else [respuesta])]
    if ident.startswith('ej-toefl'):
        if mias != aceptadas:
            return False, f'responde {mias}, la clave es {aceptadas}'
        return True, ''
    fuera = [m for m in mias if m not in aceptadas]
    if fuera:
        return False, f'respuestas que no están en aceptadas: {fuera}'
    nuevas = [normalizar(o) for o in otras if normalizar(o) not in aceptadas]
    if nuevas:
        return False, f'defiende respuestas que no están en aceptadas: {nuevas}'
    return True, ''


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    ruta = Path(sys.argv[1])
    _, clave = cuaderno_ejemplos.construir()
    clave = dict(clave)
    docs = [d for d in yaml.safe_load_all(io.open(ruta, encoding='utf-8')) if d]
    total = coinciden = 0
    disputas, avisos = [], []
    print(f'Revisión: {ruta.name} · {len(docs)} unidades')
    for d in docs:
        objeto, agente = d['objeto'], d.get('agente', '?')
        if d.get('archivos_abiertos'):
            avisos.append(f'{objeto}: el revisor declara archivos abiertos: {d["archivos_abiertos"]}')
        n = ok = 0
        for ident, resp in d['respuestas'].items():
            n += 1
            if ident not in clave:
                disputas.append((ident, 'la pregunta no existe en la clave actual (¿cambió la fuente?)'))
                continue
            bien, motivo = comparar_pregunta(ident, clave[ident], resp)
            if bien:
                ok += 1
            else:
                disputas.append((ident, motivo))
        total += n
        coinciden += ok
        print(f'  {objeto:<24} {ok:>2} de {n:<2} coinciden · revisor {agente}')
    faltan = [i for i in clave if not any(i in d['respuestas'] for d in docs)
              and any(i.startswith(d['objeto']) for d in docs)]
    for i in faltan:
        disputas.append((i, 'el revisor no contestó esta pregunta'))
    print(f'Total: {coinciden} de {total} coinciden con la clave · {len(disputas)} disputas')
    for ident, motivo in disputas:
        print(f'  DISPUTA {ident}: {motivo}')
    for aviso in avisos:
        print(f'  AVISO {aviso}')
    sys.exit(1 if disputas else 0)


if __name__ == '__main__':
    main()
