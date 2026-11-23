/// Base local (drift, SQLite): cola sin conexión y, más adelante, la copia
/// del día (docs/specs/fase-0-cimientos.md, sección 3).
///
/// Código generado: `dart run build_runner build --delete-conflicting-outputs`.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'base_local.g.dart';

/// Estado de un registro en la cola.
enum EstadoPendiente {
  /// Falta subirlo (o reintentarlo).
  pendiente,

  /// El servidor lo recibió.
  enviado,

  /// **Requiere atención**: el servidor no lo aceptó (p. ej. sin permiso,
  /// 42501, o datos inválidos) o falló demasiadas veces con un error que no es
  /// de red. No se pierde ni se reintenta solo: la app lo muestra y la persona
  /// decide (reintentar o descartar).
  rechazado,

  /// La persona decidió no subirlo (tras revisarlo).
  descartado,
}

/// Desde dónde y con qué identidad se hizo un registro.
enum OrigenRegistro {
  /// La persona con su sesión (teléfono, laptop o tablet con su PIN).
  propio,

  /// Tablet pública de la casa, sin PIN: la persona **eligió su nombre** para
  /// registrar algo de la casa (lista de compras, recordatorio genérico). Se
  /// sube con la cuenta Casa del equipo y queda como *"Ana, desde la tablet
  /// de la casa"* (D14).
  tabletCasa,
}

/// Registros hechos en el dispositivo que faltan por subir al servidor.
@DataClassName('RegistroPendiente')
class Pendientes extends Table {
  /// UUID generado en el dispositivo; el servidor lo usa como llave, así un
  /// reenvío nunca duplica (idempotencia).
  TextColumn get id => text()();

  /// Qué es, p. ej. `finanzas.gasto`.
  TextColumn get tipo => text()();

  /// Contenido en JSON.
  TextColumn get carga => text()();

  DateTimeColumn get creadoEn => dateTime()();

  IntColumn get intentos => integer().withDefault(const Constant(0))();

  TextColumn get estado => textEnum<EstadoPendiente>()();

  /// Cuándo puede volver a intentarse (espera creciente).
  DateTimeColumn get siguienteIntento => dateTime().nullable()();

  TextColumn get ultimoError => text().nullable()();

  /// Persona que lo registró (id de `personas`). Solo se envía con la sesión
  /// del servidor de esa misma persona (revisión de la Fase 0, I4).
  TextColumn get personaId => text().nullable()();

  /// Desde dónde se registró (`null` en los de antes de la versión 3:
  /// [OrigenRegistro.propio]).
  TextColumn get origen => textEnum<OrigenRegistro>().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// «Mi gimnasio» (Fase 8, G3): espejo local de las seis tablas `hab_ent_*` del
// servidor (`supabase/migrations/20261152000000_habitos_gimnasio.sql`). Local
// primero: lo que la persona hace se guarda aquí y se encola para subirlo.
//
// - Cada fila lleva su `personaId` (una tablet personal la comparten el dueño y
//   su pareja; el servidor lo pone con la sesión, aquí hay que decirlo).
// - Mismos nombres y rangos que el servidor; las fechas son `AAAA-MM-DD` y las
//   horas `HH:MM`, como las del servidor, para no mezclar zonas.
// - **Sin molestias, zonas ni dolor:** no existe columna para ellas (viven solo
//   en el almacén cifrado, `salud_local`). El motivo de cambio de una serie
//   tampoco admite «molestia» (PG-19).
// ---------------------------------------------------------------------------

/// `hab_ent_perfil`: una fila por persona.
@DataClassName('GimPerfilFila')
class GimPerfil extends Table {
  TextColumn get personaId => text()();
  IntColumn get diasPlan => integer().withDefault(const Constant(3))();
  TextColumn get versionPref => text().withDefault(const Constant('auto'))();
  TextColumn get ventana => text().withDefault(const Constant('noche'))();
  TextColumn get nocheDesde => text().withDefault(const Constant('19:00'))();
  TextColumn get objetivo =>
      text().withDefault(const Constant('salud_general'))();
  TextColumn get nivel => text().withDefault(const Constant('principiante'))();
  TextColumn get inicioCiclo => text().nullable()();
  IntColumn get cicloSemanas => integer().withDefault(const Constant(4))();
  IntColumn get descansoS => integer().nullable()();
  IntColumn get margenDormirMin => integer().withDefault(const Constant(90))();
  TextColumn get pruebaDesde => text().nullable()();
  TextColumn get pruebaVentana => text().nullable()();
  BoolColumn get vozDescanso => boolean().withDefault(const Constant(false))();
  DateTimeColumn get avisoVistoEn => dateTime().nullable()();
  DateTimeColumn get modificadoEn => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {personaId};
}

/// `hab_ent_plan_dias`: una fila por día de la semana (1 = lunes).
@DataClassName('GimPlanDiaFila')
class GimPlanDias extends Table {
  TextColumn get personaId => text()();
  IntColumn get diaSemana => integer()();
  TextColumn get tipo => text()();
  TextColumn get version => text().withDefault(const Constant('auto'))();
  TextColumn get hora => text().nullable()();
  DateTimeColumn get modificadoEn => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {personaId, diaSemana};
}

/// `hab_ent_inventario`: un aparato, puesto o accesorio por fila.
@DataClassName('GimInventarioFila')
class GimInventario extends Table {
  TextColumn get personaId => text()();
  TextColumn get itemId => text()();
  TextColumn get estado => text()();

  /// Datos del aparato confirmados (JSON): pasos de la pila, kg por paso…
  TextColumn get confirmado => text().withDefault(const Constant('{}'))();
  TextColumn get notas => text().nullable()();
  DateTimeColumn get modificadoEn => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {personaId, itemId};
}

/// `hab_ent_bandas`: las bandas de la persona (id v4).
@DataClassName('GimBandaFila')
class GimBandas extends Table {
  TextColumn get id => text()();
  TextColumn get personaId => text()();
  TextColumn get nombre => text()();
  IntColumn get orden => integer()();
  IntColumn get resistenciaKgX10 => integer().nullable()();
  IntColumn get cantidad => integer()();
  BoolColumn get activa => boolean().withDefault(const Constant(true))();
  DateTimeColumn get modificadoEn => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `hab_ent_sesiones`: una por día y plantilla (id v5).
@DataClassName('GimSesionFila')
class GimSesiones extends Table {
  TextColumn get id => text()();
  TextColumn get personaId => text()();
  TextColumn get fecha => text()();
  TextColumn get plantilla => text()();
  TextColumn get version => text()();
  TextColumn get semanaTipo => text()();
  TextColumn get ventana => text()();
  TextColumn get bloqueId => text().nullable()();
  DateTimeColumn get inicio => dateTime()();
  DateTimeColumn get fin => dateTime().nullable()();
  TextColumn get estado => text()();
  IntColumn get esfuerzo => integer().nullable()();
  IntColumn get energia => integer().nullable()();

  /// Lo planeado (JSON): lista de {ejercicio, variante, series, reps_min,
  /// reps_max}.
  TextColumn get plan => text().withDefault(const Constant('[]'))();
  IntColumn get catalogoVersion => integer()();

  /// **Solo local** (calibra el tiempo estimado, 5.5): nunca se sube.
  TextColumn get tiempos => text().nullable()();
  DateTimeColumn get modificadoEn => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// `hab_ent_series`: una por serie hecha (id v5).
@DataClassName('GimSerieFila')
class GimSeries extends Table {
  TextColumn get id => text()();
  TextColumn get personaId => text()();
  TextColumn get sesionId => text()();
  TextColumn get ejercicioId => text()();
  TextColumn get varianteId => text()();
  IntColumn get n => integer()();
  TextColumn get lado => text().nullable()();
  IntColumn get reps => integer().nullable()();
  IntColumn get segundos => integer().nullable()();
  IntColumn get cargaPasos => integer().nullable()();
  TextColumn get bandaId => text().nullable()();
  IntColumn get esfuerzo => integer().nullable()();
  IntColumn get descansoRealS => integer().nullable()();
  TextColumn get sustituyeA => text().nullable()();

  /// `no_disponible`, `preferencia` u `otra`; **nunca** «molestia» (PG-19).
  TextColumn get motivoCambio => text().nullable()();
  DateTimeColumn get modificadoEn => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Pendientes,
    GimPerfil,
    GimPlanDias,
    GimInventario,
    GimBandas,
    GimSesiones,
    GimSeries,
  ],
)
class BaseLocal extends _$BaseLocal {
  BaseLocal(super.ejecutor);

  /// Base del dispositivo (archivo `gravity.sqlite` en los documentos de la app).
  factory BaseLocal.enDispositivo() =>
      BaseLocal(driftDatabase(name: 'gravity'));

  /// Base en memoria, para pruebas.
  factory BaseLocal.enMemoria() => BaseLocal(NativeDatabase.memory());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrador, desde, hasta) async {
      if (desde < 2) await migrador.addColumn(pendientes, pendientes.personaId);
      if (desde < 3) await migrador.addColumn(pendientes, pendientes.origen);
      // 4: «Mi gimnasio» (Fase 8): las seis tablas locales, vacías.
      if (desde < 4) {
        await migrador.createTable(gimPerfil);
        await migrador.createTable(gimPlanDias);
        await migrador.createTable(gimInventario);
        await migrador.createTable(gimBandas);
        await migrador.createTable(gimSesiones);
        await migrador.createTable(gimSeries);
      }
    },
  );
}
