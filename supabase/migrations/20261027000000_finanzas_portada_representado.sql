-- =============================================================================
-- GRAVITY · Fase 1 · El dueño ve la portada de los libros representados (D19)
-- =============================================================================
-- Motivo: fin_nombrar_albacea (20261026) deja al dueño del hogar volver a nombrar
-- albacea o suplente del libro de papá, pero si el dueño no es miembro de ese libro
-- hoy ni lo ve, y la app no puede ofrecerle el botón. Criterio PROVISIONAL para
-- D19 (el dueño normalmente lleva el libro de papá como albacea): ver supabase/README.md.
--
-- Qué ve el dueño del hogar, SIEMPRE, de un libro REPRESENTADO de su hogar aunque no
-- sea miembro (su "portada"):
--   * la fila de fin_libros (nombre, titular, activo, quién lo creó), y
--   * las filas de fin_libro_miembros (quién es albacea y suplente, y el historial).
-- NADA más: ni cuentas, ni movimientos, ni plan, ni saldos, ni bitácora del libro. Eso
-- sigue exigiendo ser albacea o suplente vigente (fin_puede(libro, 'leer')).
--
-- Solo el dueño (rol `dueno`, vigente): no el coadministrador, ni la cuenta maestra que no es
-- la dueña (que ya ve la portada de TODOS los libros, y con consulta registrada el
-- contenido: esa regla no cambia), ni familiar, cuidador o casa. Solo tipo `representado`:
-- los compartidos privados y los libros personales siguen sin verse (D19). Solo su hogar.
-- Es solo lectura: escribir en el libro o en sus miembros sigue exigiendo fin_puede().
--
-- Migración nueva (hacia adelante): las anteriores no se tocan. Sin tablas, columnas ni
-- funciones nuevas (la regla va en las políticas de lectura, con rol_en_hogar(), que ya es
-- ejecutable por authenticated): no cambia la lista de operaciones de la API.
-- Compatible con PostgreSQL 15 o superior. Sin extensiones.
-- =============================================================================

drop policy fin_libros_leer on public.fin_libros;
create policy fin_libros_leer on public.fin_libros for select to authenticated
  using (public.fin_puede(id, 'leer')
         or public.es_cuenta_maestra(hogar_id)
         -- Portada del libro de papá para el dueño del hogar, sea o no miembro.
         or (tipo = 'representado' and public.rol_en_hogar(hogar_id) = 'dueno'));

-- La subconsulta pasa por la regla de lectura de fin_libros (que ya incluye al dueño); esa regla
-- llama funciones SECURITY DEFINER y no vuelve a leer fin_libro_miembros con RLS: no hay ciclo.
drop policy fin_libro_miembros_leer on public.fin_libro_miembros;
create policy fin_libro_miembros_leer on public.fin_libro_miembros for select to authenticated
  using (public.fin_puede(libro_id, 'leer')
         or public.es_cuenta_maestra(hogar_id)
         -- Portada: quién es albacea y suplente del libro de papá, para el dueño del hogar.
         or (public.rol_en_hogar(hogar_id) = 'dueno'
             and exists (select 1 from public.fin_libros l
                         where l.id = libro_id and l.hogar_id = fin_libro_miembros.hogar_id
                           and l.tipo = 'representado')));
