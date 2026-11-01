# Importador del texto bíblico

Convierte un texto de **dominio público** al formato `gravity-biblia-v1`
(JSON comprimido, `app/assets/biblia/<version>.json.gz`) y valida 66 libros y
los capítulos del canon. **No descarga ni incluye texto**: el dueño confirma la
edición y la fuente (P10 de `docs/specs/fase-3-habitos.md`) y entrega el archivo.

Entrada: lista de 66 libros en orden canónico, `{abbrev, chapters: [[versículos]]}`
(formato de los repositorios abiertos de Biblias en JSON).

    cd herramientas/biblia && dart run bin/importar.dart entrada.json salida.json.gz rvr1909 "Reina-Valera 1909" "Dominio público" "<fuente y fecha de descarga>"

Estado: la KJV existe como JSON abierto (p. ej. `en_kjv` de `thiagobodruk/bible`,
código MIT; los textos son de sus dueños, así que **verificar la edición**).
**RVR1909 no está en ese repositorio** (solo RVR1960, con derechos): falta una
fuente verificable. Las pruebas usan un fragmento ficticio.
