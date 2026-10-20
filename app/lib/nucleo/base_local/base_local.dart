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

  /// El servidor lo rechazó (p. ej. por permisos); necesita atención.
  rechazado,
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

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Pendientes])
class BaseLocal extends _$BaseLocal {
  BaseLocal(super.ejecutor);

  /// Base del dispositivo (archivo `gravity.sqlite` en los documentos de la app).
  factory BaseLocal.enDispositivo() =>
      BaseLocal(driftDatabase(name: 'gravity'));

  /// Base en memoria, para pruebas.
  factory BaseLocal.enMemoria() => BaseLocal(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}
