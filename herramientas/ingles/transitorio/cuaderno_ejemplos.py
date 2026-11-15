#!/usr/bin/env python3
"""Cuaderno a ciegas de los ejemplos patrón, en modo transitorio.

Sustituye a la orden `exportar` mientras no exista la herramienta en Dart
(paquete P1.2c del plan, `docs/specs/fase-8-ingles-plan.md`). Cuando exista,
esta carpeta se borra.

Lee `data/ingles/ejemplos/` y escribe
`docs/contenido/ingles/generado/cuaderno-ejemplos-patron.md`, sin respuestas ni
explicaciones. Las opciones y las oraciones van en orden alfabético, así que la
letra no depende de ninguna semilla y cualquiera puede recalcularla.

Uso, desde la raíz del repositorio (necesita PyYAML):
    python3 herramientas/ingles/transitorio/cuaderno_ejemplos.py          # escribe el cuaderno
    python3 herramientas/ingles/transitorio/cuaderno_ejemplos.py --clave  # además imprime la clave

La clave solo la ve quien integra. Quien resuelve a ciegas no corre este
programa ni abre `data/ingles/`.
"""
import io
import re
import sys
from pathlib import Path

import yaml

RAIZ = Path(__file__).resolve().parents[3]
EJEMPLOS = RAIZ / 'data' / 'ingles' / 'ejemplos'
SALIDA = RAIZ / 'docs' / 'contenido' / 'ingles' / 'generado' / 'cuaderno-ejemplos-patron.md'
ORDEN = [
    'cam-b1-r3-ejemplo.yaml',
    'cam-b2-ue2-ejemplo.yaml',
    'cam-b2-ue3-ejemplo.yaml',
    'cam-b2-ue4-ejemplo.yaml',
    'cam-b2-r6-ejemplo.yaml',
    'toefl-r-palabras-ejemplo.yaml',
    'sesion-b1-1-s01-lun-ejemplo.yaml',
]
LETRAS = 'ABCDEFGH'
PROHIBIDO = ('porque', 'ancla', 'aceptadas', 'sobrante', 'pistas')

CABECERA = '''# Cuaderno a ciegas · ejemplos patrón (modo transitorio)

> **Generado** a partir de `data/ingles/ejemplos/`, sin respuestas ni explicaciones. No se edita: si algo está mal, se corrige la fuente y se genera de nuevo con `herramientas/ingles/transitorio/cuaderno_ejemplos.py`.
> **Modo transitorio:** todavía no existe la herramienta `herramientas/ingles`. Las opciones y las oraciones van en orden alfabético (sin contar mayúsculas ni signos iniciales), así que la letra no dice nada sobre la respuesta.

## Instrucciones para quien resuelve

1. No abras `data/ingles/` ni ningún otro archivo del repositorio: todo lo que necesitas está en este cuaderno.
2. Contesta todas las preguntas. Si dudas, contesta igual y marca `seguridad: baja`.
3. En huecos abiertos, formación de palabras, transformaciones y respuestas cortas, escribe **todas** las respuestas que consideres válidas.
4. En cada pregunta intenta defender una segunda respuesta. Si lo logras, anótala en `otras_validas` y explica por qué en `nota`.
5. Devuelve un bloque YAML por unidad, con esta forma:

```yaml
objeto: <id de la unidad>
agente: <tu nombre de agente>
fecha: <aaaa-mm-dd>
archivos_abiertos: []          # lo que hayas leído además de este cuaderno
respuestas:
  <id de pregunta>: {respuesta: "B", seguridad: alta, otras_validas: []}
  <id de hueco abierto>: {respuesta: ["who", "that"], seguridad: media, otras_validas: []}
  <id de oraciones omitidas>: {respuesta: {1: "C", 2: "A"}, seguridad: alta, otras_validas: []}
  <id de completar palabras>: {respuesta: ["layer", "seen"], seguridad: alta, otras_validas: []}
observaciones:
  - "Lo que veas raro en el texto, el nivel o las instrucciones."
```
'''


def clave_orden(texto):
    return re.sub(r'^[^A-Za-z0-9]+', '', texto).casefold()


def cita(texto):
    return '\n'.join('> ' + l if l.strip() else '>' for l in texto.rstrip('\n').split('\n'))


def ordenadas(pregunta):
    return sorted((o['texto'] for o in pregunta['opciones']), key=clave_orden)


def lista_opciones(pregunta):
    return '\n'.join(f'   - {LETRAS[i]}) {t}' for i, t in enumerate(ordenadas(pregunta)))


def letra_correcta(pregunta):
    # en la fuente, la primera opción es siempre la correcta
    return LETRAS[ordenadas(pregunta).index(pregunta['opciones'][0]['texto'])]


def huecos_numerados(texto, forma):
    return re.sub(r'\{(\d+)\}', forma, texto)


def construir():
    out, clave = [CABECERA], []
    for nombre in ORDEN:
        d = yaml.safe_load(io.open(EJEMPLOS / nombre, encoding='utf-8'))
        uid = d['id']
        if d['tipo'] == 'sesion':
            leccion = next(b for b in d['bloques'] if b['tipo'] == 'leccion')
            out.append(f"---\n\n## Unidad `{uid}` · Curso, {d['escalon']}, lección del {d['dia']}\n")
            out.append('Lee la explicación y contesta. En las de opción múltiple, elige una letra; en las demás, escribe la respuesta.\n')
            out.append(cita(leccion['explicacion']) + '\n')
            for q in leccion['preguntas']:
                if q['tipo'] == 'opcion_multiple':
                    out.append(f"- `{q['id']}` {q['enunciado']}\n{lista_opciones(q)}")
                    clave.append((q['id'], letra_correcta(q)))
                else:
                    out.append(f"- `{q['id']}` {q['enunciado']}")
                    clave.append((q['id'], q['aceptadas']))
            out.append('')
            continue

        est, qs = d['estimulo'], d['preguntas']
        out.append(f"---\n\n## Unidad `{uid}` · {d['formato']} · {d['parte']} · nivel {d['nivel']} · {d['variante']}\n")
        tipo = qs[0]['tipo']
        if tipo == 'opcion_multiple':
            out.append('Read the text and choose the correct answer for each question.\n')
            out.append(f"**{est['titulo']}**\n\n" + cita(est['texto']) + '\n')
            for q in qs:
                out.append(f"- `{q['id']}` {q['enunciado']}\n{lista_opciones(q)}")
                clave.append((q['id'], letra_correcta(q)))
        elif tipo == 'hueco_abierto':
            out.append('Read the text and think of the word which best fits each gap. Use only **one** word in each gap.\n')
            out.append(f"**{est['titulo']}**\n\n" + cita(huecos_numerados(est['texto'], r'(\1) ________')) + '\n')
            out.append('Identificadores: ' + ', '.join(f"`{q['id']}`" for q in qs))
            clave += [(q['id'], q['aceptadas']) for q in qs]
        elif tipo == 'formacion_palabra':
            out.append('Read the text. Use the word given in capitals to form a word that fits in the gap.\n')
            out.append(f"**{est['titulo']}**\n\n" + cita(huecos_numerados(est['texto'], r'(\1) ________')) + '\n')
            for q in qs:
                out.append(f"- `{q['id']}` hueco {q['hueco']}: **{q['base']}**")
            clave += [(q['id'], q['aceptadas']) for q in qs]
        elif tipo == 'transformacion':
            out.append('Complete the second sentence so that it has a similar meaning to the first sentence, using the word given. '
                       'Do not change the word given. Use between **two and five words**, including the word given. '
                       'Contractions count as two words.\n')
            for q in qs:
                out.append(f"- `{q['id']}` {q['original']}\n   **{q['clave']}**\n   {q['antes']} ________________ {q['despues']}")
            clave += [(q['id'], q['aceptadas']) for q in qs]
        elif tipo == 'oracion_omitida':
            out.append('Six sentences have been removed from the text. Choose from the sentences A–G the one which fits each gap. '
                       'There is one extra sentence which you do not need to use.\n')
            out.append(f"**{est['titulo']}**\n\n" + cita(huecos_numerados(est['texto'], r'**(\1) ______**')) + '\n')
            oraciones = sorted(qs[0]['oraciones'], key=lambda o: clave_orden(o['texto']))
            for i, o in enumerate(oraciones):
                out.append(f"- {LETRAS[i]}) {o['texto']}")
            out.append(f"\nIdentificador: `{qs[0]['id']}` (responde con un mapa de hueco a letra)")
            clave.append((qs[0]['id'], {o['hueco']: LETRAS[i] for i, o in enumerate(oraciones) if not o.get('sobrante')}))
        elif tipo == 'completar_palabras':
            out.append('Complete the words. Each underscore is one missing letter.\n')
            numero = [0]

            def hueco(m):
                numero[0] += 1
                return f"({numero[0]}) {m.group(1)}" + '_' * len(m.group(2))

            out.append(f"**{est['titulo']}**\n\n" + cita(re.sub(r'([A-Za-z]+)\{([a-z]+)\}', hueco, est['texto'])) + '\n')
            out.append(f"Identificador: `{qs[0]['id']}` (responde con la lista de palabras completas, en orden)")
            clave.append((qs[0]['id'], [p['palabra'] for p in qs[0]['pistas']]))
        else:
            raise SystemExit(f'Tipo de pregunta sin cuaderno: {tipo} en {nombre}')
        out.append('')
    return '\n'.join(out).rstrip('\n') + '\n', clave


def main():
    texto, clave = construir()
    cuerpo = texto.split('\n---\n', 1)[1]
    for palabra in PROHIBIDO:
        if palabra in cuerpo:
            raise SystemExit(f'El cuaderno contiene "{palabra}": se coló parte de la clave.')
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    io.open(SALIDA, 'w', encoding='utf-8').write(texto)
    print(f'Cuaderno: {SALIDA.relative_to(RAIZ)} · {len(clave)} preguntas')
    if '--clave' in sys.argv:
        print('Clave (solo para quien integra):')
        for ident, respuesta in clave:
            print(f'  {ident}: {respuesta}')


if __name__ == '__main__':
    main()
