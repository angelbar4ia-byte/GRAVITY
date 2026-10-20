// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_local.dart';

// ignore_for_file: type=lint
class $PendientesTable extends Pendientes
    with TableInfo<$PendientesTable, RegistroPendiente> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendientesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
    'tipo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cargaMeta = const VerificationMeta('carga');
  @override
  late final GeneratedColumn<String> carga = GeneratedColumn<String>(
    'carga',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intentosMeta = const VerificationMeta(
    'intentos',
  );
  @override
  late final GeneratedColumn<int> intentos = GeneratedColumn<int>(
    'intentos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<EstadoPendiente, String> estado =
      GeneratedColumn<String>(
        'estado',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EstadoPendiente>($PendientesTable.$converterestado);
  static const VerificationMeta _siguienteIntentoMeta = const VerificationMeta(
    'siguienteIntento',
  );
  @override
  late final GeneratedColumn<DateTime> siguienteIntento =
      GeneratedColumn<DateTime>(
        'siguiente_intento',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _ultimoErrorMeta = const VerificationMeta(
    'ultimoError',
  );
  @override
  late final GeneratedColumn<String> ultimoError = GeneratedColumn<String>(
    'ultimo_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tipo,
    carga,
    creadoEn,
    intentos,
    estado,
    siguienteIntento,
    ultimoError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pendientes';
  @override
  VerificationContext validateIntegrity(
    Insertable<RegistroPendiente> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
        _tipoMeta,
        tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('carga')) {
      context.handle(
        _cargaMeta,
        carga.isAcceptableOrUnknown(data['carga']!, _cargaMeta),
      );
    } else if (isInserting) {
      context.missing(_cargaMeta);
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    } else if (isInserting) {
      context.missing(_creadoEnMeta);
    }
    if (data.containsKey('intentos')) {
      context.handle(
        _intentosMeta,
        intentos.isAcceptableOrUnknown(data['intentos']!, _intentosMeta),
      );
    }
    if (data.containsKey('siguiente_intento')) {
      context.handle(
        _siguienteIntentoMeta,
        siguienteIntento.isAcceptableOrUnknown(
          data['siguiente_intento']!,
          _siguienteIntentoMeta,
        ),
      );
    }
    if (data.containsKey('ultimo_error')) {
      context.handle(
        _ultimoErrorMeta,
        ultimoError.isAcceptableOrUnknown(
          data['ultimo_error']!,
          _ultimoErrorMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RegistroPendiente map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RegistroPendiente(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo'],
      )!,
      carga: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}carga'],
      )!,
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
      intentos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}intentos'],
      )!,
      estado: $PendientesTable.$converterestado.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}estado'],
        )!,
      ),
      siguienteIntento: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}siguiente_intento'],
      ),
      ultimoError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ultimo_error'],
      ),
    );
  }

  @override
  $PendientesTable createAlias(String alias) {
    return $PendientesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EstadoPendiente, String, String> $converterestado =
      const EnumNameConverter<EstadoPendiente>(EstadoPendiente.values);
}

class RegistroPendiente extends DataClass
    implements Insertable<RegistroPendiente> {
  /// UUID generado en el dispositivo; el servidor lo usa como llave, así un
  /// reenvío nunca duplica (idempotencia).
  final String id;

  /// Qué es, p. ej. `finanzas.gasto`.
  final String tipo;

  /// Contenido en JSON.
  final String carga;
  final DateTime creadoEn;
  final int intentos;
  final EstadoPendiente estado;

  /// Cuándo puede volver a intentarse (espera creciente).
  final DateTime? siguienteIntento;
  final String? ultimoError;
  const RegistroPendiente({
    required this.id,
    required this.tipo,
    required this.carga,
    required this.creadoEn,
    required this.intentos,
    required this.estado,
    this.siguienteIntento,
    this.ultimoError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tipo'] = Variable<String>(tipo);
    map['carga'] = Variable<String>(carga);
    map['creado_en'] = Variable<DateTime>(creadoEn);
    map['intentos'] = Variable<int>(intentos);
    {
      map['estado'] = Variable<String>(
        $PendientesTable.$converterestado.toSql(estado),
      );
    }
    if (!nullToAbsent || siguienteIntento != null) {
      map['siguiente_intento'] = Variable<DateTime>(siguienteIntento);
    }
    if (!nullToAbsent || ultimoError != null) {
      map['ultimo_error'] = Variable<String>(ultimoError);
    }
    return map;
  }

  PendientesCompanion toCompanion(bool nullToAbsent) {
    return PendientesCompanion(
      id: Value(id),
      tipo: Value(tipo),
      carga: Value(carga),
      creadoEn: Value(creadoEn),
      intentos: Value(intentos),
      estado: Value(estado),
      siguienteIntento: siguienteIntento == null && nullToAbsent
          ? const Value.absent()
          : Value(siguienteIntento),
      ultimoError: ultimoError == null && nullToAbsent
          ? const Value.absent()
          : Value(ultimoError),
    );
  }

  factory RegistroPendiente.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RegistroPendiente(
      id: serializer.fromJson<String>(json['id']),
      tipo: serializer.fromJson<String>(json['tipo']),
      carga: serializer.fromJson<String>(json['carga']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
      intentos: serializer.fromJson<int>(json['intentos']),
      estado: $PendientesTable.$converterestado.fromJson(
        serializer.fromJson<String>(json['estado']),
      ),
      siguienteIntento: serializer.fromJson<DateTime?>(
        json['siguienteIntento'],
      ),
      ultimoError: serializer.fromJson<String?>(json['ultimoError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tipo': serializer.toJson<String>(tipo),
      'carga': serializer.toJson<String>(carga),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
      'intentos': serializer.toJson<int>(intentos),
      'estado': serializer.toJson<String>(
        $PendientesTable.$converterestado.toJson(estado),
      ),
      'siguienteIntento': serializer.toJson<DateTime?>(siguienteIntento),
      'ultimoError': serializer.toJson<String?>(ultimoError),
    };
  }

  RegistroPendiente copyWith({
    String? id,
    String? tipo,
    String? carga,
    DateTime? creadoEn,
    int? intentos,
    EstadoPendiente? estado,
    Value<DateTime?> siguienteIntento = const Value.absent(),
    Value<String?> ultimoError = const Value.absent(),
  }) => RegistroPendiente(
    id: id ?? this.id,
    tipo: tipo ?? this.tipo,
    carga: carga ?? this.carga,
    creadoEn: creadoEn ?? this.creadoEn,
    intentos: intentos ?? this.intentos,
    estado: estado ?? this.estado,
    siguienteIntento: siguienteIntento.present
        ? siguienteIntento.value
        : this.siguienteIntento,
    ultimoError: ultimoError.present ? ultimoError.value : this.ultimoError,
  );
  RegistroPendiente copyWithCompanion(PendientesCompanion data) {
    return RegistroPendiente(
      id: data.id.present ? data.id.value : this.id,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      carga: data.carga.present ? data.carga.value : this.carga,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
      intentos: data.intentos.present ? data.intentos.value : this.intentos,
      estado: data.estado.present ? data.estado.value : this.estado,
      siguienteIntento: data.siguienteIntento.present
          ? data.siguienteIntento.value
          : this.siguienteIntento,
      ultimoError: data.ultimoError.present
          ? data.ultimoError.value
          : this.ultimoError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RegistroPendiente(')
          ..write('id: $id, ')
          ..write('tipo: $tipo, ')
          ..write('carga: $carga, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('intentos: $intentos, ')
          ..write('estado: $estado, ')
          ..write('siguienteIntento: $siguienteIntento, ')
          ..write('ultimoError: $ultimoError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tipo,
    carga,
    creadoEn,
    intentos,
    estado,
    siguienteIntento,
    ultimoError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegistroPendiente &&
          other.id == this.id &&
          other.tipo == this.tipo &&
          other.carga == this.carga &&
          other.creadoEn == this.creadoEn &&
          other.intentos == this.intentos &&
          other.estado == this.estado &&
          other.siguienteIntento == this.siguienteIntento &&
          other.ultimoError == this.ultimoError);
}

class PendientesCompanion extends UpdateCompanion<RegistroPendiente> {
  final Value<String> id;
  final Value<String> tipo;
  final Value<String> carga;
  final Value<DateTime> creadoEn;
  final Value<int> intentos;
  final Value<EstadoPendiente> estado;
  final Value<DateTime?> siguienteIntento;
  final Value<String?> ultimoError;
  final Value<int> rowid;
  const PendientesCompanion({
    this.id = const Value.absent(),
    this.tipo = const Value.absent(),
    this.carga = const Value.absent(),
    this.creadoEn = const Value.absent(),
    this.intentos = const Value.absent(),
    this.estado = const Value.absent(),
    this.siguienteIntento = const Value.absent(),
    this.ultimoError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendientesCompanion.insert({
    required String id,
    required String tipo,
    required String carga,
    required DateTime creadoEn,
    this.intentos = const Value.absent(),
    required EstadoPendiente estado,
    this.siguienteIntento = const Value.absent(),
    this.ultimoError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tipo = Value(tipo),
       carga = Value(carga),
       creadoEn = Value(creadoEn),
       estado = Value(estado);
  static Insertable<RegistroPendiente> custom({
    Expression<String>? id,
    Expression<String>? tipo,
    Expression<String>? carga,
    Expression<DateTime>? creadoEn,
    Expression<int>? intentos,
    Expression<String>? estado,
    Expression<DateTime>? siguienteIntento,
    Expression<String>? ultimoError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tipo != null) 'tipo': tipo,
      if (carga != null) 'carga': carga,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (intentos != null) 'intentos': intentos,
      if (estado != null) 'estado': estado,
      if (siguienteIntento != null) 'siguiente_intento': siguienteIntento,
      if (ultimoError != null) 'ultimo_error': ultimoError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendientesCompanion copyWith({
    Value<String>? id,
    Value<String>? tipo,
    Value<String>? carga,
    Value<DateTime>? creadoEn,
    Value<int>? intentos,
    Value<EstadoPendiente>? estado,
    Value<DateTime?>? siguienteIntento,
    Value<String?>? ultimoError,
    Value<int>? rowid,
  }) {
    return PendientesCompanion(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      carga: carga ?? this.carga,
      creadoEn: creadoEn ?? this.creadoEn,
      intentos: intentos ?? this.intentos,
      estado: estado ?? this.estado,
      siguienteIntento: siguienteIntento ?? this.siguienteIntento,
      ultimoError: ultimoError ?? this.ultimoError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (carga.present) {
      map['carga'] = Variable<String>(carga.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    if (intentos.present) {
      map['intentos'] = Variable<int>(intentos.value);
    }
    if (estado.present) {
      map['estado'] = Variable<String>(
        $PendientesTable.$converterestado.toSql(estado.value),
      );
    }
    if (siguienteIntento.present) {
      map['siguiente_intento'] = Variable<DateTime>(siguienteIntento.value);
    }
    if (ultimoError.present) {
      map['ultimo_error'] = Variable<String>(ultimoError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendientesCompanion(')
          ..write('id: $id, ')
          ..write('tipo: $tipo, ')
          ..write('carga: $carga, ')
          ..write('creadoEn: $creadoEn, ')
          ..write('intentos: $intentos, ')
          ..write('estado: $estado, ')
          ..write('siguienteIntento: $siguienteIntento, ')
          ..write('ultimoError: $ultimoError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$BaseLocal extends GeneratedDatabase {
  _$BaseLocal(QueryExecutor e) : super(e);
  $BaseLocalManager get managers => $BaseLocalManager(this);
  late final $PendientesTable pendientes = $PendientesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [pendientes];
}

typedef $$PendientesTableCreateCompanionBuilder = PendientesCompanion Function({
  required String id,
  required String tipo,
  required String carga,
  required DateTime creadoEn,
  Value<int> intentos,
  required EstadoPendiente estado,
  Value<DateTime?> siguienteIntento,
  Value<String?> ultimoError,
  Value<int> rowid,
});
typedef $$PendientesTableUpdateCompanionBuilder = PendientesCompanion Function({
  Value<String> id,
  Value<String> tipo,
  Value<String> carga,
  Value<DateTime> creadoEn,
  Value<int> intentos,
  Value<EstadoPendiente> estado,
  Value<DateTime?> siguienteIntento,
  Value<String?> ultimoError,
  Value<int> rowid,
});

class $$PendientesTableFilterComposer
    extends Composer<_$BaseLocal, $PendientesTable> {
  $$PendientesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get carga => $composableBuilder(
    column: $table.carga,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intentos => $composableBuilder(
    column: $table.intentos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EstadoPendiente, EstadoPendiente, String>
  get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get siguienteIntento => $composableBuilder(
    column: $table.siguienteIntento,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ultimoError => $composableBuilder(
    column: $table.ultimoError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendientesTableOrderingComposer
    extends Composer<_$BaseLocal, $PendientesTable> {
  $$PendientesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carga => $composableBuilder(
    column: $table.carga,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intentos => $composableBuilder(
    column: $table.intentos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get siguienteIntento => $composableBuilder(
    column: $table.siguienteIntento,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ultimoError => $composableBuilder(
    column: $table.ultimoError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendientesTableAnnotationComposer
    extends Composer<_$BaseLocal, $PendientesTable> {
  $$PendientesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<String> get carga =>
      $composableBuilder(column: $table.carga, builder: (column) => column);

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);

  GeneratedColumn<int> get intentos =>
      $composableBuilder(column: $table.intentos, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EstadoPendiente, String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<DateTime> get siguienteIntento => $composableBuilder(
    column: $table.siguienteIntento,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ultimoError => $composableBuilder(
    column: $table.ultimoError,
    builder: (column) => column,
  );
}

class $$PendientesTableTableManager
    extends
        RootTableManager<
          _$BaseLocal,
          $PendientesTable,
          RegistroPendiente,
          $$PendientesTableFilterComposer,
          $$PendientesTableOrderingComposer,
          $$PendientesTableAnnotationComposer,
          $$PendientesTableCreateCompanionBuilder,
          $$PendientesTableUpdateCompanionBuilder,
          (
            RegistroPendiente,
            BaseReferences<_$BaseLocal, $PendientesTable, RegistroPendiente>,
          ),
          RegistroPendiente,
          PrefetchHooks Function()
        > {
  $$PendientesTableTableManager(_$BaseLocal db, $PendientesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendientesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendientesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendientesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tipo = const Value.absent(),
                Value<String> carga = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
                Value<int> intentos = const Value.absent(),
                Value<EstadoPendiente> estado = const Value.absent(),
                Value<DateTime?> siguienteIntento = const Value.absent(),
                Value<String?> ultimoError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendientesCompanion(
                id: id,
                tipo: tipo,
                carga: carga,
                creadoEn: creadoEn,
                intentos: intentos,
                estado: estado,
                siguienteIntento: siguienteIntento,
                ultimoError: ultimoError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tipo,
                required String carga,
                required DateTime creadoEn,
                Value<int> intentos = const Value.absent(),
                required EstadoPendiente estado,
                Value<DateTime?> siguienteIntento = const Value.absent(),
                Value<String?> ultimoError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendientesCompanion.insert(
                id: id,
                tipo: tipo,
                carga: carga,
                creadoEn: creadoEn,
                intentos: intentos,
                estado: estado,
                siguienteIntento: siguienteIntento,
                ultimoError: ultimoError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendientesTable, RegistroPendiente>(table),
                  BaseReferences<
                    _$BaseLocal,
                    $PendientesTable,
                    RegistroPendiente
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendientesTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseLocal,
      $PendientesTable,
      RegistroPendiente,
      $$PendientesTableFilterComposer,
      $$PendientesTableOrderingComposer,
      $$PendientesTableAnnotationComposer,
      $$PendientesTableCreateCompanionBuilder,
      $$PendientesTableUpdateCompanionBuilder,
      (
        RegistroPendiente,
        BaseReferences<_$BaseLocal, $PendientesTable, RegistroPendiente>,
      ),
      RegistroPendiente,
      PrefetchHooks Function()
    >;

class $BaseLocalManager {
  final _$BaseLocal _db;
  $BaseLocalManager(this._db);
  $$PendientesTableTableManager get pendientes =>
      $$PendientesTableTableManager(_db, _db.pendientes);
}
