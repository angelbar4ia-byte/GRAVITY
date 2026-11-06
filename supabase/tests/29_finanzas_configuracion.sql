-- Configuración de los libros (4.1 y 4.5): vigencias de ingreso con varios
-- días al mes y cada N meses (D19 regla 6), grupo de deudas prioritarias
-- (regla 4), regla de día inhábil por compromiso y deuda (regla 5),
-- parámetros por libro, días inhábiles del hogar y libros personales.
begin;
select pruebas.como('ana@ejemplo.test');

-- ---------------------------------------------------------------- ingresos de Papá (P15)
select pruebas.igual(
  (select forma || ' ' || dias_mes::text || ' ' || regla_inhabil from public.fin_vigencias_ingreso
    where id = 'e2000000-0000-4000-8000-000000000003'),
  'mensual {1,11} siguiente_dia_habil', 'Pensión de Papá: días 1 y 11, al siguiente día hábil');
select pruebas.igual(
  (select forma || ' cada ' || intervalo_meses || ' desde ' || fecha_ancla from public.fin_vigencias_ingreso
    where id = 'e2000000-0000-4000-8000-000000000004'),
  'cada_meses cada 2 desde 2026-09-01', 'Apoyo 60+: cada bimestre desde una fecha conocida');
select pruebas.igual(
  (select certeza from public.fin_ingresos where id = 'e1000000-0000-4000-8000-000000000004'),
  'probable', 'El apoyo es probable');
select pruebas.igual(
  (select libro_id from public.fin_vigencias_ingreso where id = 'e2000000-0000-4000-8000-000000000003'),
  'f1000000-0000-4000-8000-000000000002'::uuid, 'La vigencia va en el libro de su ingreso (lo pone el servidor)');

-- ---------------------------------------------------------------- vigencias
insert into public.fin_ingresos (id, hogar_id, libro_id, persona_id, nombre, tipo)
values ('e1000000-0000-4000-8000-0000000000f1', 'b0000000-0000-4000-8000-000000000001',
        pruebas.libro_personal('ana@ejemplo.test'), pruebas.id_persona('ana@ejemplo.test'), 'Asesorías (ejemplo)', 'independiente');
select pruebas.falla($$insert into public.fin_vigencias_ingreso (hogar_id, ingreso_id, monto_neto_centavos, forma,
  fecha_ancla, desde) values ('b0000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-0000000000f1',
  100, 'cada_meses', '2027-01-01', '2027-01-01')$$, 'cada_meses exige el intervalo', '23514');
select pruebas.falla($$insert into public.fin_vigencias_ingreso (hogar_id, ingreso_id, monto_neto_centavos, forma,
  dias_mes, desde) values ('b0000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-0000000000f1',
  100, 'mensual', '{32}', '2027-01-01')$$, 'Días del mes de 0 (último) a 31', '23514');
select pruebas.falla($$insert into public.fin_vigencias_ingreso (hogar_id, ingreso_id, monto_neto_centavos, forma,
  dias_mes, desde) values ('b0000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-0000000000f1',
  100, 'quincenal', '{15}', '2027-01-01')$$, 'Una quincena tiene dos días', '23514');
select pruebas.falla($$insert into public.fin_vigencias_ingreso (hogar_id, ingreso_id, monto_neto_centavos, forma, desde)
  values ('b0000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-0000000000f1', 100, 'semanal', '2027-01-01')$$,
  'Un pago semanal dice el día de la semana', '23514');
select pruebas.falla($$insert into public.fin_vigencias_ingreso (hogar_id, ingreso_id, monto_neto_centavos, forma,
  dias_mes, desde) values ('b0000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-000000000001',
  950000, 'quincenal', '{15,0}', '2026-06-01')$$,
  'Las vigencias de un ingreso no se traslapan', '22023');
select pruebas.igual(pruebas.afecta($$update public.fin_vigencias_ingreso set hasta = '2026-10-31'
  where id = 'e2000000-0000-4000-8000-000000000001'$$), 1, 'Cambio de neto: se cierra la vigencia anterior');
select pruebas.igual(pruebas.afecta($$insert into public.fin_vigencias_ingreso (hogar_id, ingreso_id,
  monto_neto_centavos, forma, dias_mes, desde) values ('b0000000-0000-4000-8000-000000000001',
  'e1000000-0000-4000-8000-000000000001', 950000, 'quincenal', '{15,0}', '2026-11-01')$$), 1,
  '… y se crea la nueva');
select pruebas.falla($$update public.fin_vigencias_ingreso set hasta = '2025-01-01'
  where id = 'e2000000-0000-4000-8000-000000000001'$$, 'hasta no va antes de desde', '23514');

-- ---------------------------------------------------------------- ingresos
select pruebas.falla($$insert into public.fin_ingresos (hogar_id, libro_id, persona_id, nombre)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          pruebas.id_persona('alex@ejemplo.test'), 'Sueldo ajeno')$$,
  'Un ingreso es del titular o de un miembro del libro', '22023');
select pruebas.falla($$insert into public.fin_ingresos (hogar_id, libro_id, persona_id, nombre, cuenta_origen_id)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          pruebas.id_persona('ana@ejemplo.test'), 'Bono', 'c3000000-0000-4000-8000-000000000001')$$,
  'La cuenta de origen de un ingreso es de tipo origen_ingreso', '22023');
select pruebas.falla($$insert into public.fin_ingresos (hogar_id, libro_id, persona_id, nombre, cuenta_destino_id)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          pruebas.id_persona('ana@ejemplo.test'), 'Bono', 'c3000000-0000-4000-8000-000000000003')$$,
  'Un ingreso llega a un activo', '22023');
select pruebas.falla($$insert into public.fin_ingresos (hogar_id, libro_id, persona_id, nombre, cuenta_origen_id)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          pruebas.id_persona('ana@ejemplo.test'), 'Bono', 'c4000000-0000-4000-8000-000000000003')$$,
  'Las cuentas de un ingreso son de su libro', '23503');
select pruebas.igual(pruebas.afecta($$insert into public.fin_ingresos (hogar_id, libro_id, persona_id, nombre, tipo,
  cuenta_destino_id) values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
  pruebas.id_persona('alex@ejemplo.test'), 'Renta del cuarto (ejemplo)', 'otro',
  'c5000000-0000-4000-8000-000000000001')$$), 1, 'En el compartido, un ingreso puede ser de cualquier miembro');

-- ---------------------------------------------------------------- deudas
select pruebas.igual(
  (select string_agg(nombre, ', ' order by orden_grupo) from public.fin_deudas
    where libro_id = pruebas.libro_personal('ana@ejemplo.test') and grupo_prioritario),
  'Tarjeta de crédito, Préstamo de la tía', 'D19 regla 4: el grupo de deudas prioritarias y su orden');
select pruebas.falla($$insert into public.fin_deudas (hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id,
  abono_centavos, frecuencia) values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
  'Sin tasa', 'con_costo', 'c3000000-0000-4000-8000-000000000003', 100, 'mensual')$$,
  'Una deuda con costo exige su tasa', '23514');
select pruebas.falla($$insert into public.fin_deudas (hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id,
  abono_centavos, frecuencia, tasa_anual_pb) values ('b0000000-0000-4000-8000-000000000001',
  pruebas.libro_personal('ana@ejemplo.test'), 'Familiar con tasa', 'familiar', 'c3000000-0000-4000-8000-000000000004',
  100, 'mensual', 1000)$$, 'Un préstamo familiar va sin tasa', '23514');
select pruebas.falla($$insert into public.fin_deudas (hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id,
  abono_centavos, frecuencia, grupo_prioritario) values ('b0000000-0000-4000-8000-000000000001',
  pruebas.libro_personal('ana@ejemplo.test'), 'Sin orden', 'msi', 'c3000000-0000-4000-8000-000000000003',
  100, 'mensual', true)$$, 'En el grupo prioritario, cada deuda tiene su orden', '23514');
select pruebas.falla($$insert into public.fin_deudas (hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id,
  abono_centavos, frecuencia) values ('b0000000-0000-4000-8000-000000000001',
  pruebas.libro_personal('ana@ejemplo.test'), 'Banco como deuda', 'msi', 'c3000000-0000-4000-8000-000000000001',
  100, 'mensual')$$, 'La cuenta de una deuda es un pasivo', '22023');
select pruebas.falla($$insert into public.fin_deudas (hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id,
  abono_centavos, frecuencia) values ('b0000000-0000-4000-8000-000000000001',
  pruebas.libro_personal('ana@ejemplo.test'), 'Diaria', 'msi', 'c3000000-0000-4000-8000-000000000003',
  100, 'diaria')$$, 'Una deuda no es diaria', '23514');
insert into public.fin_deudas (id, hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos, frecuencia)
values ('e5000000-0000-4000-8000-0000000000f1', 'b0000000-0000-4000-8000-000000000001',
        pruebas.libro_personal('ana@ejemplo.test'), 'Pantalla a MSI', 'msi', 'c3000000-0000-4000-8000-000000000003',
        50000, 'mensual');
select pruebas.igual(
  (select regla_inhabil || ' ' || tasa_anual_pb || ' ' || grupo_prioritario from public.fin_deudas
    where id = 'e5000000-0000-4000-8000-0000000000f1'),
  'sin_cambio 0 false', 'D19 regla 5: una deuda se paga en su fecha por defecto; MSI sin tasa ni grupo');

-- ---------------------------------------------------------------- compromisos y sobres
insert into public.fin_compromisos (id, hogar_id, libro_id, nombre, tipo, cuenta_gasto_id, monto_centavos, frecuencia,
                                    forma, dias_mes)
values ('e3000000-0000-4000-8000-0000000000f1', 'b0000000-0000-4000-8000-000000000001',
        pruebas.libro_personal('ana@ejemplo.test'), 'Gimnasio', 'fija', 'c2000000-0000-4000-8000-000000000007',
        50000, 'mensual', 'mensual', '{5}');
select pruebas.igual(
  (select regla_inhabil from public.fin_compromisos where id = 'e3000000-0000-4000-8000-0000000000f1'),
  'sin_cambio', 'D19 regla 5: un compromiso se paga en su fecha por defecto');
select pruebas.igual(pruebas.afecta($$insert into public.fin_compromisos (hogar_id, libro_id, nombre, tipo,
  cuenta_gasto_id, monto_centavos, frecuencia, forma, dias_mes, regla_inhabil)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'La caja (ejemplo)',
          'fija', 'c2000000-0000-4000-8000-000000000010', 100000, 'mensual', 'mensual', '{1}', 'siguiente_dia_habil')$$), 1,
  'P13: el pago a la caja puede pasar al siguiente día hábil');
select pruebas.falla($$insert into public.fin_compromisos (hogar_id, libro_id, nombre, tipo, monto_centavos, frecuencia)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Pasaje', 'fija',
          3000, 'diaria')$$, 'Un gasto diario dice cuántos días a la semana', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.fin_compromisos (hogar_id, libro_id, nombre, tipo,
  monto_centavos, frecuencia, dias_activos)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Pasaje', 'fija',
          3000, 'diaria', 5)$$), 1, 'Pasaje de lunes a viernes: diario con 5 días activos');
select pruebas.falla($$insert into public.fin_compromisos (hogar_id, libro_id, nombre, tipo, cuenta_gasto_id,
  monto_centavos, frecuencia) values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
  'Mal', 'fija', 'c3000000-0000-4000-8000-000000000001', 100, 'mensual')$$,
  'Un compromiso va a una cuenta de gasto del hogar', '22023');
select pruebas.falla($$insert into public.fin_sobres (hogar_id, libro_id, cuenta_gasto_id, nombre,
  monto_semanal_centavos, piso_minimo_centavos) values ('b0000000-0000-4000-8000-000000000001',
  pruebas.libro_personal('ana@ejemplo.test'), 'c2000000-0000-4000-8000-000000000001', 'Antojos', 1000, 2000)$$,
  'El piso de un sobre no pasa de su monto', '23514');
select pruebas.falla($$insert into public.fin_sobres (hogar_id, libro_id, cuenta_gasto_id, nombre,
  monto_semanal_centavos) values ('b0000000-0000-4000-8000-000000000001',
  pruebas.libro_personal('ana@ejemplo.test'), 'c3000000-0000-4000-8000-000000000001', 'Mal', 1000)$$,
  'Un sobre va a una cuenta de gasto del hogar', '22023');

-- ---------------------------------------------------------------- parámetros por libro
select pruebas.igual(pruebas.cuenta('select * from public.fin_parametros'), 3,
  'Cada libro nace con sus parámetros (Ana ve los de sus 3 libros)');
select pruebas.igual(
  (select meta_remanente_pb || '/' || tope_arrastre_semanas || '/' || partida_ambar_pb || '/' || cierre_automatico_dias
     from public.fin_parametros where libro_id = 'f1000000-0000-4000-8000-000000000001'),
  '2000/2/8000/3', 'Con los valores por defecto (20 %, 2 semanas, 80 %, 3 días)');
select pruebas.igual(pruebas.afecta($$update public.fin_parametros set meta_remanente_pb = 2500
  where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$), 1, 'Ana cambia la meta de su libro');
select pruebas.falla($$update public.fin_parametros set partida_ambar_pb = 12000
  where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$, 'El ámbar no pasa del rojo', '23514');
select pruebas.falla($$update public.fin_parametros set cuenta_ajustes_id = 'c3000000-0000-4000-8000-000000000001'
  where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$, 'Las cuentas de sistema del libro no cambian', '42501');

-- ---------------------------------------------------------------- días inhábiles del hogar
select pruebas.igual(
  (select revisado_por from public.fin_dias_inhabiles where id = 'ec000000-0000-4000-8000-000000000001'),
  pruebas.id_persona('ana@ejemplo.test'), 'Quién revisó y activó un festivo lo pone el servidor');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_dias_inhabiles set activo = true
  where id = 'ec000000-0000-4000-8000-000000000002'$$), 1, 'El calendario es del hogar: la pareja también lo revisa');
select pruebas.ok(
  (select revisado_por = pruebas.id_persona('alex@ejemplo.test') and revisado_en is not null
     from public.fin_dias_inhabiles where id = 'ec000000-0000-4000-8000-000000000002'),
  'Queda quién y cuándo');
select pruebas.igual(pruebas.afecta($$insert into public.fin_dias_inhabiles (hogar_id, fecha, nombre, tipo, activo,
  revisado_por) values ('b0000000-0000-4000-8000-000000000001', '2026-12-24', 'Nochebuena', 'personal', true,
  pruebas.id_persona('ana@ejemplo.test'))$$), 1, 'Un día propio');
select pruebas.igual(
  (select revisado_por from public.fin_dias_inhabiles where fecha = '2026-12-24'),
  pruebas.id_persona('alex@ejemplo.test'), 'Aunque la app mande otro revisado_por, el servidor pone a quien lo hizo');
select pruebas.falla($$insert into public.fin_dias_inhabiles (hogar_id, fecha, nombre)
  values ('b0000000-0000-4000-8000-000000000001', '2026-11-16', 'Repetido')$$, 'Un día una sola vez', '23505');

-- ---------------------------------------------------------------- libros
select pruebas.falla($$insert into public.fin_libros (hogar_id, nombre, tipo, titular_id)
  values ('b0000000-0000-4000-8000-000000000001', 'Para Ana', 'personal', pruebas.id_persona('ana@ejemplo.test'))$$,
  'Nadie crea el libro personal de otra persona', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.fin_libros (hogar_id, nombre, tipo, titular_id)
  values ('b0000000-0000-4000-8000-000000000001', 'Otro mío', 'personal', pruebas.id_persona('ana@ejemplo.test'))$$,
  'Un solo libro personal por persona', '23505');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libros (id, hogar_id, nombre, tipo)
  values ('f1000000-0000-4000-8000-0000000000b1', 'b0000000-0000-4000-8000-000000000001', 'Viaje (ejemplo)', 'compartido')$$), 1,
  'Ana crea un libro compartido');
select pruebas.igual(
  (select papel from public.fin_libro_miembros
    where libro_id = 'f1000000-0000-4000-8000-0000000000b1' and persona_id = pruebas.id_persona('ana@ejemplo.test')),
  'miembro', 'Quien lo crea queda como miembro');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-0000000000b1', pruebas.id_persona('alex@ejemplo.test'), 'miembro')$$), 1,
  'Y agrega a Alex');
select pruebas.falla($$update public.fin_libros set tipo = 'personal' where id = 'f1000000-0000-4000-8000-0000000000b1'$$,
  'Un libro no cambia de tipo', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set activo = false
  where id = 'f1000000-0000-4000-8000-0000000000b1'$$), 1, 'Se desactiva al terminar el viaje');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-0000000000b1', 'leer')
                  and not public.fin_puede('f1000000-0000-4000-8000-0000000000b1', 'escribir'),
  'Un libro inactivo se lee y ya no admite movimientos');

-- Libro personal automático al recibir un rol con Finanzas.
select pruebas.igual(pruebas.afecta($$update public.membresias set rol = 'coadministrador'
  where persona_id = pruebas.id_persona('carla@ejemplo.test')$$), 1,
  'La dueña le da a Carla el rol de coadministradora');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(
  (select tipo || ' ' || (titular_id = pruebas.id_persona('carla@ejemplo.test')) from public.fin_libros),
  'personal true', 'El servidor le crea su libro personal');
select pruebas.igual(
  (select string_agg(tipo, ',' order by tipo) from public.fin_cuentas where libro_id = pruebas.libro_personal('carla@ejemplo.test')),
  'ajustes,apertura,por_clasificar', 'Con sus cuentas de sistema');
select pruebas.igual(pruebas.cuenta('select * from public.fin_parametros'), 1, 'Y sus parámetros');
select pruebas.como('nuevo@ejemplo.test');
create temporary table hogar_nuevo on commit drop as select public.crear_hogar('Hogar de Nuevo') as id;
select pruebas.igual(
  (select count(*)::int from public.fin_libros l where l.hogar_id = (select id from hogar_nuevo) and l.tipo = 'personal'), 1,
  'Quien crea un hogar recibe su libro personal');

rollback;
