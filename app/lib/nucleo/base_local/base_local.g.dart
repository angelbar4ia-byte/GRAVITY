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
  static const VerificationMeta _personaIdMeta = const VerificationMeta(
    'personaId',
  );
  @override
  late final GeneratedColumn<String> personaId = GeneratedColumn<String>(
    'persona_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<OrigenRegistro?, String> origen =
      GeneratedColumn<String>(
        'origen',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<OrigenRegistro?>($PendientesTable.$converterorigenn);
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
    personaId,
    origen,
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
    if (data.containsKey('persona_id')) {
      context.handle(
        _personaIdMeta,
        personaId.isAcceptableOrUnknown(data['persona_id']!, _personaIdMeta),
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
      personaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona_id'],
      ),
      origen: $PendientesTable.$converterorigenn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}origen'],
        ),
      ),
    );
  }

  @override
  $PendientesTable createAlias(String alias) {
    return $PendientesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EstadoPendiente, String, String> $converterestado =
      const EnumNameConverter<EstadoPendiente>(EstadoPendiente.values);
  static JsonTypeConverter2<OrigenRegistro, String, String> $converterorigen =
      const EnumNameConverter<OrigenRegistro>(OrigenRegistro.values);
  static JsonTypeConverter2<OrigenRegistro?, String?, String?>
  $converterorigenn = JsonTypeConverter2.asNullable($converterorigen);
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

  /// Persona que lo registró (id de `personas`). Solo se envía con la sesión
  /// del servidor de esa misma persona (revisión de la Fase 0, I4).
  final String? personaId;

  /// Desde dónde se registró (`null` en los de antes de la versión 3:
  /// [OrigenRegistro.propio]).
  final OrigenRegistro? origen;
  const RegistroPendiente({
    required this.id,
    required this.tipo,
    required this.carga,
    required this.creadoEn,
    required this.intentos,
    required this.estado,
    this.siguienteIntento,
    this.ultimoError,
    this.personaId,
    this.origen,
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
    if (!nullToAbsent || personaId != null) {
      map['persona_id'] = Variable<String>(personaId);
    }
    if (!nullToAbsent || origen != null) {
      map['origen'] = Variable<String>(
        $PendientesTable.$converterorigenn.toSql(origen),
      );
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
      personaId: personaId == null && nullToAbsent
          ? const Value.absent()
          : Value(personaId),
      origen: origen == null && nullToAbsent
          ? const Value.absent()
          : Value(origen),
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
      personaId: serializer.fromJson<String?>(json['personaId']),
      origen: $PendientesTable.$converterorigenn.fromJson(
        serializer.fromJson<String?>(json['origen']),
      ),
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
      'personaId': serializer.toJson<String?>(personaId),
      'origen': serializer.toJson<String?>(
        $PendientesTable.$converterorigenn.toJson(origen),
      ),
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
    Value<String?> personaId = const Value.absent(),
    Value<OrigenRegistro?> origen = const Value.absent(),
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
    personaId: personaId.present ? personaId.value : this.personaId,
    origen: origen.present ? origen.value : this.origen,
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
      personaId: data.personaId.present ? data.personaId.value : this.personaId,
      origen: data.origen.present ? data.origen.value : this.origen,
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
          ..write('ultimoError: $ultimoError, ')
          ..write('personaId: $personaId, ')
          ..write('origen: $origen')
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
    personaId,
    origen,
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
          other.ultimoError == this.ultimoError &&
          other.personaId == this.personaId &&
          other.origen == this.origen);
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
  final Value<String?> personaId;
  final Value<OrigenRegistro?> origen;
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
    this.personaId = const Value.absent(),
    this.origen = const Value.absent(),
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
    this.personaId = const Value.absent(),
    this.origen = const Value.absent(),
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
    Expression<String>? personaId,
    Expression<String>? origen,
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
      if (personaId != null) 'persona_id': personaId,
      if (origen != null) 'origen': origen,
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
    Value<String?>? personaId,
    Value<OrigenRegistro?>? origen,
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
      personaId: personaId ?? this.personaId,
      origen: origen ?? this.origen,
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
    if (personaId.present) {
      map['persona_id'] = Variable<String>(personaId.value);
    }
    if (origen.present) {
      map['origen'] = Variable<String>(
        $PendientesTable.$converterorigenn.toSql(origen.value),
      );
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
          ..write('personaId: $personaId, ')
          ..write('origen: $origen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GimPerfilTable extends GimPerfil
    with TableInfo<$GimPerfilTable, GimPerfilFila> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GimPerfilTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _personaIdMeta = const VerificationMeta(
    'personaId',
  );
  @override
  late final GeneratedColumn<String> personaId = GeneratedColumn<String>(
    'persona_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diasPlanMeta = const VerificationMeta(
    'diasPlan',
  );
  @override
  late final GeneratedColumn<int> diasPlan = GeneratedColumn<int>(
    'dias_plan',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _versionPrefMeta = const VerificationMeta(
    'versionPref',
  );
  @override
  late final GeneratedColumn<String> versionPref = GeneratedColumn<String>(
    'version_pref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('auto'),
  );
  static const VerificationMeta _ventanaMeta = const VerificationMeta(
    'ventana',
  );
  @override
  late final GeneratedColumn<String> ventana = GeneratedColumn<String>(
    'ventana',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('noche'),
  );
  static const VerificationMeta _nocheDesdeMeta = const VerificationMeta(
    'nocheDesde',
  );
  @override
  late final GeneratedColumn<String> nocheDesde = GeneratedColumn<String>(
    'noche_desde',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('19:00'),
  );
  static const VerificationMeta _objetivoMeta = const VerificationMeta(
    'objetivo',
  );
  @override
  late final GeneratedColumn<String> objetivo = GeneratedColumn<String>(
    'objetivo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('salud_general'),
  );
  static const VerificationMeta _nivelMeta = const VerificationMeta('nivel');
  @override
  late final GeneratedColumn<String> nivel = GeneratedColumn<String>(
    'nivel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('principiante'),
  );
  static const VerificationMeta _inicioCicloMeta = const VerificationMeta(
    'inicioCiclo',
  );
  @override
  late final GeneratedColumn<String> inicioCiclo = GeneratedColumn<String>(
    'inicio_ciclo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cicloSemanasMeta = const VerificationMeta(
    'cicloSemanas',
  );
  @override
  late final GeneratedColumn<int> cicloSemanas = GeneratedColumn<int>(
    'ciclo_semanas',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _descansoSMeta = const VerificationMeta(
    'descansoS',
  );
  @override
  late final GeneratedColumn<int> descansoS = GeneratedColumn<int>(
    'descanso_s',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _margenDormirMinMeta = const VerificationMeta(
    'margenDormirMin',
  );
  @override
  late final GeneratedColumn<int> margenDormirMin = GeneratedColumn<int>(
    'margen_dormir_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(90),
  );
  static const VerificationMeta _pruebaDesdeMeta = const VerificationMeta(
    'pruebaDesde',
  );
  @override
  late final GeneratedColumn<String> pruebaDesde = GeneratedColumn<String>(
    'prueba_desde',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pruebaVentanaMeta = const VerificationMeta(
    'pruebaVentana',
  );
  @override
  late final GeneratedColumn<String> pruebaVentana = GeneratedColumn<String>(
    'prueba_ventana',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vozDescansoMeta = const VerificationMeta(
    'vozDescanso',
  );
  @override
  late final GeneratedColumn<bool> vozDescanso = GeneratedColumn<bool>(
    'voz_descanso',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("voz_descanso" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _avisoVistoEnMeta = const VerificationMeta(
    'avisoVistoEn',
  );
  @override
  late final GeneratedColumn<DateTime> avisoVistoEn = GeneratedColumn<DateTime>(
    'aviso_visto_en',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modificadoEnMeta = const VerificationMeta(
    'modificadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> modificadoEn = GeneratedColumn<DateTime>(
    'modificado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    personaId,
    diasPlan,
    versionPref,
    ventana,
    nocheDesde,
    objetivo,
    nivel,
    inicioCiclo,
    cicloSemanas,
    descansoS,
    margenDormirMin,
    pruebaDesde,
    pruebaVentana,
    vozDescanso,
    avisoVistoEn,
    modificadoEn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gim_perfil';
  @override
  VerificationContext validateIntegrity(
    Insertable<GimPerfilFila> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('persona_id')) {
      context.handle(
        _personaIdMeta,
        personaId.isAcceptableOrUnknown(data['persona_id']!, _personaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personaIdMeta);
    }
    if (data.containsKey('dias_plan')) {
      context.handle(
        _diasPlanMeta,
        diasPlan.isAcceptableOrUnknown(data['dias_plan']!, _diasPlanMeta),
      );
    }
    if (data.containsKey('version_pref')) {
      context.handle(
        _versionPrefMeta,
        versionPref.isAcceptableOrUnknown(
          data['version_pref']!,
          _versionPrefMeta,
        ),
      );
    }
    if (data.containsKey('ventana')) {
      context.handle(
        _ventanaMeta,
        ventana.isAcceptableOrUnknown(data['ventana']!, _ventanaMeta),
      );
    }
    if (data.containsKey('noche_desde')) {
      context.handle(
        _nocheDesdeMeta,
        nocheDesde.isAcceptableOrUnknown(data['noche_desde']!, _nocheDesdeMeta),
      );
    }
    if (data.containsKey('objetivo')) {
      context.handle(
        _objetivoMeta,
        objetivo.isAcceptableOrUnknown(data['objetivo']!, _objetivoMeta),
      );
    }
    if (data.containsKey('nivel')) {
      context.handle(
        _nivelMeta,
        nivel.isAcceptableOrUnknown(data['nivel']!, _nivelMeta),
      );
    }
    if (data.containsKey('inicio_ciclo')) {
      context.handle(
        _inicioCicloMeta,
        inicioCiclo.isAcceptableOrUnknown(
          data['inicio_ciclo']!,
          _inicioCicloMeta,
        ),
      );
    }
    if (data.containsKey('ciclo_semanas')) {
      context.handle(
        _cicloSemanasMeta,
        cicloSemanas.isAcceptableOrUnknown(
          data['ciclo_semanas']!,
          _cicloSemanasMeta,
        ),
      );
    }
    if (data.containsKey('descanso_s')) {
      context.handle(
        _descansoSMeta,
        descansoS.isAcceptableOrUnknown(data['descanso_s']!, _descansoSMeta),
      );
    }
    if (data.containsKey('margen_dormir_min')) {
      context.handle(
        _margenDormirMinMeta,
        margenDormirMin.isAcceptableOrUnknown(
          data['margen_dormir_min']!,
          _margenDormirMinMeta,
        ),
      );
    }
    if (data.containsKey('prueba_desde')) {
      context.handle(
        _pruebaDesdeMeta,
        pruebaDesde.isAcceptableOrUnknown(
          data['prueba_desde']!,
          _pruebaDesdeMeta,
        ),
      );
    }
    if (data.containsKey('prueba_ventana')) {
      context.handle(
        _pruebaVentanaMeta,
        pruebaVentana.isAcceptableOrUnknown(
          data['prueba_ventana']!,
          _pruebaVentanaMeta,
        ),
      );
    }
    if (data.containsKey('voz_descanso')) {
      context.handle(
        _vozDescansoMeta,
        vozDescanso.isAcceptableOrUnknown(
          data['voz_descanso']!,
          _vozDescansoMeta,
        ),
      );
    }
    if (data.containsKey('aviso_visto_en')) {
      context.handle(
        _avisoVistoEnMeta,
        avisoVistoEn.isAcceptableOrUnknown(
          data['aviso_visto_en']!,
          _avisoVistoEnMeta,
        ),
      );
    }
    if (data.containsKey('modificado_en')) {
      context.handle(
        _modificadoEnMeta,
        modificadoEn.isAcceptableOrUnknown(
          data['modificado_en']!,
          _modificadoEnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modificadoEnMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {personaId};
  @override
  GimPerfilFila map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GimPerfilFila(
      personaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona_id'],
      )!,
      diasPlan: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dias_plan'],
      )!,
      versionPref: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_pref'],
      )!,
      ventana: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ventana'],
      )!,
      nocheDesde: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}noche_desde'],
      )!,
      objetivo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}objetivo'],
      )!,
      nivel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nivel'],
      )!,
      inicioCiclo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}inicio_ciclo'],
      ),
      cicloSemanas: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ciclo_semanas'],
      )!,
      descansoS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}descanso_s'],
      ),
      margenDormirMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}margen_dormir_min'],
      )!,
      pruebaDesde: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prueba_desde'],
      ),
      pruebaVentana: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prueba_ventana'],
      ),
      vozDescanso: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}voz_descanso'],
      )!,
      avisoVistoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}aviso_visto_en'],
      ),
      modificadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modificado_en'],
      )!,
    );
  }

  @override
  $GimPerfilTable createAlias(String alias) {
    return $GimPerfilTable(attachedDatabase, alias);
  }
}

class GimPerfilFila extends DataClass implements Insertable<GimPerfilFila> {
  final String personaId;
  final int diasPlan;
  final String versionPref;
  final String ventana;
  final String nocheDesde;
  final String objetivo;
  final String nivel;
  final String? inicioCiclo;
  final int cicloSemanas;
  final int? descansoS;
  final int margenDormirMin;
  final String? pruebaDesde;
  final String? pruebaVentana;
  final bool vozDescanso;
  final DateTime? avisoVistoEn;
  final DateTime modificadoEn;
  const GimPerfilFila({
    required this.personaId,
    required this.diasPlan,
    required this.versionPref,
    required this.ventana,
    required this.nocheDesde,
    required this.objetivo,
    required this.nivel,
    this.inicioCiclo,
    required this.cicloSemanas,
    this.descansoS,
    required this.margenDormirMin,
    this.pruebaDesde,
    this.pruebaVentana,
    required this.vozDescanso,
    this.avisoVistoEn,
    required this.modificadoEn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['persona_id'] = Variable<String>(personaId);
    map['dias_plan'] = Variable<int>(diasPlan);
    map['version_pref'] = Variable<String>(versionPref);
    map['ventana'] = Variable<String>(ventana);
    map['noche_desde'] = Variable<String>(nocheDesde);
    map['objetivo'] = Variable<String>(objetivo);
    map['nivel'] = Variable<String>(nivel);
    if (!nullToAbsent || inicioCiclo != null) {
      map['inicio_ciclo'] = Variable<String>(inicioCiclo);
    }
    map['ciclo_semanas'] = Variable<int>(cicloSemanas);
    if (!nullToAbsent || descansoS != null) {
      map['descanso_s'] = Variable<int>(descansoS);
    }
    map['margen_dormir_min'] = Variable<int>(margenDormirMin);
    if (!nullToAbsent || pruebaDesde != null) {
      map['prueba_desde'] = Variable<String>(pruebaDesde);
    }
    if (!nullToAbsent || pruebaVentana != null) {
      map['prueba_ventana'] = Variable<String>(pruebaVentana);
    }
    map['voz_descanso'] = Variable<bool>(vozDescanso);
    if (!nullToAbsent || avisoVistoEn != null) {
      map['aviso_visto_en'] = Variable<DateTime>(avisoVistoEn);
    }
    map['modificado_en'] = Variable<DateTime>(modificadoEn);
    return map;
  }

  GimPerfilCompanion toCompanion(bool nullToAbsent) {
    return GimPerfilCompanion(
      personaId: Value(personaId),
      diasPlan: Value(diasPlan),
      versionPref: Value(versionPref),
      ventana: Value(ventana),
      nocheDesde: Value(nocheDesde),
      objetivo: Value(objetivo),
      nivel: Value(nivel),
      inicioCiclo: inicioCiclo == null && nullToAbsent
          ? const Value.absent()
          : Value(inicioCiclo),
      cicloSemanas: Value(cicloSemanas),
      descansoS: descansoS == null && nullToAbsent
          ? const Value.absent()
          : Value(descansoS),
      margenDormirMin: Value(margenDormirMin),
      pruebaDesde: pruebaDesde == null && nullToAbsent
          ? const Value.absent()
          : Value(pruebaDesde),
      pruebaVentana: pruebaVentana == null && nullToAbsent
          ? const Value.absent()
          : Value(pruebaVentana),
      vozDescanso: Value(vozDescanso),
      avisoVistoEn: avisoVistoEn == null && nullToAbsent
          ? const Value.absent()
          : Value(avisoVistoEn),
      modificadoEn: Value(modificadoEn),
    );
  }

  factory GimPerfilFila.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GimPerfilFila(
      personaId: serializer.fromJson<String>(json['personaId']),
      diasPlan: serializer.fromJson<int>(json['diasPlan']),
      versionPref: serializer.fromJson<String>(json['versionPref']),
      ventana: serializer.fromJson<String>(json['ventana']),
      nocheDesde: serializer.fromJson<String>(json['nocheDesde']),
      objetivo: serializer.fromJson<String>(json['objetivo']),
      nivel: serializer.fromJson<String>(json['nivel']),
      inicioCiclo: serializer.fromJson<String?>(json['inicioCiclo']),
      cicloSemanas: serializer.fromJson<int>(json['cicloSemanas']),
      descansoS: serializer.fromJson<int?>(json['descansoS']),
      margenDormirMin: serializer.fromJson<int>(json['margenDormirMin']),
      pruebaDesde: serializer.fromJson<String?>(json['pruebaDesde']),
      pruebaVentana: serializer.fromJson<String?>(json['pruebaVentana']),
      vozDescanso: serializer.fromJson<bool>(json['vozDescanso']),
      avisoVistoEn: serializer.fromJson<DateTime?>(json['avisoVistoEn']),
      modificadoEn: serializer.fromJson<DateTime>(json['modificadoEn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'personaId': serializer.toJson<String>(personaId),
      'diasPlan': serializer.toJson<int>(diasPlan),
      'versionPref': serializer.toJson<String>(versionPref),
      'ventana': serializer.toJson<String>(ventana),
      'nocheDesde': serializer.toJson<String>(nocheDesde),
      'objetivo': serializer.toJson<String>(objetivo),
      'nivel': serializer.toJson<String>(nivel),
      'inicioCiclo': serializer.toJson<String?>(inicioCiclo),
      'cicloSemanas': serializer.toJson<int>(cicloSemanas),
      'descansoS': serializer.toJson<int?>(descansoS),
      'margenDormirMin': serializer.toJson<int>(margenDormirMin),
      'pruebaDesde': serializer.toJson<String?>(pruebaDesde),
      'pruebaVentana': serializer.toJson<String?>(pruebaVentana),
      'vozDescanso': serializer.toJson<bool>(vozDescanso),
      'avisoVistoEn': serializer.toJson<DateTime?>(avisoVistoEn),
      'modificadoEn': serializer.toJson<DateTime>(modificadoEn),
    };
  }

  GimPerfilFila copyWith({
    String? personaId,
    int? diasPlan,
    String? versionPref,
    String? ventana,
    String? nocheDesde,
    String? objetivo,
    String? nivel,
    Value<String?> inicioCiclo = const Value.absent(),
    int? cicloSemanas,
    Value<int?> descansoS = const Value.absent(),
    int? margenDormirMin,
    Value<String?> pruebaDesde = const Value.absent(),
    Value<String?> pruebaVentana = const Value.absent(),
    bool? vozDescanso,
    Value<DateTime?> avisoVistoEn = const Value.absent(),
    DateTime? modificadoEn,
  }) => GimPerfilFila(
    personaId: personaId ?? this.personaId,
    diasPlan: diasPlan ?? this.diasPlan,
    versionPref: versionPref ?? this.versionPref,
    ventana: ventana ?? this.ventana,
    nocheDesde: nocheDesde ?? this.nocheDesde,
    objetivo: objetivo ?? this.objetivo,
    nivel: nivel ?? this.nivel,
    inicioCiclo: inicioCiclo.present ? inicioCiclo.value : this.inicioCiclo,
    cicloSemanas: cicloSemanas ?? this.cicloSemanas,
    descansoS: descansoS.present ? descansoS.value : this.descansoS,
    margenDormirMin: margenDormirMin ?? this.margenDormirMin,
    pruebaDesde: pruebaDesde.present ? pruebaDesde.value : this.pruebaDesde,
    pruebaVentana: pruebaVentana.present
        ? pruebaVentana.value
        : this.pruebaVentana,
    vozDescanso: vozDescanso ?? this.vozDescanso,
    avisoVistoEn: avisoVistoEn.present ? avisoVistoEn.value : this.avisoVistoEn,
    modificadoEn: modificadoEn ?? this.modificadoEn,
  );
  GimPerfilFila copyWithCompanion(GimPerfilCompanion data) {
    return GimPerfilFila(
      personaId: data.personaId.present ? data.personaId.value : this.personaId,
      diasPlan: data.diasPlan.present ? data.diasPlan.value : this.diasPlan,
      versionPref: data.versionPref.present
          ? data.versionPref.value
          : this.versionPref,
      ventana: data.ventana.present ? data.ventana.value : this.ventana,
      nocheDesde: data.nocheDesde.present
          ? data.nocheDesde.value
          : this.nocheDesde,
      objetivo: data.objetivo.present ? data.objetivo.value : this.objetivo,
      nivel: data.nivel.present ? data.nivel.value : this.nivel,
      inicioCiclo: data.inicioCiclo.present
          ? data.inicioCiclo.value
          : this.inicioCiclo,
      cicloSemanas: data.cicloSemanas.present
          ? data.cicloSemanas.value
          : this.cicloSemanas,
      descansoS: data.descansoS.present ? data.descansoS.value : this.descansoS,
      margenDormirMin: data.margenDormirMin.present
          ? data.margenDormirMin.value
          : this.margenDormirMin,
      pruebaDesde: data.pruebaDesde.present
          ? data.pruebaDesde.value
          : this.pruebaDesde,
      pruebaVentana: data.pruebaVentana.present
          ? data.pruebaVentana.value
          : this.pruebaVentana,
      vozDescanso: data.vozDescanso.present
          ? data.vozDescanso.value
          : this.vozDescanso,
      avisoVistoEn: data.avisoVistoEn.present
          ? data.avisoVistoEn.value
          : this.avisoVistoEn,
      modificadoEn: data.modificadoEn.present
          ? data.modificadoEn.value
          : this.modificadoEn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GimPerfilFila(')
          ..write('personaId: $personaId, ')
          ..write('diasPlan: $diasPlan, ')
          ..write('versionPref: $versionPref, ')
          ..write('ventana: $ventana, ')
          ..write('nocheDesde: $nocheDesde, ')
          ..write('objetivo: $objetivo, ')
          ..write('nivel: $nivel, ')
          ..write('inicioCiclo: $inicioCiclo, ')
          ..write('cicloSemanas: $cicloSemanas, ')
          ..write('descansoS: $descansoS, ')
          ..write('margenDormirMin: $margenDormirMin, ')
          ..write('pruebaDesde: $pruebaDesde, ')
          ..write('pruebaVentana: $pruebaVentana, ')
          ..write('vozDescanso: $vozDescanso, ')
          ..write('avisoVistoEn: $avisoVistoEn, ')
          ..write('modificadoEn: $modificadoEn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    personaId,
    diasPlan,
    versionPref,
    ventana,
    nocheDesde,
    objetivo,
    nivel,
    inicioCiclo,
    cicloSemanas,
    descansoS,
    margenDormirMin,
    pruebaDesde,
    pruebaVentana,
    vozDescanso,
    avisoVistoEn,
    modificadoEn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GimPerfilFila &&
          other.personaId == this.personaId &&
          other.diasPlan == this.diasPlan &&
          other.versionPref == this.versionPref &&
          other.ventana == this.ventana &&
          other.nocheDesde == this.nocheDesde &&
          other.objetivo == this.objetivo &&
          other.nivel == this.nivel &&
          other.inicioCiclo == this.inicioCiclo &&
          other.cicloSemanas == this.cicloSemanas &&
          other.descansoS == this.descansoS &&
          other.margenDormirMin == this.margenDormirMin &&
          other.pruebaDesde == this.pruebaDesde &&
          other.pruebaVentana == this.pruebaVentana &&
          other.vozDescanso == this.vozDescanso &&
          other.avisoVistoEn == this.avisoVistoEn &&
          other.modificadoEn == this.modificadoEn);
}

class GimPerfilCompanion extends UpdateCompanion<GimPerfilFila> {
  final Value<String> personaId;
  final Value<int> diasPlan;
  final Value<String> versionPref;
  final Value<String> ventana;
  final Value<String> nocheDesde;
  final Value<String> objetivo;
  final Value<String> nivel;
  final Value<String?> inicioCiclo;
  final Value<int> cicloSemanas;
  final Value<int?> descansoS;
  final Value<int> margenDormirMin;
  final Value<String?> pruebaDesde;
  final Value<String?> pruebaVentana;
  final Value<bool> vozDescanso;
  final Value<DateTime?> avisoVistoEn;
  final Value<DateTime> modificadoEn;
  final Value<int> rowid;
  const GimPerfilCompanion({
    this.personaId = const Value.absent(),
    this.diasPlan = const Value.absent(),
    this.versionPref = const Value.absent(),
    this.ventana = const Value.absent(),
    this.nocheDesde = const Value.absent(),
    this.objetivo = const Value.absent(),
    this.nivel = const Value.absent(),
    this.inicioCiclo = const Value.absent(),
    this.cicloSemanas = const Value.absent(),
    this.descansoS = const Value.absent(),
    this.margenDormirMin = const Value.absent(),
    this.pruebaDesde = const Value.absent(),
    this.pruebaVentana = const Value.absent(),
    this.vozDescanso = const Value.absent(),
    this.avisoVistoEn = const Value.absent(),
    this.modificadoEn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GimPerfilCompanion.insert({
    required String personaId,
    this.diasPlan = const Value.absent(),
    this.versionPref = const Value.absent(),
    this.ventana = const Value.absent(),
    this.nocheDesde = const Value.absent(),
    this.objetivo = const Value.absent(),
    this.nivel = const Value.absent(),
    this.inicioCiclo = const Value.absent(),
    this.cicloSemanas = const Value.absent(),
    this.descansoS = const Value.absent(),
    this.margenDormirMin = const Value.absent(),
    this.pruebaDesde = const Value.absent(),
    this.pruebaVentana = const Value.absent(),
    this.vozDescanso = const Value.absent(),
    this.avisoVistoEn = const Value.absent(),
    required DateTime modificadoEn,
    this.rowid = const Value.absent(),
  }) : personaId = Value(personaId),
       modificadoEn = Value(modificadoEn);
  static Insertable<GimPerfilFila> custom({
    Expression<String>? personaId,
    Expression<int>? diasPlan,
    Expression<String>? versionPref,
    Expression<String>? ventana,
    Expression<String>? nocheDesde,
    Expression<String>? objetivo,
    Expression<String>? nivel,
    Expression<String>? inicioCiclo,
    Expression<int>? cicloSemanas,
    Expression<int>? descansoS,
    Expression<int>? margenDormirMin,
    Expression<String>? pruebaDesde,
    Expression<String>? pruebaVentana,
    Expression<bool>? vozDescanso,
    Expression<DateTime>? avisoVistoEn,
    Expression<DateTime>? modificadoEn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (personaId != null) 'persona_id': personaId,
      if (diasPlan != null) 'dias_plan': diasPlan,
      if (versionPref != null) 'version_pref': versionPref,
      if (ventana != null) 'ventana': ventana,
      if (nocheDesde != null) 'noche_desde': nocheDesde,
      if (objetivo != null) 'objetivo': objetivo,
      if (nivel != null) 'nivel': nivel,
      if (inicioCiclo != null) 'inicio_ciclo': inicioCiclo,
      if (cicloSemanas != null) 'ciclo_semanas': cicloSemanas,
      if (descansoS != null) 'descanso_s': descansoS,
      if (margenDormirMin != null) 'margen_dormir_min': margenDormirMin,
      if (pruebaDesde != null) 'prueba_desde': pruebaDesde,
      if (pruebaVentana != null) 'prueba_ventana': pruebaVentana,
      if (vozDescanso != null) 'voz_descanso': vozDescanso,
      if (avisoVistoEn != null) 'aviso_visto_en': avisoVistoEn,
      if (modificadoEn != null) 'modificado_en': modificadoEn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GimPerfilCompanion copyWith({
    Value<String>? personaId,
    Value<int>? diasPlan,
    Value<String>? versionPref,
    Value<String>? ventana,
    Value<String>? nocheDesde,
    Value<String>? objetivo,
    Value<String>? nivel,
    Value<String?>? inicioCiclo,
    Value<int>? cicloSemanas,
    Value<int?>? descansoS,
    Value<int>? margenDormirMin,
    Value<String?>? pruebaDesde,
    Value<String?>? pruebaVentana,
    Value<bool>? vozDescanso,
    Value<DateTime?>? avisoVistoEn,
    Value<DateTime>? modificadoEn,
    Value<int>? rowid,
  }) {
    return GimPerfilCompanion(
      personaId: personaId ?? this.personaId,
      diasPlan: diasPlan ?? this.diasPlan,
      versionPref: versionPref ?? this.versionPref,
      ventana: ventana ?? this.ventana,
      nocheDesde: nocheDesde ?? this.nocheDesde,
      objetivo: objetivo ?? this.objetivo,
      nivel: nivel ?? this.nivel,
      inicioCiclo: inicioCiclo ?? this.inicioCiclo,
      cicloSemanas: cicloSemanas ?? this.cicloSemanas,
      descansoS: descansoS ?? this.descansoS,
      margenDormirMin: margenDormirMin ?? this.margenDormirMin,
      pruebaDesde: pruebaDesde ?? this.pruebaDesde,
      pruebaVentana: pruebaVentana ?? this.pruebaVentana,
      vozDescanso: vozDescanso ?? this.vozDescanso,
      avisoVistoEn: avisoVistoEn ?? this.avisoVistoEn,
      modificadoEn: modificadoEn ?? this.modificadoEn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (personaId.present) {
      map['persona_id'] = Variable<String>(personaId.value);
    }
    if (diasPlan.present) {
      map['dias_plan'] = Variable<int>(diasPlan.value);
    }
    if (versionPref.present) {
      map['version_pref'] = Variable<String>(versionPref.value);
    }
    if (ventana.present) {
      map['ventana'] = Variable<String>(ventana.value);
    }
    if (nocheDesde.present) {
      map['noche_desde'] = Variable<String>(nocheDesde.value);
    }
    if (objetivo.present) {
      map['objetivo'] = Variable<String>(objetivo.value);
    }
    if (nivel.present) {
      map['nivel'] = Variable<String>(nivel.value);
    }
    if (inicioCiclo.present) {
      map['inicio_ciclo'] = Variable<String>(inicioCiclo.value);
    }
    if (cicloSemanas.present) {
      map['ciclo_semanas'] = Variable<int>(cicloSemanas.value);
    }
    if (descansoS.present) {
      map['descanso_s'] = Variable<int>(descansoS.value);
    }
    if (margenDormirMin.present) {
      map['margen_dormir_min'] = Variable<int>(margenDormirMin.value);
    }
    if (pruebaDesde.present) {
      map['prueba_desde'] = Variable<String>(pruebaDesde.value);
    }
    if (pruebaVentana.present) {
      map['prueba_ventana'] = Variable<String>(pruebaVentana.value);
    }
    if (vozDescanso.present) {
      map['voz_descanso'] = Variable<bool>(vozDescanso.value);
    }
    if (avisoVistoEn.present) {
      map['aviso_visto_en'] = Variable<DateTime>(avisoVistoEn.value);
    }
    if (modificadoEn.present) {
      map['modificado_en'] = Variable<DateTime>(modificadoEn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GimPerfilCompanion(')
          ..write('personaId: $personaId, ')
          ..write('diasPlan: $diasPlan, ')
          ..write('versionPref: $versionPref, ')
          ..write('ventana: $ventana, ')
          ..write('nocheDesde: $nocheDesde, ')
          ..write('objetivo: $objetivo, ')
          ..write('nivel: $nivel, ')
          ..write('inicioCiclo: $inicioCiclo, ')
          ..write('cicloSemanas: $cicloSemanas, ')
          ..write('descansoS: $descansoS, ')
          ..write('margenDormirMin: $margenDormirMin, ')
          ..write('pruebaDesde: $pruebaDesde, ')
          ..write('pruebaVentana: $pruebaVentana, ')
          ..write('vozDescanso: $vozDescanso, ')
          ..write('avisoVistoEn: $avisoVistoEn, ')
          ..write('modificadoEn: $modificadoEn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GimPlanDiasTable extends GimPlanDias
    with TableInfo<$GimPlanDiasTable, GimPlanDiaFila> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GimPlanDiasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _personaIdMeta = const VerificationMeta(
    'personaId',
  );
  @override
  late final GeneratedColumn<String> personaId = GeneratedColumn<String>(
    'persona_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diaSemanaMeta = const VerificationMeta(
    'diaSemana',
  );
  @override
  late final GeneratedColumn<int> diaSemana = GeneratedColumn<int>(
    'dia_semana',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('auto'),
  );
  static const VerificationMeta _horaMeta = const VerificationMeta('hora');
  @override
  late final GeneratedColumn<String> hora = GeneratedColumn<String>(
    'hora',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modificadoEnMeta = const VerificationMeta(
    'modificadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> modificadoEn = GeneratedColumn<DateTime>(
    'modificado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    personaId,
    diaSemana,
    tipo,
    version,
    hora,
    modificadoEn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gim_plan_dias';
  @override
  VerificationContext validateIntegrity(
    Insertable<GimPlanDiaFila> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('persona_id')) {
      context.handle(
        _personaIdMeta,
        personaId.isAcceptableOrUnknown(data['persona_id']!, _personaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personaIdMeta);
    }
    if (data.containsKey('dia_semana')) {
      context.handle(
        _diaSemanaMeta,
        diaSemana.isAcceptableOrUnknown(data['dia_semana']!, _diaSemanaMeta),
      );
    } else if (isInserting) {
      context.missing(_diaSemanaMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
        _tipoMeta,
        tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('hora')) {
      context.handle(
        _horaMeta,
        hora.isAcceptableOrUnknown(data['hora']!, _horaMeta),
      );
    }
    if (data.containsKey('modificado_en')) {
      context.handle(
        _modificadoEnMeta,
        modificadoEn.isAcceptableOrUnknown(
          data['modificado_en']!,
          _modificadoEnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modificadoEnMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {personaId, diaSemana};
  @override
  GimPlanDiaFila map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GimPlanDiaFila(
      personaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona_id'],
      )!,
      diaSemana: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dia_semana'],
      )!,
      tipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      hora: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hora'],
      ),
      modificadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modificado_en'],
      )!,
    );
  }

  @override
  $GimPlanDiasTable createAlias(String alias) {
    return $GimPlanDiasTable(attachedDatabase, alias);
  }
}

class GimPlanDiaFila extends DataClass implements Insertable<GimPlanDiaFila> {
  final String personaId;
  final int diaSemana;
  final String tipo;
  final String version;
  final String? hora;
  final DateTime modificadoEn;
  const GimPlanDiaFila({
    required this.personaId,
    required this.diaSemana,
    required this.tipo,
    required this.version,
    this.hora,
    required this.modificadoEn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['persona_id'] = Variable<String>(personaId);
    map['dia_semana'] = Variable<int>(diaSemana);
    map['tipo'] = Variable<String>(tipo);
    map['version'] = Variable<String>(version);
    if (!nullToAbsent || hora != null) {
      map['hora'] = Variable<String>(hora);
    }
    map['modificado_en'] = Variable<DateTime>(modificadoEn);
    return map;
  }

  GimPlanDiasCompanion toCompanion(bool nullToAbsent) {
    return GimPlanDiasCompanion(
      personaId: Value(personaId),
      diaSemana: Value(diaSemana),
      tipo: Value(tipo),
      version: Value(version),
      hora: hora == null && nullToAbsent ? const Value.absent() : Value(hora),
      modificadoEn: Value(modificadoEn),
    );
  }

  factory GimPlanDiaFila.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GimPlanDiaFila(
      personaId: serializer.fromJson<String>(json['personaId']),
      diaSemana: serializer.fromJson<int>(json['diaSemana']),
      tipo: serializer.fromJson<String>(json['tipo']),
      version: serializer.fromJson<String>(json['version']),
      hora: serializer.fromJson<String?>(json['hora']),
      modificadoEn: serializer.fromJson<DateTime>(json['modificadoEn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'personaId': serializer.toJson<String>(personaId),
      'diaSemana': serializer.toJson<int>(diaSemana),
      'tipo': serializer.toJson<String>(tipo),
      'version': serializer.toJson<String>(version),
      'hora': serializer.toJson<String?>(hora),
      'modificadoEn': serializer.toJson<DateTime>(modificadoEn),
    };
  }

  GimPlanDiaFila copyWith({
    String? personaId,
    int? diaSemana,
    String? tipo,
    String? version,
    Value<String?> hora = const Value.absent(),
    DateTime? modificadoEn,
  }) => GimPlanDiaFila(
    personaId: personaId ?? this.personaId,
    diaSemana: diaSemana ?? this.diaSemana,
    tipo: tipo ?? this.tipo,
    version: version ?? this.version,
    hora: hora.present ? hora.value : this.hora,
    modificadoEn: modificadoEn ?? this.modificadoEn,
  );
  GimPlanDiaFila copyWithCompanion(GimPlanDiasCompanion data) {
    return GimPlanDiaFila(
      personaId: data.personaId.present ? data.personaId.value : this.personaId,
      diaSemana: data.diaSemana.present ? data.diaSemana.value : this.diaSemana,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      version: data.version.present ? data.version.value : this.version,
      hora: data.hora.present ? data.hora.value : this.hora,
      modificadoEn: data.modificadoEn.present
          ? data.modificadoEn.value
          : this.modificadoEn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GimPlanDiaFila(')
          ..write('personaId: $personaId, ')
          ..write('diaSemana: $diaSemana, ')
          ..write('tipo: $tipo, ')
          ..write('version: $version, ')
          ..write('hora: $hora, ')
          ..write('modificadoEn: $modificadoEn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(personaId, diaSemana, tipo, version, hora, modificadoEn);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GimPlanDiaFila &&
          other.personaId == this.personaId &&
          other.diaSemana == this.diaSemana &&
          other.tipo == this.tipo &&
          other.version == this.version &&
          other.hora == this.hora &&
          other.modificadoEn == this.modificadoEn);
}

class GimPlanDiasCompanion extends UpdateCompanion<GimPlanDiaFila> {
  final Value<String> personaId;
  final Value<int> diaSemana;
  final Value<String> tipo;
  final Value<String> version;
  final Value<String?> hora;
  final Value<DateTime> modificadoEn;
  final Value<int> rowid;
  const GimPlanDiasCompanion({
    this.personaId = const Value.absent(),
    this.diaSemana = const Value.absent(),
    this.tipo = const Value.absent(),
    this.version = const Value.absent(),
    this.hora = const Value.absent(),
    this.modificadoEn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GimPlanDiasCompanion.insert({
    required String personaId,
    required int diaSemana,
    required String tipo,
    this.version = const Value.absent(),
    this.hora = const Value.absent(),
    required DateTime modificadoEn,
    this.rowid = const Value.absent(),
  }) : personaId = Value(personaId),
       diaSemana = Value(diaSemana),
       tipo = Value(tipo),
       modificadoEn = Value(modificadoEn);
  static Insertable<GimPlanDiaFila> custom({
    Expression<String>? personaId,
    Expression<int>? diaSemana,
    Expression<String>? tipo,
    Expression<String>? version,
    Expression<String>? hora,
    Expression<DateTime>? modificadoEn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (personaId != null) 'persona_id': personaId,
      if (diaSemana != null) 'dia_semana': diaSemana,
      if (tipo != null) 'tipo': tipo,
      if (version != null) 'version': version,
      if (hora != null) 'hora': hora,
      if (modificadoEn != null) 'modificado_en': modificadoEn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GimPlanDiasCompanion copyWith({
    Value<String>? personaId,
    Value<int>? diaSemana,
    Value<String>? tipo,
    Value<String>? version,
    Value<String?>? hora,
    Value<DateTime>? modificadoEn,
    Value<int>? rowid,
  }) {
    return GimPlanDiasCompanion(
      personaId: personaId ?? this.personaId,
      diaSemana: diaSemana ?? this.diaSemana,
      tipo: tipo ?? this.tipo,
      version: version ?? this.version,
      hora: hora ?? this.hora,
      modificadoEn: modificadoEn ?? this.modificadoEn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (personaId.present) {
      map['persona_id'] = Variable<String>(personaId.value);
    }
    if (diaSemana.present) {
      map['dia_semana'] = Variable<int>(diaSemana.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (hora.present) {
      map['hora'] = Variable<String>(hora.value);
    }
    if (modificadoEn.present) {
      map['modificado_en'] = Variable<DateTime>(modificadoEn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GimPlanDiasCompanion(')
          ..write('personaId: $personaId, ')
          ..write('diaSemana: $diaSemana, ')
          ..write('tipo: $tipo, ')
          ..write('version: $version, ')
          ..write('hora: $hora, ')
          ..write('modificadoEn: $modificadoEn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GimInventarioTable extends GimInventario
    with TableInfo<$GimInventarioTable, GimInventarioFila> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GimInventarioTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _personaIdMeta = const VerificationMeta(
    'personaId',
  );
  @override
  late final GeneratedColumn<String> personaId = GeneratedColumn<String>(
    'persona_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _estadoMeta = const VerificationMeta('estado');
  @override
  late final GeneratedColumn<String> estado = GeneratedColumn<String>(
    'estado',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmadoMeta = const VerificationMeta(
    'confirmado',
  );
  @override
  late final GeneratedColumn<String> confirmado = GeneratedColumn<String>(
    'confirmado',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _notasMeta = const VerificationMeta('notas');
  @override
  late final GeneratedColumn<String> notas = GeneratedColumn<String>(
    'notas',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modificadoEnMeta = const VerificationMeta(
    'modificadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> modificadoEn = GeneratedColumn<DateTime>(
    'modificado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    personaId,
    itemId,
    estado,
    confirmado,
    notas,
    modificadoEn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gim_inventario';
  @override
  VerificationContext validateIntegrity(
    Insertable<GimInventarioFila> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('persona_id')) {
      context.handle(
        _personaIdMeta,
        personaId.isAcceptableOrUnknown(data['persona_id']!, _personaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personaIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('estado')) {
      context.handle(
        _estadoMeta,
        estado.isAcceptableOrUnknown(data['estado']!, _estadoMeta),
      );
    } else if (isInserting) {
      context.missing(_estadoMeta);
    }
    if (data.containsKey('confirmado')) {
      context.handle(
        _confirmadoMeta,
        confirmado.isAcceptableOrUnknown(data['confirmado']!, _confirmadoMeta),
      );
    }
    if (data.containsKey('notas')) {
      context.handle(
        _notasMeta,
        notas.isAcceptableOrUnknown(data['notas']!, _notasMeta),
      );
    }
    if (data.containsKey('modificado_en')) {
      context.handle(
        _modificadoEnMeta,
        modificadoEn.isAcceptableOrUnknown(
          data['modificado_en']!,
          _modificadoEnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modificadoEnMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {personaId, itemId};
  @override
  GimInventarioFila map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GimInventarioFila(
      personaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      estado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estado'],
      )!,
      confirmado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmado'],
      )!,
      notas: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notas'],
      ),
      modificadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modificado_en'],
      )!,
    );
  }

  @override
  $GimInventarioTable createAlias(String alias) {
    return $GimInventarioTable(attachedDatabase, alias);
  }
}

class GimInventarioFila extends DataClass
    implements Insertable<GimInventarioFila> {
  final String personaId;
  final String itemId;
  final String estado;

  /// Datos del aparato confirmados (JSON): pasos de la pila, kg por paso…
  final String confirmado;
  final String? notas;
  final DateTime modificadoEn;
  const GimInventarioFila({
    required this.personaId,
    required this.itemId,
    required this.estado,
    required this.confirmado,
    this.notas,
    required this.modificadoEn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['persona_id'] = Variable<String>(personaId);
    map['item_id'] = Variable<String>(itemId);
    map['estado'] = Variable<String>(estado);
    map['confirmado'] = Variable<String>(confirmado);
    if (!nullToAbsent || notas != null) {
      map['notas'] = Variable<String>(notas);
    }
    map['modificado_en'] = Variable<DateTime>(modificadoEn);
    return map;
  }

  GimInventarioCompanion toCompanion(bool nullToAbsent) {
    return GimInventarioCompanion(
      personaId: Value(personaId),
      itemId: Value(itemId),
      estado: Value(estado),
      confirmado: Value(confirmado),
      notas: notas == null && nullToAbsent
          ? const Value.absent()
          : Value(notas),
      modificadoEn: Value(modificadoEn),
    );
  }

  factory GimInventarioFila.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GimInventarioFila(
      personaId: serializer.fromJson<String>(json['personaId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      estado: serializer.fromJson<String>(json['estado']),
      confirmado: serializer.fromJson<String>(json['confirmado']),
      notas: serializer.fromJson<String?>(json['notas']),
      modificadoEn: serializer.fromJson<DateTime>(json['modificadoEn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'personaId': serializer.toJson<String>(personaId),
      'itemId': serializer.toJson<String>(itemId),
      'estado': serializer.toJson<String>(estado),
      'confirmado': serializer.toJson<String>(confirmado),
      'notas': serializer.toJson<String?>(notas),
      'modificadoEn': serializer.toJson<DateTime>(modificadoEn),
    };
  }

  GimInventarioFila copyWith({
    String? personaId,
    String? itemId,
    String? estado,
    String? confirmado,
    Value<String?> notas = const Value.absent(),
    DateTime? modificadoEn,
  }) => GimInventarioFila(
    personaId: personaId ?? this.personaId,
    itemId: itemId ?? this.itemId,
    estado: estado ?? this.estado,
    confirmado: confirmado ?? this.confirmado,
    notas: notas.present ? notas.value : this.notas,
    modificadoEn: modificadoEn ?? this.modificadoEn,
  );
  GimInventarioFila copyWithCompanion(GimInventarioCompanion data) {
    return GimInventarioFila(
      personaId: data.personaId.present ? data.personaId.value : this.personaId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      estado: data.estado.present ? data.estado.value : this.estado,
      confirmado: data.confirmado.present
          ? data.confirmado.value
          : this.confirmado,
      notas: data.notas.present ? data.notas.value : this.notas,
      modificadoEn: data.modificadoEn.present
          ? data.modificadoEn.value
          : this.modificadoEn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GimInventarioFila(')
          ..write('personaId: $personaId, ')
          ..write('itemId: $itemId, ')
          ..write('estado: $estado, ')
          ..write('confirmado: $confirmado, ')
          ..write('notas: $notas, ')
          ..write('modificadoEn: $modificadoEn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(personaId, itemId, estado, confirmado, notas, modificadoEn);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GimInventarioFila &&
          other.personaId == this.personaId &&
          other.itemId == this.itemId &&
          other.estado == this.estado &&
          other.confirmado == this.confirmado &&
          other.notas == this.notas &&
          other.modificadoEn == this.modificadoEn);
}

class GimInventarioCompanion extends UpdateCompanion<GimInventarioFila> {
  final Value<String> personaId;
  final Value<String> itemId;
  final Value<String> estado;
  final Value<String> confirmado;
  final Value<String?> notas;
  final Value<DateTime> modificadoEn;
  final Value<int> rowid;
  const GimInventarioCompanion({
    this.personaId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.estado = const Value.absent(),
    this.confirmado = const Value.absent(),
    this.notas = const Value.absent(),
    this.modificadoEn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GimInventarioCompanion.insert({
    required String personaId,
    required String itemId,
    required String estado,
    this.confirmado = const Value.absent(),
    this.notas = const Value.absent(),
    required DateTime modificadoEn,
    this.rowid = const Value.absent(),
  }) : personaId = Value(personaId),
       itemId = Value(itemId),
       estado = Value(estado),
       modificadoEn = Value(modificadoEn);
  static Insertable<GimInventarioFila> custom({
    Expression<String>? personaId,
    Expression<String>? itemId,
    Expression<String>? estado,
    Expression<String>? confirmado,
    Expression<String>? notas,
    Expression<DateTime>? modificadoEn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (personaId != null) 'persona_id': personaId,
      if (itemId != null) 'item_id': itemId,
      if (estado != null) 'estado': estado,
      if (confirmado != null) 'confirmado': confirmado,
      if (notas != null) 'notas': notas,
      if (modificadoEn != null) 'modificado_en': modificadoEn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GimInventarioCompanion copyWith({
    Value<String>? personaId,
    Value<String>? itemId,
    Value<String>? estado,
    Value<String>? confirmado,
    Value<String?>? notas,
    Value<DateTime>? modificadoEn,
    Value<int>? rowid,
  }) {
    return GimInventarioCompanion(
      personaId: personaId ?? this.personaId,
      itemId: itemId ?? this.itemId,
      estado: estado ?? this.estado,
      confirmado: confirmado ?? this.confirmado,
      notas: notas ?? this.notas,
      modificadoEn: modificadoEn ?? this.modificadoEn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (personaId.present) {
      map['persona_id'] = Variable<String>(personaId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (estado.present) {
      map['estado'] = Variable<String>(estado.value);
    }
    if (confirmado.present) {
      map['confirmado'] = Variable<String>(confirmado.value);
    }
    if (notas.present) {
      map['notas'] = Variable<String>(notas.value);
    }
    if (modificadoEn.present) {
      map['modificado_en'] = Variable<DateTime>(modificadoEn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GimInventarioCompanion(')
          ..write('personaId: $personaId, ')
          ..write('itemId: $itemId, ')
          ..write('estado: $estado, ')
          ..write('confirmado: $confirmado, ')
          ..write('notas: $notas, ')
          ..write('modificadoEn: $modificadoEn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GimBandasTable extends GimBandas
    with TableInfo<$GimBandasTable, GimBandaFila> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GimBandasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personaIdMeta = const VerificationMeta(
    'personaId',
  );
  @override
  late final GeneratedColumn<String> personaId = GeneratedColumn<String>(
    'persona_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordenMeta = const VerificationMeta('orden');
  @override
  late final GeneratedColumn<int> orden = GeneratedColumn<int>(
    'orden',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resistenciaKgX10Meta = const VerificationMeta(
    'resistenciaKgX10',
  );
  @override
  late final GeneratedColumn<int> resistenciaKgX10 = GeneratedColumn<int>(
    'resistencia_kg_x10',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cantidadMeta = const VerificationMeta(
    'cantidad',
  );
  @override
  late final GeneratedColumn<int> cantidad = GeneratedColumn<int>(
    'cantidad',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activaMeta = const VerificationMeta('activa');
  @override
  late final GeneratedColumn<bool> activa = GeneratedColumn<bool>(
    'activa',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("activa" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _modificadoEnMeta = const VerificationMeta(
    'modificadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> modificadoEn = GeneratedColumn<DateTime>(
    'modificado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    personaId,
    nombre,
    orden,
    resistenciaKgX10,
    cantidad,
    activa,
    modificadoEn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gim_bandas';
  @override
  VerificationContext validateIntegrity(
    Insertable<GimBandaFila> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('persona_id')) {
      context.handle(
        _personaIdMeta,
        personaId.isAcceptableOrUnknown(data['persona_id']!, _personaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personaIdMeta);
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('orden')) {
      context.handle(
        _ordenMeta,
        orden.isAcceptableOrUnknown(data['orden']!, _ordenMeta),
      );
    } else if (isInserting) {
      context.missing(_ordenMeta);
    }
    if (data.containsKey('resistencia_kg_x10')) {
      context.handle(
        _resistenciaKgX10Meta,
        resistenciaKgX10.isAcceptableOrUnknown(
          data['resistencia_kg_x10']!,
          _resistenciaKgX10Meta,
        ),
      );
    }
    if (data.containsKey('cantidad')) {
      context.handle(
        _cantidadMeta,
        cantidad.isAcceptableOrUnknown(data['cantidad']!, _cantidadMeta),
      );
    } else if (isInserting) {
      context.missing(_cantidadMeta);
    }
    if (data.containsKey('activa')) {
      context.handle(
        _activaMeta,
        activa.isAcceptableOrUnknown(data['activa']!, _activaMeta),
      );
    }
    if (data.containsKey('modificado_en')) {
      context.handle(
        _modificadoEnMeta,
        modificadoEn.isAcceptableOrUnknown(
          data['modificado_en']!,
          _modificadoEnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modificadoEnMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GimBandaFila map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GimBandaFila(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      personaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona_id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      orden: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}orden'],
      )!,
      resistenciaKgX10: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resistencia_kg_x10'],
      ),
      cantidad: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cantidad'],
      )!,
      activa: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}activa'],
      )!,
      modificadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modificado_en'],
      )!,
    );
  }

  @override
  $GimBandasTable createAlias(String alias) {
    return $GimBandasTable(attachedDatabase, alias);
  }
}

class GimBandaFila extends DataClass implements Insertable<GimBandaFila> {
  final String id;
  final String personaId;
  final String nombre;
  final int orden;
  final int? resistenciaKgX10;
  final int cantidad;
  final bool activa;
  final DateTime modificadoEn;
  const GimBandaFila({
    required this.id,
    required this.personaId,
    required this.nombre,
    required this.orden,
    this.resistenciaKgX10,
    required this.cantidad,
    required this.activa,
    required this.modificadoEn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['persona_id'] = Variable<String>(personaId);
    map['nombre'] = Variable<String>(nombre);
    map['orden'] = Variable<int>(orden);
    if (!nullToAbsent || resistenciaKgX10 != null) {
      map['resistencia_kg_x10'] = Variable<int>(resistenciaKgX10);
    }
    map['cantidad'] = Variable<int>(cantidad);
    map['activa'] = Variable<bool>(activa);
    map['modificado_en'] = Variable<DateTime>(modificadoEn);
    return map;
  }

  GimBandasCompanion toCompanion(bool nullToAbsent) {
    return GimBandasCompanion(
      id: Value(id),
      personaId: Value(personaId),
      nombre: Value(nombre),
      orden: Value(orden),
      resistenciaKgX10: resistenciaKgX10 == null && nullToAbsent
          ? const Value.absent()
          : Value(resistenciaKgX10),
      cantidad: Value(cantidad),
      activa: Value(activa),
      modificadoEn: Value(modificadoEn),
    );
  }

  factory GimBandaFila.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GimBandaFila(
      id: serializer.fromJson<String>(json['id']),
      personaId: serializer.fromJson<String>(json['personaId']),
      nombre: serializer.fromJson<String>(json['nombre']),
      orden: serializer.fromJson<int>(json['orden']),
      resistenciaKgX10: serializer.fromJson<int?>(json['resistenciaKgX10']),
      cantidad: serializer.fromJson<int>(json['cantidad']),
      activa: serializer.fromJson<bool>(json['activa']),
      modificadoEn: serializer.fromJson<DateTime>(json['modificadoEn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'personaId': serializer.toJson<String>(personaId),
      'nombre': serializer.toJson<String>(nombre),
      'orden': serializer.toJson<int>(orden),
      'resistenciaKgX10': serializer.toJson<int?>(resistenciaKgX10),
      'cantidad': serializer.toJson<int>(cantidad),
      'activa': serializer.toJson<bool>(activa),
      'modificadoEn': serializer.toJson<DateTime>(modificadoEn),
    };
  }

  GimBandaFila copyWith({
    String? id,
    String? personaId,
    String? nombre,
    int? orden,
    Value<int?> resistenciaKgX10 = const Value.absent(),
    int? cantidad,
    bool? activa,
    DateTime? modificadoEn,
  }) => GimBandaFila(
    id: id ?? this.id,
    personaId: personaId ?? this.personaId,
    nombre: nombre ?? this.nombre,
    orden: orden ?? this.orden,
    resistenciaKgX10: resistenciaKgX10.present
        ? resistenciaKgX10.value
        : this.resistenciaKgX10,
    cantidad: cantidad ?? this.cantidad,
    activa: activa ?? this.activa,
    modificadoEn: modificadoEn ?? this.modificadoEn,
  );
  GimBandaFila copyWithCompanion(GimBandasCompanion data) {
    return GimBandaFila(
      id: data.id.present ? data.id.value : this.id,
      personaId: data.personaId.present ? data.personaId.value : this.personaId,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      orden: data.orden.present ? data.orden.value : this.orden,
      resistenciaKgX10: data.resistenciaKgX10.present
          ? data.resistenciaKgX10.value
          : this.resistenciaKgX10,
      cantidad: data.cantidad.present ? data.cantidad.value : this.cantidad,
      activa: data.activa.present ? data.activa.value : this.activa,
      modificadoEn: data.modificadoEn.present
          ? data.modificadoEn.value
          : this.modificadoEn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GimBandaFila(')
          ..write('id: $id, ')
          ..write('personaId: $personaId, ')
          ..write('nombre: $nombre, ')
          ..write('orden: $orden, ')
          ..write('resistenciaKgX10: $resistenciaKgX10, ')
          ..write('cantidad: $cantidad, ')
          ..write('activa: $activa, ')
          ..write('modificadoEn: $modificadoEn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    personaId,
    nombre,
    orden,
    resistenciaKgX10,
    cantidad,
    activa,
    modificadoEn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GimBandaFila &&
          other.id == this.id &&
          other.personaId == this.personaId &&
          other.nombre == this.nombre &&
          other.orden == this.orden &&
          other.resistenciaKgX10 == this.resistenciaKgX10 &&
          other.cantidad == this.cantidad &&
          other.activa == this.activa &&
          other.modificadoEn == this.modificadoEn);
}

class GimBandasCompanion extends UpdateCompanion<GimBandaFila> {
  final Value<String> id;
  final Value<String> personaId;
  final Value<String> nombre;
  final Value<int> orden;
  final Value<int?> resistenciaKgX10;
  final Value<int> cantidad;
  final Value<bool> activa;
  final Value<DateTime> modificadoEn;
  final Value<int> rowid;
  const GimBandasCompanion({
    this.id = const Value.absent(),
    this.personaId = const Value.absent(),
    this.nombre = const Value.absent(),
    this.orden = const Value.absent(),
    this.resistenciaKgX10 = const Value.absent(),
    this.cantidad = const Value.absent(),
    this.activa = const Value.absent(),
    this.modificadoEn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GimBandasCompanion.insert({
    required String id,
    required String personaId,
    required String nombre,
    required int orden,
    this.resistenciaKgX10 = const Value.absent(),
    required int cantidad,
    this.activa = const Value.absent(),
    required DateTime modificadoEn,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       personaId = Value(personaId),
       nombre = Value(nombre),
       orden = Value(orden),
       cantidad = Value(cantidad),
       modificadoEn = Value(modificadoEn);
  static Insertable<GimBandaFila> custom({
    Expression<String>? id,
    Expression<String>? personaId,
    Expression<String>? nombre,
    Expression<int>? orden,
    Expression<int>? resistenciaKgX10,
    Expression<int>? cantidad,
    Expression<bool>? activa,
    Expression<DateTime>? modificadoEn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personaId != null) 'persona_id': personaId,
      if (nombre != null) 'nombre': nombre,
      if (orden != null) 'orden': orden,
      if (resistenciaKgX10 != null) 'resistencia_kg_x10': resistenciaKgX10,
      if (cantidad != null) 'cantidad': cantidad,
      if (activa != null) 'activa': activa,
      if (modificadoEn != null) 'modificado_en': modificadoEn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GimBandasCompanion copyWith({
    Value<String>? id,
    Value<String>? personaId,
    Value<String>? nombre,
    Value<int>? orden,
    Value<int?>? resistenciaKgX10,
    Value<int>? cantidad,
    Value<bool>? activa,
    Value<DateTime>? modificadoEn,
    Value<int>? rowid,
  }) {
    return GimBandasCompanion(
      id: id ?? this.id,
      personaId: personaId ?? this.personaId,
      nombre: nombre ?? this.nombre,
      orden: orden ?? this.orden,
      resistenciaKgX10: resistenciaKgX10 ?? this.resistenciaKgX10,
      cantidad: cantidad ?? this.cantidad,
      activa: activa ?? this.activa,
      modificadoEn: modificadoEn ?? this.modificadoEn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (personaId.present) {
      map['persona_id'] = Variable<String>(personaId.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (orden.present) {
      map['orden'] = Variable<int>(orden.value);
    }
    if (resistenciaKgX10.present) {
      map['resistencia_kg_x10'] = Variable<int>(resistenciaKgX10.value);
    }
    if (cantidad.present) {
      map['cantidad'] = Variable<int>(cantidad.value);
    }
    if (activa.present) {
      map['activa'] = Variable<bool>(activa.value);
    }
    if (modificadoEn.present) {
      map['modificado_en'] = Variable<DateTime>(modificadoEn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GimBandasCompanion(')
          ..write('id: $id, ')
          ..write('personaId: $personaId, ')
          ..write('nombre: $nombre, ')
          ..write('orden: $orden, ')
          ..write('resistenciaKgX10: $resistenciaKgX10, ')
          ..write('cantidad: $cantidad, ')
          ..write('activa: $activa, ')
          ..write('modificadoEn: $modificadoEn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GimSesionesTable extends GimSesiones
    with TableInfo<$GimSesionesTable, GimSesionFila> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GimSesionesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personaIdMeta = const VerificationMeta(
    'personaId',
  );
  @override
  late final GeneratedColumn<String> personaId = GeneratedColumn<String>(
    'persona_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<String> fecha = GeneratedColumn<String>(
    'fecha',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plantillaMeta = const VerificationMeta(
    'plantilla',
  );
  @override
  late final GeneratedColumn<String> plantilla = GeneratedColumn<String>(
    'plantilla',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _semanaTipoMeta = const VerificationMeta(
    'semanaTipo',
  );
  @override
  late final GeneratedColumn<String> semanaTipo = GeneratedColumn<String>(
    'semana_tipo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ventanaMeta = const VerificationMeta(
    'ventana',
  );
  @override
  late final GeneratedColumn<String> ventana = GeneratedColumn<String>(
    'ventana',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bloqueIdMeta = const VerificationMeta(
    'bloqueId',
  );
  @override
  late final GeneratedColumn<String> bloqueId = GeneratedColumn<String>(
    'bloque_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inicioMeta = const VerificationMeta('inicio');
  @override
  late final GeneratedColumn<DateTime> inicio = GeneratedColumn<DateTime>(
    'inicio',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finMeta = const VerificationMeta('fin');
  @override
  late final GeneratedColumn<DateTime> fin = GeneratedColumn<DateTime>(
    'fin',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estadoMeta = const VerificationMeta('estado');
  @override
  late final GeneratedColumn<String> estado = GeneratedColumn<String>(
    'estado',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _esfuerzoMeta = const VerificationMeta(
    'esfuerzo',
  );
  @override
  late final GeneratedColumn<int> esfuerzo = GeneratedColumn<int>(
    'esfuerzo',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _energiaMeta = const VerificationMeta(
    'energia',
  );
  @override
  late final GeneratedColumn<int> energia = GeneratedColumn<int>(
    'energia',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _planMeta = const VerificationMeta('plan');
  @override
  late final GeneratedColumn<String> plan = GeneratedColumn<String>(
    'plan',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _catalogoVersionMeta = const VerificationMeta(
    'catalogoVersion',
  );
  @override
  late final GeneratedColumn<int> catalogoVersion = GeneratedColumn<int>(
    'catalogo_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tiemposMeta = const VerificationMeta(
    'tiempos',
  );
  @override
  late final GeneratedColumn<String> tiempos = GeneratedColumn<String>(
    'tiempos',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modificadoEnMeta = const VerificationMeta(
    'modificadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> modificadoEn = GeneratedColumn<DateTime>(
    'modificado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    personaId,
    fecha,
    plantilla,
    version,
    semanaTipo,
    ventana,
    bloqueId,
    inicio,
    fin,
    estado,
    esfuerzo,
    energia,
    plan,
    catalogoVersion,
    tiempos,
    modificadoEn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gim_sesiones';
  @override
  VerificationContext validateIntegrity(
    Insertable<GimSesionFila> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('persona_id')) {
      context.handle(
        _personaIdMeta,
        personaId.isAcceptableOrUnknown(data['persona_id']!, _personaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personaIdMeta);
    }
    if (data.containsKey('fecha')) {
      context.handle(
        _fechaMeta,
        fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaMeta);
    }
    if (data.containsKey('plantilla')) {
      context.handle(
        _plantillaMeta,
        plantilla.isAcceptableOrUnknown(data['plantilla']!, _plantillaMeta),
      );
    } else if (isInserting) {
      context.missing(_plantillaMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('semana_tipo')) {
      context.handle(
        _semanaTipoMeta,
        semanaTipo.isAcceptableOrUnknown(data['semana_tipo']!, _semanaTipoMeta),
      );
    } else if (isInserting) {
      context.missing(_semanaTipoMeta);
    }
    if (data.containsKey('ventana')) {
      context.handle(
        _ventanaMeta,
        ventana.isAcceptableOrUnknown(data['ventana']!, _ventanaMeta),
      );
    } else if (isInserting) {
      context.missing(_ventanaMeta);
    }
    if (data.containsKey('bloque_id')) {
      context.handle(
        _bloqueIdMeta,
        bloqueId.isAcceptableOrUnknown(data['bloque_id']!, _bloqueIdMeta),
      );
    }
    if (data.containsKey('inicio')) {
      context.handle(
        _inicioMeta,
        inicio.isAcceptableOrUnknown(data['inicio']!, _inicioMeta),
      );
    } else if (isInserting) {
      context.missing(_inicioMeta);
    }
    if (data.containsKey('fin')) {
      context.handle(
        _finMeta,
        fin.isAcceptableOrUnknown(data['fin']!, _finMeta),
      );
    }
    if (data.containsKey('estado')) {
      context.handle(
        _estadoMeta,
        estado.isAcceptableOrUnknown(data['estado']!, _estadoMeta),
      );
    } else if (isInserting) {
      context.missing(_estadoMeta);
    }
    if (data.containsKey('esfuerzo')) {
      context.handle(
        _esfuerzoMeta,
        esfuerzo.isAcceptableOrUnknown(data['esfuerzo']!, _esfuerzoMeta),
      );
    }
    if (data.containsKey('energia')) {
      context.handle(
        _energiaMeta,
        energia.isAcceptableOrUnknown(data['energia']!, _energiaMeta),
      );
    }
    if (data.containsKey('plan')) {
      context.handle(
        _planMeta,
        plan.isAcceptableOrUnknown(data['plan']!, _planMeta),
      );
    }
    if (data.containsKey('catalogo_version')) {
      context.handle(
        _catalogoVersionMeta,
        catalogoVersion.isAcceptableOrUnknown(
          data['catalogo_version']!,
          _catalogoVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_catalogoVersionMeta);
    }
    if (data.containsKey('tiempos')) {
      context.handle(
        _tiemposMeta,
        tiempos.isAcceptableOrUnknown(data['tiempos']!, _tiemposMeta),
      );
    }
    if (data.containsKey('modificado_en')) {
      context.handle(
        _modificadoEnMeta,
        modificadoEn.isAcceptableOrUnknown(
          data['modificado_en']!,
          _modificadoEnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modificadoEnMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GimSesionFila map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GimSesionFila(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      personaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona_id'],
      )!,
      fecha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha'],
      )!,
      plantilla: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plantilla'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      semanaTipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semana_tipo'],
      )!,
      ventana: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ventana'],
      )!,
      bloqueId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bloque_id'],
      ),
      inicio: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}inicio'],
      )!,
      fin: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fin'],
      ),
      estado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estado'],
      )!,
      esfuerzo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}esfuerzo'],
      ),
      energia: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}energia'],
      ),
      plan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan'],
      )!,
      catalogoVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}catalogo_version'],
      )!,
      tiempos: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tiempos'],
      ),
      modificadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modificado_en'],
      )!,
    );
  }

  @override
  $GimSesionesTable createAlias(String alias) {
    return $GimSesionesTable(attachedDatabase, alias);
  }
}

class GimSesionFila extends DataClass implements Insertable<GimSesionFila> {
  final String id;
  final String personaId;
  final String fecha;
  final String plantilla;
  final String version;
  final String semanaTipo;
  final String ventana;
  final String? bloqueId;
  final DateTime inicio;
  final DateTime? fin;
  final String estado;
  final int? esfuerzo;
  final int? energia;

  /// Lo planeado (JSON): lista de {ejercicio, variante, series, reps_min,
  /// reps_max}.
  final String plan;
  final int catalogoVersion;

  /// **Solo local** (calibra el tiempo estimado, 5.5): nunca se sube.
  final String? tiempos;
  final DateTime modificadoEn;
  const GimSesionFila({
    required this.id,
    required this.personaId,
    required this.fecha,
    required this.plantilla,
    required this.version,
    required this.semanaTipo,
    required this.ventana,
    this.bloqueId,
    required this.inicio,
    this.fin,
    required this.estado,
    this.esfuerzo,
    this.energia,
    required this.plan,
    required this.catalogoVersion,
    this.tiempos,
    required this.modificadoEn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['persona_id'] = Variable<String>(personaId);
    map['fecha'] = Variable<String>(fecha);
    map['plantilla'] = Variable<String>(plantilla);
    map['version'] = Variable<String>(version);
    map['semana_tipo'] = Variable<String>(semanaTipo);
    map['ventana'] = Variable<String>(ventana);
    if (!nullToAbsent || bloqueId != null) {
      map['bloque_id'] = Variable<String>(bloqueId);
    }
    map['inicio'] = Variable<DateTime>(inicio);
    if (!nullToAbsent || fin != null) {
      map['fin'] = Variable<DateTime>(fin);
    }
    map['estado'] = Variable<String>(estado);
    if (!nullToAbsent || esfuerzo != null) {
      map['esfuerzo'] = Variable<int>(esfuerzo);
    }
    if (!nullToAbsent || energia != null) {
      map['energia'] = Variable<int>(energia);
    }
    map['plan'] = Variable<String>(plan);
    map['catalogo_version'] = Variable<int>(catalogoVersion);
    if (!nullToAbsent || tiempos != null) {
      map['tiempos'] = Variable<String>(tiempos);
    }
    map['modificado_en'] = Variable<DateTime>(modificadoEn);
    return map;
  }

  GimSesionesCompanion toCompanion(bool nullToAbsent) {
    return GimSesionesCompanion(
      id: Value(id),
      personaId: Value(personaId),
      fecha: Value(fecha),
      plantilla: Value(plantilla),
      version: Value(version),
      semanaTipo: Value(semanaTipo),
      ventana: Value(ventana),
      bloqueId: bloqueId == null && nullToAbsent
          ? const Value.absent()
          : Value(bloqueId),
      inicio: Value(inicio),
      fin: fin == null && nullToAbsent ? const Value.absent() : Value(fin),
      estado: Value(estado),
      esfuerzo: esfuerzo == null && nullToAbsent
          ? const Value.absent()
          : Value(esfuerzo),
      energia: energia == null && nullToAbsent
          ? const Value.absent()
          : Value(energia),
      plan: Value(plan),
      catalogoVersion: Value(catalogoVersion),
      tiempos: tiempos == null && nullToAbsent
          ? const Value.absent()
          : Value(tiempos),
      modificadoEn: Value(modificadoEn),
    );
  }

  factory GimSesionFila.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GimSesionFila(
      id: serializer.fromJson<String>(json['id']),
      personaId: serializer.fromJson<String>(json['personaId']),
      fecha: serializer.fromJson<String>(json['fecha']),
      plantilla: serializer.fromJson<String>(json['plantilla']),
      version: serializer.fromJson<String>(json['version']),
      semanaTipo: serializer.fromJson<String>(json['semanaTipo']),
      ventana: serializer.fromJson<String>(json['ventana']),
      bloqueId: serializer.fromJson<String?>(json['bloqueId']),
      inicio: serializer.fromJson<DateTime>(json['inicio']),
      fin: serializer.fromJson<DateTime?>(json['fin']),
      estado: serializer.fromJson<String>(json['estado']),
      esfuerzo: serializer.fromJson<int?>(json['esfuerzo']),
      energia: serializer.fromJson<int?>(json['energia']),
      plan: serializer.fromJson<String>(json['plan']),
      catalogoVersion: serializer.fromJson<int>(json['catalogoVersion']),
      tiempos: serializer.fromJson<String?>(json['tiempos']),
      modificadoEn: serializer.fromJson<DateTime>(json['modificadoEn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'personaId': serializer.toJson<String>(personaId),
      'fecha': serializer.toJson<String>(fecha),
      'plantilla': serializer.toJson<String>(plantilla),
      'version': serializer.toJson<String>(version),
      'semanaTipo': serializer.toJson<String>(semanaTipo),
      'ventana': serializer.toJson<String>(ventana),
      'bloqueId': serializer.toJson<String?>(bloqueId),
      'inicio': serializer.toJson<DateTime>(inicio),
      'fin': serializer.toJson<DateTime?>(fin),
      'estado': serializer.toJson<String>(estado),
      'esfuerzo': serializer.toJson<int?>(esfuerzo),
      'energia': serializer.toJson<int?>(energia),
      'plan': serializer.toJson<String>(plan),
      'catalogoVersion': serializer.toJson<int>(catalogoVersion),
      'tiempos': serializer.toJson<String?>(tiempos),
      'modificadoEn': serializer.toJson<DateTime>(modificadoEn),
    };
  }

  GimSesionFila copyWith({
    String? id,
    String? personaId,
    String? fecha,
    String? plantilla,
    String? version,
    String? semanaTipo,
    String? ventana,
    Value<String?> bloqueId = const Value.absent(),
    DateTime? inicio,
    Value<DateTime?> fin = const Value.absent(),
    String? estado,
    Value<int?> esfuerzo = const Value.absent(),
    Value<int?> energia = const Value.absent(),
    String? plan,
    int? catalogoVersion,
    Value<String?> tiempos = const Value.absent(),
    DateTime? modificadoEn,
  }) => GimSesionFila(
    id: id ?? this.id,
    personaId: personaId ?? this.personaId,
    fecha: fecha ?? this.fecha,
    plantilla: plantilla ?? this.plantilla,
    version: version ?? this.version,
    semanaTipo: semanaTipo ?? this.semanaTipo,
    ventana: ventana ?? this.ventana,
    bloqueId: bloqueId.present ? bloqueId.value : this.bloqueId,
    inicio: inicio ?? this.inicio,
    fin: fin.present ? fin.value : this.fin,
    estado: estado ?? this.estado,
    esfuerzo: esfuerzo.present ? esfuerzo.value : this.esfuerzo,
    energia: energia.present ? energia.value : this.energia,
    plan: plan ?? this.plan,
    catalogoVersion: catalogoVersion ?? this.catalogoVersion,
    tiempos: tiempos.present ? tiempos.value : this.tiempos,
    modificadoEn: modificadoEn ?? this.modificadoEn,
  );
  GimSesionFila copyWithCompanion(GimSesionesCompanion data) {
    return GimSesionFila(
      id: data.id.present ? data.id.value : this.id,
      personaId: data.personaId.present ? data.personaId.value : this.personaId,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
      plantilla: data.plantilla.present ? data.plantilla.value : this.plantilla,
      version: data.version.present ? data.version.value : this.version,
      semanaTipo: data.semanaTipo.present
          ? data.semanaTipo.value
          : this.semanaTipo,
      ventana: data.ventana.present ? data.ventana.value : this.ventana,
      bloqueId: data.bloqueId.present ? data.bloqueId.value : this.bloqueId,
      inicio: data.inicio.present ? data.inicio.value : this.inicio,
      fin: data.fin.present ? data.fin.value : this.fin,
      estado: data.estado.present ? data.estado.value : this.estado,
      esfuerzo: data.esfuerzo.present ? data.esfuerzo.value : this.esfuerzo,
      energia: data.energia.present ? data.energia.value : this.energia,
      plan: data.plan.present ? data.plan.value : this.plan,
      catalogoVersion: data.catalogoVersion.present
          ? data.catalogoVersion.value
          : this.catalogoVersion,
      tiempos: data.tiempos.present ? data.tiempos.value : this.tiempos,
      modificadoEn: data.modificadoEn.present
          ? data.modificadoEn.value
          : this.modificadoEn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GimSesionFila(')
          ..write('id: $id, ')
          ..write('personaId: $personaId, ')
          ..write('fecha: $fecha, ')
          ..write('plantilla: $plantilla, ')
          ..write('version: $version, ')
          ..write('semanaTipo: $semanaTipo, ')
          ..write('ventana: $ventana, ')
          ..write('bloqueId: $bloqueId, ')
          ..write('inicio: $inicio, ')
          ..write('fin: $fin, ')
          ..write('estado: $estado, ')
          ..write('esfuerzo: $esfuerzo, ')
          ..write('energia: $energia, ')
          ..write('plan: $plan, ')
          ..write('catalogoVersion: $catalogoVersion, ')
          ..write('tiempos: $tiempos, ')
          ..write('modificadoEn: $modificadoEn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    personaId,
    fecha,
    plantilla,
    version,
    semanaTipo,
    ventana,
    bloqueId,
    inicio,
    fin,
    estado,
    esfuerzo,
    energia,
    plan,
    catalogoVersion,
    tiempos,
    modificadoEn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GimSesionFila &&
          other.id == this.id &&
          other.personaId == this.personaId &&
          other.fecha == this.fecha &&
          other.plantilla == this.plantilla &&
          other.version == this.version &&
          other.semanaTipo == this.semanaTipo &&
          other.ventana == this.ventana &&
          other.bloqueId == this.bloqueId &&
          other.inicio == this.inicio &&
          other.fin == this.fin &&
          other.estado == this.estado &&
          other.esfuerzo == this.esfuerzo &&
          other.energia == this.energia &&
          other.plan == this.plan &&
          other.catalogoVersion == this.catalogoVersion &&
          other.tiempos == this.tiempos &&
          other.modificadoEn == this.modificadoEn);
}

class GimSesionesCompanion extends UpdateCompanion<GimSesionFila> {
  final Value<String> id;
  final Value<String> personaId;
  final Value<String> fecha;
  final Value<String> plantilla;
  final Value<String> version;
  final Value<String> semanaTipo;
  final Value<String> ventana;
  final Value<String?> bloqueId;
  final Value<DateTime> inicio;
  final Value<DateTime?> fin;
  final Value<String> estado;
  final Value<int?> esfuerzo;
  final Value<int?> energia;
  final Value<String> plan;
  final Value<int> catalogoVersion;
  final Value<String?> tiempos;
  final Value<DateTime> modificadoEn;
  final Value<int> rowid;
  const GimSesionesCompanion({
    this.id = const Value.absent(),
    this.personaId = const Value.absent(),
    this.fecha = const Value.absent(),
    this.plantilla = const Value.absent(),
    this.version = const Value.absent(),
    this.semanaTipo = const Value.absent(),
    this.ventana = const Value.absent(),
    this.bloqueId = const Value.absent(),
    this.inicio = const Value.absent(),
    this.fin = const Value.absent(),
    this.estado = const Value.absent(),
    this.esfuerzo = const Value.absent(),
    this.energia = const Value.absent(),
    this.plan = const Value.absent(),
    this.catalogoVersion = const Value.absent(),
    this.tiempos = const Value.absent(),
    this.modificadoEn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GimSesionesCompanion.insert({
    required String id,
    required String personaId,
    required String fecha,
    required String plantilla,
    required String version,
    required String semanaTipo,
    required String ventana,
    this.bloqueId = const Value.absent(),
    required DateTime inicio,
    this.fin = const Value.absent(),
    required String estado,
    this.esfuerzo = const Value.absent(),
    this.energia = const Value.absent(),
    this.plan = const Value.absent(),
    required int catalogoVersion,
    this.tiempos = const Value.absent(),
    required DateTime modificadoEn,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       personaId = Value(personaId),
       fecha = Value(fecha),
       plantilla = Value(plantilla),
       version = Value(version),
       semanaTipo = Value(semanaTipo),
       ventana = Value(ventana),
       inicio = Value(inicio),
       estado = Value(estado),
       catalogoVersion = Value(catalogoVersion),
       modificadoEn = Value(modificadoEn);
  static Insertable<GimSesionFila> custom({
    Expression<String>? id,
    Expression<String>? personaId,
    Expression<String>? fecha,
    Expression<String>? plantilla,
    Expression<String>? version,
    Expression<String>? semanaTipo,
    Expression<String>? ventana,
    Expression<String>? bloqueId,
    Expression<DateTime>? inicio,
    Expression<DateTime>? fin,
    Expression<String>? estado,
    Expression<int>? esfuerzo,
    Expression<int>? energia,
    Expression<String>? plan,
    Expression<int>? catalogoVersion,
    Expression<String>? tiempos,
    Expression<DateTime>? modificadoEn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personaId != null) 'persona_id': personaId,
      if (fecha != null) 'fecha': fecha,
      if (plantilla != null) 'plantilla': plantilla,
      if (version != null) 'version': version,
      if (semanaTipo != null) 'semana_tipo': semanaTipo,
      if (ventana != null) 'ventana': ventana,
      if (bloqueId != null) 'bloque_id': bloqueId,
      if (inicio != null) 'inicio': inicio,
      if (fin != null) 'fin': fin,
      if (estado != null) 'estado': estado,
      if (esfuerzo != null) 'esfuerzo': esfuerzo,
      if (energia != null) 'energia': energia,
      if (plan != null) 'plan': plan,
      if (catalogoVersion != null) 'catalogo_version': catalogoVersion,
      if (tiempos != null) 'tiempos': tiempos,
      if (modificadoEn != null) 'modificado_en': modificadoEn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GimSesionesCompanion copyWith({
    Value<String>? id,
    Value<String>? personaId,
    Value<String>? fecha,
    Value<String>? plantilla,
    Value<String>? version,
    Value<String>? semanaTipo,
    Value<String>? ventana,
    Value<String?>? bloqueId,
    Value<DateTime>? inicio,
    Value<DateTime?>? fin,
    Value<String>? estado,
    Value<int?>? esfuerzo,
    Value<int?>? energia,
    Value<String>? plan,
    Value<int>? catalogoVersion,
    Value<String?>? tiempos,
    Value<DateTime>? modificadoEn,
    Value<int>? rowid,
  }) {
    return GimSesionesCompanion(
      id: id ?? this.id,
      personaId: personaId ?? this.personaId,
      fecha: fecha ?? this.fecha,
      plantilla: plantilla ?? this.plantilla,
      version: version ?? this.version,
      semanaTipo: semanaTipo ?? this.semanaTipo,
      ventana: ventana ?? this.ventana,
      bloqueId: bloqueId ?? this.bloqueId,
      inicio: inicio ?? this.inicio,
      fin: fin ?? this.fin,
      estado: estado ?? this.estado,
      esfuerzo: esfuerzo ?? this.esfuerzo,
      energia: energia ?? this.energia,
      plan: plan ?? this.plan,
      catalogoVersion: catalogoVersion ?? this.catalogoVersion,
      tiempos: tiempos ?? this.tiempos,
      modificadoEn: modificadoEn ?? this.modificadoEn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (personaId.present) {
      map['persona_id'] = Variable<String>(personaId.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<String>(fecha.value);
    }
    if (plantilla.present) {
      map['plantilla'] = Variable<String>(plantilla.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (semanaTipo.present) {
      map['semana_tipo'] = Variable<String>(semanaTipo.value);
    }
    if (ventana.present) {
      map['ventana'] = Variable<String>(ventana.value);
    }
    if (bloqueId.present) {
      map['bloque_id'] = Variable<String>(bloqueId.value);
    }
    if (inicio.present) {
      map['inicio'] = Variable<DateTime>(inicio.value);
    }
    if (fin.present) {
      map['fin'] = Variable<DateTime>(fin.value);
    }
    if (estado.present) {
      map['estado'] = Variable<String>(estado.value);
    }
    if (esfuerzo.present) {
      map['esfuerzo'] = Variable<int>(esfuerzo.value);
    }
    if (energia.present) {
      map['energia'] = Variable<int>(energia.value);
    }
    if (plan.present) {
      map['plan'] = Variable<String>(plan.value);
    }
    if (catalogoVersion.present) {
      map['catalogo_version'] = Variable<int>(catalogoVersion.value);
    }
    if (tiempos.present) {
      map['tiempos'] = Variable<String>(tiempos.value);
    }
    if (modificadoEn.present) {
      map['modificado_en'] = Variable<DateTime>(modificadoEn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GimSesionesCompanion(')
          ..write('id: $id, ')
          ..write('personaId: $personaId, ')
          ..write('fecha: $fecha, ')
          ..write('plantilla: $plantilla, ')
          ..write('version: $version, ')
          ..write('semanaTipo: $semanaTipo, ')
          ..write('ventana: $ventana, ')
          ..write('bloqueId: $bloqueId, ')
          ..write('inicio: $inicio, ')
          ..write('fin: $fin, ')
          ..write('estado: $estado, ')
          ..write('esfuerzo: $esfuerzo, ')
          ..write('energia: $energia, ')
          ..write('plan: $plan, ')
          ..write('catalogoVersion: $catalogoVersion, ')
          ..write('tiempos: $tiempos, ')
          ..write('modificadoEn: $modificadoEn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GimSeriesTable extends GimSeries
    with TableInfo<$GimSeriesTable, GimSerieFila> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GimSeriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personaIdMeta = const VerificationMeta(
    'personaId',
  );
  @override
  late final GeneratedColumn<String> personaId = GeneratedColumn<String>(
    'persona_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sesionIdMeta = const VerificationMeta(
    'sesionId',
  );
  @override
  late final GeneratedColumn<String> sesionId = GeneratedColumn<String>(
    'sesion_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ejercicioIdMeta = const VerificationMeta(
    'ejercicioId',
  );
  @override
  late final GeneratedColumn<String> ejercicioId = GeneratedColumn<String>(
    'ejercicio_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _varianteIdMeta = const VerificationMeta(
    'varianteId',
  );
  @override
  late final GeneratedColumn<String> varianteId = GeneratedColumn<String>(
    'variante_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nMeta = const VerificationMeta('n');
  @override
  late final GeneratedColumn<int> n = GeneratedColumn<int>(
    'n',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ladoMeta = const VerificationMeta('lado');
  @override
  late final GeneratedColumn<String> lado = GeneratedColumn<String>(
    'lado',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _segundosMeta = const VerificationMeta(
    'segundos',
  );
  @override
  late final GeneratedColumn<int> segundos = GeneratedColumn<int>(
    'segundos',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cargaPasosMeta = const VerificationMeta(
    'cargaPasos',
  );
  @override
  late final GeneratedColumn<int> cargaPasos = GeneratedColumn<int>(
    'carga_pasos',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bandaIdMeta = const VerificationMeta(
    'bandaId',
  );
  @override
  late final GeneratedColumn<String> bandaId = GeneratedColumn<String>(
    'banda_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _esfuerzoMeta = const VerificationMeta(
    'esfuerzo',
  );
  @override
  late final GeneratedColumn<int> esfuerzo = GeneratedColumn<int>(
    'esfuerzo',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descansoRealSMeta = const VerificationMeta(
    'descansoRealS',
  );
  @override
  late final GeneratedColumn<int> descansoRealS = GeneratedColumn<int>(
    'descanso_real_s',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sustituyeAMeta = const VerificationMeta(
    'sustituyeA',
  );
  @override
  late final GeneratedColumn<String> sustituyeA = GeneratedColumn<String>(
    'sustituye_a',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _motivoCambioMeta = const VerificationMeta(
    'motivoCambio',
  );
  @override
  late final GeneratedColumn<String> motivoCambio = GeneratedColumn<String>(
    'motivo_cambio',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modificadoEnMeta = const VerificationMeta(
    'modificadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> modificadoEn = GeneratedColumn<DateTime>(
    'modificado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    personaId,
    sesionId,
    ejercicioId,
    varianteId,
    n,
    lado,
    reps,
    segundos,
    cargaPasos,
    bandaId,
    esfuerzo,
    descansoRealS,
    sustituyeA,
    motivoCambio,
    modificadoEn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gim_series';
  @override
  VerificationContext validateIntegrity(
    Insertable<GimSerieFila> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('persona_id')) {
      context.handle(
        _personaIdMeta,
        personaId.isAcceptableOrUnknown(data['persona_id']!, _personaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personaIdMeta);
    }
    if (data.containsKey('sesion_id')) {
      context.handle(
        _sesionIdMeta,
        sesionId.isAcceptableOrUnknown(data['sesion_id']!, _sesionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sesionIdMeta);
    }
    if (data.containsKey('ejercicio_id')) {
      context.handle(
        _ejercicioIdMeta,
        ejercicioId.isAcceptableOrUnknown(
          data['ejercicio_id']!,
          _ejercicioIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ejercicioIdMeta);
    }
    if (data.containsKey('variante_id')) {
      context.handle(
        _varianteIdMeta,
        varianteId.isAcceptableOrUnknown(data['variante_id']!, _varianteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_varianteIdMeta);
    }
    if (data.containsKey('n')) {
      context.handle(_nMeta, n.isAcceptableOrUnknown(data['n']!, _nMeta));
    } else if (isInserting) {
      context.missing(_nMeta);
    }
    if (data.containsKey('lado')) {
      context.handle(
        _ladoMeta,
        lado.isAcceptableOrUnknown(data['lado']!, _ladoMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('segundos')) {
      context.handle(
        _segundosMeta,
        segundos.isAcceptableOrUnknown(data['segundos']!, _segundosMeta),
      );
    }
    if (data.containsKey('carga_pasos')) {
      context.handle(
        _cargaPasosMeta,
        cargaPasos.isAcceptableOrUnknown(data['carga_pasos']!, _cargaPasosMeta),
      );
    }
    if (data.containsKey('banda_id')) {
      context.handle(
        _bandaIdMeta,
        bandaId.isAcceptableOrUnknown(data['banda_id']!, _bandaIdMeta),
      );
    }
    if (data.containsKey('esfuerzo')) {
      context.handle(
        _esfuerzoMeta,
        esfuerzo.isAcceptableOrUnknown(data['esfuerzo']!, _esfuerzoMeta),
      );
    }
    if (data.containsKey('descanso_real_s')) {
      context.handle(
        _descansoRealSMeta,
        descansoRealS.isAcceptableOrUnknown(
          data['descanso_real_s']!,
          _descansoRealSMeta,
        ),
      );
    }
    if (data.containsKey('sustituye_a')) {
      context.handle(
        _sustituyeAMeta,
        sustituyeA.isAcceptableOrUnknown(data['sustituye_a']!, _sustituyeAMeta),
      );
    }
    if (data.containsKey('motivo_cambio')) {
      context.handle(
        _motivoCambioMeta,
        motivoCambio.isAcceptableOrUnknown(
          data['motivo_cambio']!,
          _motivoCambioMeta,
        ),
      );
    }
    if (data.containsKey('modificado_en')) {
      context.handle(
        _modificadoEnMeta,
        modificadoEn.isAcceptableOrUnknown(
          data['modificado_en']!,
          _modificadoEnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modificadoEnMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GimSerieFila map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GimSerieFila(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      personaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona_id'],
      )!,
      sesionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sesion_id'],
      )!,
      ejercicioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ejercicio_id'],
      )!,
      varianteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variante_id'],
      )!,
      n: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}n'],
      )!,
      lado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lado'],
      ),
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      ),
      segundos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segundos'],
      ),
      cargaPasos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}carga_pasos'],
      ),
      bandaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}banda_id'],
      ),
      esfuerzo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}esfuerzo'],
      ),
      descansoRealS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}descanso_real_s'],
      ),
      sustituyeA: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sustituye_a'],
      ),
      motivoCambio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}motivo_cambio'],
      ),
      modificadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modificado_en'],
      )!,
    );
  }

  @override
  $GimSeriesTable createAlias(String alias) {
    return $GimSeriesTable(attachedDatabase, alias);
  }
}

class GimSerieFila extends DataClass implements Insertable<GimSerieFila> {
  final String id;
  final String personaId;
  final String sesionId;
  final String ejercicioId;
  final String varianteId;
  final int n;
  final String? lado;
  final int? reps;
  final int? segundos;
  final int? cargaPasos;
  final String? bandaId;
  final int? esfuerzo;
  final int? descansoRealS;
  final String? sustituyeA;

  /// `no_disponible`, `preferencia` u `otra`; **nunca** «molestia» (PG-19).
  final String? motivoCambio;
  final DateTime modificadoEn;
  const GimSerieFila({
    required this.id,
    required this.personaId,
    required this.sesionId,
    required this.ejercicioId,
    required this.varianteId,
    required this.n,
    this.lado,
    this.reps,
    this.segundos,
    this.cargaPasos,
    this.bandaId,
    this.esfuerzo,
    this.descansoRealS,
    this.sustituyeA,
    this.motivoCambio,
    required this.modificadoEn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['persona_id'] = Variable<String>(personaId);
    map['sesion_id'] = Variable<String>(sesionId);
    map['ejercicio_id'] = Variable<String>(ejercicioId);
    map['variante_id'] = Variable<String>(varianteId);
    map['n'] = Variable<int>(n);
    if (!nullToAbsent || lado != null) {
      map['lado'] = Variable<String>(lado);
    }
    if (!nullToAbsent || reps != null) {
      map['reps'] = Variable<int>(reps);
    }
    if (!nullToAbsent || segundos != null) {
      map['segundos'] = Variable<int>(segundos);
    }
    if (!nullToAbsent || cargaPasos != null) {
      map['carga_pasos'] = Variable<int>(cargaPasos);
    }
    if (!nullToAbsent || bandaId != null) {
      map['banda_id'] = Variable<String>(bandaId);
    }
    if (!nullToAbsent || esfuerzo != null) {
      map['esfuerzo'] = Variable<int>(esfuerzo);
    }
    if (!nullToAbsent || descansoRealS != null) {
      map['descanso_real_s'] = Variable<int>(descansoRealS);
    }
    if (!nullToAbsent || sustituyeA != null) {
      map['sustituye_a'] = Variable<String>(sustituyeA);
    }
    if (!nullToAbsent || motivoCambio != null) {
      map['motivo_cambio'] = Variable<String>(motivoCambio);
    }
    map['modificado_en'] = Variable<DateTime>(modificadoEn);
    return map;
  }

  GimSeriesCompanion toCompanion(bool nullToAbsent) {
    return GimSeriesCompanion(
      id: Value(id),
      personaId: Value(personaId),
      sesionId: Value(sesionId),
      ejercicioId: Value(ejercicioId),
      varianteId: Value(varianteId),
      n: Value(n),
      lado: lado == null && nullToAbsent ? const Value.absent() : Value(lado),
      reps: reps == null && nullToAbsent ? const Value.absent() : Value(reps),
      segundos: segundos == null && nullToAbsent
          ? const Value.absent()
          : Value(segundos),
      cargaPasos: cargaPasos == null && nullToAbsent
          ? const Value.absent()
          : Value(cargaPasos),
      bandaId: bandaId == null && nullToAbsent
          ? const Value.absent()
          : Value(bandaId),
      esfuerzo: esfuerzo == null && nullToAbsent
          ? const Value.absent()
          : Value(esfuerzo),
      descansoRealS: descansoRealS == null && nullToAbsent
          ? const Value.absent()
          : Value(descansoRealS),
      sustituyeA: sustituyeA == null && nullToAbsent
          ? const Value.absent()
          : Value(sustituyeA),
      motivoCambio: motivoCambio == null && nullToAbsent
          ? const Value.absent()
          : Value(motivoCambio),
      modificadoEn: Value(modificadoEn),
    );
  }

  factory GimSerieFila.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GimSerieFila(
      id: serializer.fromJson<String>(json['id']),
      personaId: serializer.fromJson<String>(json['personaId']),
      sesionId: serializer.fromJson<String>(json['sesionId']),
      ejercicioId: serializer.fromJson<String>(json['ejercicioId']),
      varianteId: serializer.fromJson<String>(json['varianteId']),
      n: serializer.fromJson<int>(json['n']),
      lado: serializer.fromJson<String?>(json['lado']),
      reps: serializer.fromJson<int?>(json['reps']),
      segundos: serializer.fromJson<int?>(json['segundos']),
      cargaPasos: serializer.fromJson<int?>(json['cargaPasos']),
      bandaId: serializer.fromJson<String?>(json['bandaId']),
      esfuerzo: serializer.fromJson<int?>(json['esfuerzo']),
      descansoRealS: serializer.fromJson<int?>(json['descansoRealS']),
      sustituyeA: serializer.fromJson<String?>(json['sustituyeA']),
      motivoCambio: serializer.fromJson<String?>(json['motivoCambio']),
      modificadoEn: serializer.fromJson<DateTime>(json['modificadoEn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'personaId': serializer.toJson<String>(personaId),
      'sesionId': serializer.toJson<String>(sesionId),
      'ejercicioId': serializer.toJson<String>(ejercicioId),
      'varianteId': serializer.toJson<String>(varianteId),
      'n': serializer.toJson<int>(n),
      'lado': serializer.toJson<String?>(lado),
      'reps': serializer.toJson<int?>(reps),
      'segundos': serializer.toJson<int?>(segundos),
      'cargaPasos': serializer.toJson<int?>(cargaPasos),
      'bandaId': serializer.toJson<String?>(bandaId),
      'esfuerzo': serializer.toJson<int?>(esfuerzo),
      'descansoRealS': serializer.toJson<int?>(descansoRealS),
      'sustituyeA': serializer.toJson<String?>(sustituyeA),
      'motivoCambio': serializer.toJson<String?>(motivoCambio),
      'modificadoEn': serializer.toJson<DateTime>(modificadoEn),
    };
  }

  GimSerieFila copyWith({
    String? id,
    String? personaId,
    String? sesionId,
    String? ejercicioId,
    String? varianteId,
    int? n,
    Value<String?> lado = const Value.absent(),
    Value<int?> reps = const Value.absent(),
    Value<int?> segundos = const Value.absent(),
    Value<int?> cargaPasos = const Value.absent(),
    Value<String?> bandaId = const Value.absent(),
    Value<int?> esfuerzo = const Value.absent(),
    Value<int?> descansoRealS = const Value.absent(),
    Value<String?> sustituyeA = const Value.absent(),
    Value<String?> motivoCambio = const Value.absent(),
    DateTime? modificadoEn,
  }) => GimSerieFila(
    id: id ?? this.id,
    personaId: personaId ?? this.personaId,
    sesionId: sesionId ?? this.sesionId,
    ejercicioId: ejercicioId ?? this.ejercicioId,
    varianteId: varianteId ?? this.varianteId,
    n: n ?? this.n,
    lado: lado.present ? lado.value : this.lado,
    reps: reps.present ? reps.value : this.reps,
    segundos: segundos.present ? segundos.value : this.segundos,
    cargaPasos: cargaPasos.present ? cargaPasos.value : this.cargaPasos,
    bandaId: bandaId.present ? bandaId.value : this.bandaId,
    esfuerzo: esfuerzo.present ? esfuerzo.value : this.esfuerzo,
    descansoRealS: descansoRealS.present
        ? descansoRealS.value
        : this.descansoRealS,
    sustituyeA: sustituyeA.present ? sustituyeA.value : this.sustituyeA,
    motivoCambio: motivoCambio.present ? motivoCambio.value : this.motivoCambio,
    modificadoEn: modificadoEn ?? this.modificadoEn,
  );
  GimSerieFila copyWithCompanion(GimSeriesCompanion data) {
    return GimSerieFila(
      id: data.id.present ? data.id.value : this.id,
      personaId: data.personaId.present ? data.personaId.value : this.personaId,
      sesionId: data.sesionId.present ? data.sesionId.value : this.sesionId,
      ejercicioId: data.ejercicioId.present
          ? data.ejercicioId.value
          : this.ejercicioId,
      varianteId: data.varianteId.present
          ? data.varianteId.value
          : this.varianteId,
      n: data.n.present ? data.n.value : this.n,
      lado: data.lado.present ? data.lado.value : this.lado,
      reps: data.reps.present ? data.reps.value : this.reps,
      segundos: data.segundos.present ? data.segundos.value : this.segundos,
      cargaPasos: data.cargaPasos.present
          ? data.cargaPasos.value
          : this.cargaPasos,
      bandaId: data.bandaId.present ? data.bandaId.value : this.bandaId,
      esfuerzo: data.esfuerzo.present ? data.esfuerzo.value : this.esfuerzo,
      descansoRealS: data.descansoRealS.present
          ? data.descansoRealS.value
          : this.descansoRealS,
      sustituyeA: data.sustituyeA.present
          ? data.sustituyeA.value
          : this.sustituyeA,
      motivoCambio: data.motivoCambio.present
          ? data.motivoCambio.value
          : this.motivoCambio,
      modificadoEn: data.modificadoEn.present
          ? data.modificadoEn.value
          : this.modificadoEn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GimSerieFila(')
          ..write('id: $id, ')
          ..write('personaId: $personaId, ')
          ..write('sesionId: $sesionId, ')
          ..write('ejercicioId: $ejercicioId, ')
          ..write('varianteId: $varianteId, ')
          ..write('n: $n, ')
          ..write('lado: $lado, ')
          ..write('reps: $reps, ')
          ..write('segundos: $segundos, ')
          ..write('cargaPasos: $cargaPasos, ')
          ..write('bandaId: $bandaId, ')
          ..write('esfuerzo: $esfuerzo, ')
          ..write('descansoRealS: $descansoRealS, ')
          ..write('sustituyeA: $sustituyeA, ')
          ..write('motivoCambio: $motivoCambio, ')
          ..write('modificadoEn: $modificadoEn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    personaId,
    sesionId,
    ejercicioId,
    varianteId,
    n,
    lado,
    reps,
    segundos,
    cargaPasos,
    bandaId,
    esfuerzo,
    descansoRealS,
    sustituyeA,
    motivoCambio,
    modificadoEn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GimSerieFila &&
          other.id == this.id &&
          other.personaId == this.personaId &&
          other.sesionId == this.sesionId &&
          other.ejercicioId == this.ejercicioId &&
          other.varianteId == this.varianteId &&
          other.n == this.n &&
          other.lado == this.lado &&
          other.reps == this.reps &&
          other.segundos == this.segundos &&
          other.cargaPasos == this.cargaPasos &&
          other.bandaId == this.bandaId &&
          other.esfuerzo == this.esfuerzo &&
          other.descansoRealS == this.descansoRealS &&
          other.sustituyeA == this.sustituyeA &&
          other.motivoCambio == this.motivoCambio &&
          other.modificadoEn == this.modificadoEn);
}

class GimSeriesCompanion extends UpdateCompanion<GimSerieFila> {
  final Value<String> id;
  final Value<String> personaId;
  final Value<String> sesionId;
  final Value<String> ejercicioId;
  final Value<String> varianteId;
  final Value<int> n;
  final Value<String?> lado;
  final Value<int?> reps;
  final Value<int?> segundos;
  final Value<int?> cargaPasos;
  final Value<String?> bandaId;
  final Value<int?> esfuerzo;
  final Value<int?> descansoRealS;
  final Value<String?> sustituyeA;
  final Value<String?> motivoCambio;
  final Value<DateTime> modificadoEn;
  final Value<int> rowid;
  const GimSeriesCompanion({
    this.id = const Value.absent(),
    this.personaId = const Value.absent(),
    this.sesionId = const Value.absent(),
    this.ejercicioId = const Value.absent(),
    this.varianteId = const Value.absent(),
    this.n = const Value.absent(),
    this.lado = const Value.absent(),
    this.reps = const Value.absent(),
    this.segundos = const Value.absent(),
    this.cargaPasos = const Value.absent(),
    this.bandaId = const Value.absent(),
    this.esfuerzo = const Value.absent(),
    this.descansoRealS = const Value.absent(),
    this.sustituyeA = const Value.absent(),
    this.motivoCambio = const Value.absent(),
    this.modificadoEn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GimSeriesCompanion.insert({
    required String id,
    required String personaId,
    required String sesionId,
    required String ejercicioId,
    required String varianteId,
    required int n,
    this.lado = const Value.absent(),
    this.reps = const Value.absent(),
    this.segundos = const Value.absent(),
    this.cargaPasos = const Value.absent(),
    this.bandaId = const Value.absent(),
    this.esfuerzo = const Value.absent(),
    this.descansoRealS = const Value.absent(),
    this.sustituyeA = const Value.absent(),
    this.motivoCambio = const Value.absent(),
    required DateTime modificadoEn,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       personaId = Value(personaId),
       sesionId = Value(sesionId),
       ejercicioId = Value(ejercicioId),
       varianteId = Value(varianteId),
       n = Value(n),
       modificadoEn = Value(modificadoEn);
  static Insertable<GimSerieFila> custom({
    Expression<String>? id,
    Expression<String>? personaId,
    Expression<String>? sesionId,
    Expression<String>? ejercicioId,
    Expression<String>? varianteId,
    Expression<int>? n,
    Expression<String>? lado,
    Expression<int>? reps,
    Expression<int>? segundos,
    Expression<int>? cargaPasos,
    Expression<String>? bandaId,
    Expression<int>? esfuerzo,
    Expression<int>? descansoRealS,
    Expression<String>? sustituyeA,
    Expression<String>? motivoCambio,
    Expression<DateTime>? modificadoEn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personaId != null) 'persona_id': personaId,
      if (sesionId != null) 'sesion_id': sesionId,
      if (ejercicioId != null) 'ejercicio_id': ejercicioId,
      if (varianteId != null) 'variante_id': varianteId,
      if (n != null) 'n': n,
      if (lado != null) 'lado': lado,
      if (reps != null) 'reps': reps,
      if (segundos != null) 'segundos': segundos,
      if (cargaPasos != null) 'carga_pasos': cargaPasos,
      if (bandaId != null) 'banda_id': bandaId,
      if (esfuerzo != null) 'esfuerzo': esfuerzo,
      if (descansoRealS != null) 'descanso_real_s': descansoRealS,
      if (sustituyeA != null) 'sustituye_a': sustituyeA,
      if (motivoCambio != null) 'motivo_cambio': motivoCambio,
      if (modificadoEn != null) 'modificado_en': modificadoEn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GimSeriesCompanion copyWith({
    Value<String>? id,
    Value<String>? personaId,
    Value<String>? sesionId,
    Value<String>? ejercicioId,
    Value<String>? varianteId,
    Value<int>? n,
    Value<String?>? lado,
    Value<int?>? reps,
    Value<int?>? segundos,
    Value<int?>? cargaPasos,
    Value<String?>? bandaId,
    Value<int?>? esfuerzo,
    Value<int?>? descansoRealS,
    Value<String?>? sustituyeA,
    Value<String?>? motivoCambio,
    Value<DateTime>? modificadoEn,
    Value<int>? rowid,
  }) {
    return GimSeriesCompanion(
      id: id ?? this.id,
      personaId: personaId ?? this.personaId,
      sesionId: sesionId ?? this.sesionId,
      ejercicioId: ejercicioId ?? this.ejercicioId,
      varianteId: varianteId ?? this.varianteId,
      n: n ?? this.n,
      lado: lado ?? this.lado,
      reps: reps ?? this.reps,
      segundos: segundos ?? this.segundos,
      cargaPasos: cargaPasos ?? this.cargaPasos,
      bandaId: bandaId ?? this.bandaId,
      esfuerzo: esfuerzo ?? this.esfuerzo,
      descansoRealS: descansoRealS ?? this.descansoRealS,
      sustituyeA: sustituyeA ?? this.sustituyeA,
      motivoCambio: motivoCambio ?? this.motivoCambio,
      modificadoEn: modificadoEn ?? this.modificadoEn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (personaId.present) {
      map['persona_id'] = Variable<String>(personaId.value);
    }
    if (sesionId.present) {
      map['sesion_id'] = Variable<String>(sesionId.value);
    }
    if (ejercicioId.present) {
      map['ejercicio_id'] = Variable<String>(ejercicioId.value);
    }
    if (varianteId.present) {
      map['variante_id'] = Variable<String>(varianteId.value);
    }
    if (n.present) {
      map['n'] = Variable<int>(n.value);
    }
    if (lado.present) {
      map['lado'] = Variable<String>(lado.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (segundos.present) {
      map['segundos'] = Variable<int>(segundos.value);
    }
    if (cargaPasos.present) {
      map['carga_pasos'] = Variable<int>(cargaPasos.value);
    }
    if (bandaId.present) {
      map['banda_id'] = Variable<String>(bandaId.value);
    }
    if (esfuerzo.present) {
      map['esfuerzo'] = Variable<int>(esfuerzo.value);
    }
    if (descansoRealS.present) {
      map['descanso_real_s'] = Variable<int>(descansoRealS.value);
    }
    if (sustituyeA.present) {
      map['sustituye_a'] = Variable<String>(sustituyeA.value);
    }
    if (motivoCambio.present) {
      map['motivo_cambio'] = Variable<String>(motivoCambio.value);
    }
    if (modificadoEn.present) {
      map['modificado_en'] = Variable<DateTime>(modificadoEn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GimSeriesCompanion(')
          ..write('id: $id, ')
          ..write('personaId: $personaId, ')
          ..write('sesionId: $sesionId, ')
          ..write('ejercicioId: $ejercicioId, ')
          ..write('varianteId: $varianteId, ')
          ..write('n: $n, ')
          ..write('lado: $lado, ')
          ..write('reps: $reps, ')
          ..write('segundos: $segundos, ')
          ..write('cargaPasos: $cargaPasos, ')
          ..write('bandaId: $bandaId, ')
          ..write('esfuerzo: $esfuerzo, ')
          ..write('descansoRealS: $descansoRealS, ')
          ..write('sustituyeA: $sustituyeA, ')
          ..write('motivoCambio: $motivoCambio, ')
          ..write('modificadoEn: $modificadoEn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$BaseLocal extends GeneratedDatabase {
  _$BaseLocal(QueryExecutor e) : super(e);
  $BaseLocalManager get managers => $BaseLocalManager(this);
  late final $PendientesTable pendientes = $PendientesTable(this);
  late final $GimPerfilTable gimPerfil = $GimPerfilTable(this);
  late final $GimPlanDiasTable gimPlanDias = $GimPlanDiasTable(this);
  late final $GimInventarioTable gimInventario = $GimInventarioTable(this);
  late final $GimBandasTable gimBandas = $GimBandasTable(this);
  late final $GimSesionesTable gimSesiones = $GimSesionesTable(this);
  late final $GimSeriesTable gimSeries = $GimSeriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    pendientes,
    gimPerfil,
    gimPlanDias,
    gimInventario,
    gimBandas,
    gimSesiones,
    gimSeries,
  ];
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
  Value<String?> personaId,
  Value<OrigenRegistro?> origen,
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
  Value<String?> personaId,
  Value<OrigenRegistro?> origen,
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

  ColumnFilters<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OrigenRegistro?, OrigenRegistro, String>
  get origen => $composableBuilder(
    column: $table.origen,
    builder: (column) => ColumnWithTypeConverterFilters(column),
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

  ColumnOrderings<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origen => $composableBuilder(
    column: $table.origen,
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

  GeneratedColumn<String> get personaId =>
      $composableBuilder(column: $table.personaId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OrigenRegistro?, String> get origen =>
      $composableBuilder(column: $table.origen, builder: (column) => column);
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
                Value<String?> personaId = const Value.absent(),
                Value<OrigenRegistro?> origen = const Value.absent(),
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
                personaId: personaId,
                origen: origen,
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
                Value<String?> personaId = const Value.absent(),
                Value<OrigenRegistro?> origen = const Value.absent(),
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
                personaId: personaId,
                origen: origen,
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
typedef $$GimPerfilTableCreateCompanionBuilder = GimPerfilCompanion Function({
  required String personaId,
  Value<int> diasPlan,
  Value<String> versionPref,
  Value<String> ventana,
  Value<String> nocheDesde,
  Value<String> objetivo,
  Value<String> nivel,
  Value<String?> inicioCiclo,
  Value<int> cicloSemanas,
  Value<int?> descansoS,
  Value<int> margenDormirMin,
  Value<String?> pruebaDesde,
  Value<String?> pruebaVentana,
  Value<bool> vozDescanso,
  Value<DateTime?> avisoVistoEn,
  required DateTime modificadoEn,
  Value<int> rowid,
});
typedef $$GimPerfilTableUpdateCompanionBuilder = GimPerfilCompanion Function({
  Value<String> personaId,
  Value<int> diasPlan,
  Value<String> versionPref,
  Value<String> ventana,
  Value<String> nocheDesde,
  Value<String> objetivo,
  Value<String> nivel,
  Value<String?> inicioCiclo,
  Value<int> cicloSemanas,
  Value<int?> descansoS,
  Value<int> margenDormirMin,
  Value<String?> pruebaDesde,
  Value<String?> pruebaVentana,
  Value<bool> vozDescanso,
  Value<DateTime?> avisoVistoEn,
  Value<DateTime> modificadoEn,
  Value<int> rowid,
});

class $$GimPerfilTableFilterComposer
    extends Composer<_$BaseLocal, $GimPerfilTable> {
  $$GimPerfilTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diasPlan => $composableBuilder(
    column: $table.diasPlan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionPref => $composableBuilder(
    column: $table.versionPref,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ventana => $composableBuilder(
    column: $table.ventana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nocheDesde => $composableBuilder(
    column: $table.nocheDesde,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objetivo => $composableBuilder(
    column: $table.objetivo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nivel => $composableBuilder(
    column: $table.nivel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inicioCiclo => $composableBuilder(
    column: $table.inicioCiclo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cicloSemanas => $composableBuilder(
    column: $table.cicloSemanas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get descansoS => $composableBuilder(
    column: $table.descansoS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get margenDormirMin => $composableBuilder(
    column: $table.margenDormirMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pruebaDesde => $composableBuilder(
    column: $table.pruebaDesde,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pruebaVentana => $composableBuilder(
    column: $table.pruebaVentana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get vozDescanso => $composableBuilder(
    column: $table.vozDescanso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get avisoVistoEn => $composableBuilder(
    column: $table.avisoVistoEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GimPerfilTableOrderingComposer
    extends Composer<_$BaseLocal, $GimPerfilTable> {
  $$GimPerfilTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diasPlan => $composableBuilder(
    column: $table.diasPlan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionPref => $composableBuilder(
    column: $table.versionPref,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ventana => $composableBuilder(
    column: $table.ventana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nocheDesde => $composableBuilder(
    column: $table.nocheDesde,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objetivo => $composableBuilder(
    column: $table.objetivo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nivel => $composableBuilder(
    column: $table.nivel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inicioCiclo => $composableBuilder(
    column: $table.inicioCiclo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cicloSemanas => $composableBuilder(
    column: $table.cicloSemanas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get descansoS => $composableBuilder(
    column: $table.descansoS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get margenDormirMin => $composableBuilder(
    column: $table.margenDormirMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pruebaDesde => $composableBuilder(
    column: $table.pruebaDesde,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pruebaVentana => $composableBuilder(
    column: $table.pruebaVentana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get vozDescanso => $composableBuilder(
    column: $table.vozDescanso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get avisoVistoEn => $composableBuilder(
    column: $table.avisoVistoEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GimPerfilTableAnnotationComposer
    extends Composer<_$BaseLocal, $GimPerfilTable> {
  $$GimPerfilTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get personaId =>
      $composableBuilder(column: $table.personaId, builder: (column) => column);

  GeneratedColumn<int> get diasPlan =>
      $composableBuilder(column: $table.diasPlan, builder: (column) => column);

  GeneratedColumn<String> get versionPref => $composableBuilder(
    column: $table.versionPref,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ventana =>
      $composableBuilder(column: $table.ventana, builder: (column) => column);

  GeneratedColumn<String> get nocheDesde => $composableBuilder(
    column: $table.nocheDesde,
    builder: (column) => column,
  );

  GeneratedColumn<String> get objetivo =>
      $composableBuilder(column: $table.objetivo, builder: (column) => column);

  GeneratedColumn<String> get nivel =>
      $composableBuilder(column: $table.nivel, builder: (column) => column);

  GeneratedColumn<String> get inicioCiclo => $composableBuilder(
    column: $table.inicioCiclo,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cicloSemanas => $composableBuilder(
    column: $table.cicloSemanas,
    builder: (column) => column,
  );

  GeneratedColumn<int> get descansoS =>
      $composableBuilder(column: $table.descansoS, builder: (column) => column);

  GeneratedColumn<int> get margenDormirMin => $composableBuilder(
    column: $table.margenDormirMin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pruebaDesde => $composableBuilder(
    column: $table.pruebaDesde,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pruebaVentana => $composableBuilder(
    column: $table.pruebaVentana,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get vozDescanso => $composableBuilder(
    column: $table.vozDescanso,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get avisoVistoEn => $composableBuilder(
    column: $table.avisoVistoEn,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => column,
  );
}

class $$GimPerfilTableTableManager
    extends
        RootTableManager<
          _$BaseLocal,
          $GimPerfilTable,
          GimPerfilFila,
          $$GimPerfilTableFilterComposer,
          $$GimPerfilTableOrderingComposer,
          $$GimPerfilTableAnnotationComposer,
          $$GimPerfilTableCreateCompanionBuilder,
          $$GimPerfilTableUpdateCompanionBuilder,
          (
            GimPerfilFila,
            BaseReferences<_$BaseLocal, $GimPerfilTable, GimPerfilFila>,
          ),
          GimPerfilFila,
          PrefetchHooks Function()
        > {
  $$GimPerfilTableTableManager(_$BaseLocal db, $GimPerfilTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GimPerfilTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GimPerfilTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GimPerfilTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> personaId = const Value.absent(),
                Value<int> diasPlan = const Value.absent(),
                Value<String> versionPref = const Value.absent(),
                Value<String> ventana = const Value.absent(),
                Value<String> nocheDesde = const Value.absent(),
                Value<String> objetivo = const Value.absent(),
                Value<String> nivel = const Value.absent(),
                Value<String?> inicioCiclo = const Value.absent(),
                Value<int> cicloSemanas = const Value.absent(),
                Value<int?> descansoS = const Value.absent(),
                Value<int> margenDormirMin = const Value.absent(),
                Value<String?> pruebaDesde = const Value.absent(),
                Value<String?> pruebaVentana = const Value.absent(),
                Value<bool> vozDescanso = const Value.absent(),
                Value<DateTime?> avisoVistoEn = const Value.absent(),
                Value<DateTime> modificadoEn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GimPerfilCompanion(
                personaId: personaId,
                diasPlan: diasPlan,
                versionPref: versionPref,
                ventana: ventana,
                nocheDesde: nocheDesde,
                objetivo: objetivo,
                nivel: nivel,
                inicioCiclo: inicioCiclo,
                cicloSemanas: cicloSemanas,
                descansoS: descansoS,
                margenDormirMin: margenDormirMin,
                pruebaDesde: pruebaDesde,
                pruebaVentana: pruebaVentana,
                vozDescanso: vozDescanso,
                avisoVistoEn: avisoVistoEn,
                modificadoEn: modificadoEn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String personaId,
                Value<int> diasPlan = const Value.absent(),
                Value<String> versionPref = const Value.absent(),
                Value<String> ventana = const Value.absent(),
                Value<String> nocheDesde = const Value.absent(),
                Value<String> objetivo = const Value.absent(),
                Value<String> nivel = const Value.absent(),
                Value<String?> inicioCiclo = const Value.absent(),
                Value<int> cicloSemanas = const Value.absent(),
                Value<int?> descansoS = const Value.absent(),
                Value<int> margenDormirMin = const Value.absent(),
                Value<String?> pruebaDesde = const Value.absent(),
                Value<String?> pruebaVentana = const Value.absent(),
                Value<bool> vozDescanso = const Value.absent(),
                Value<DateTime?> avisoVistoEn = const Value.absent(),
                required DateTime modificadoEn,
                Value<int> rowid = const Value.absent(),
              }) => GimPerfilCompanion.insert(
                personaId: personaId,
                diasPlan: diasPlan,
                versionPref: versionPref,
                ventana: ventana,
                nocheDesde: nocheDesde,
                objetivo: objetivo,
                nivel: nivel,
                inicioCiclo: inicioCiclo,
                cicloSemanas: cicloSemanas,
                descansoS: descansoS,
                margenDormirMin: margenDormirMin,
                pruebaDesde: pruebaDesde,
                pruebaVentana: pruebaVentana,
                vozDescanso: vozDescanso,
                avisoVistoEn: avisoVistoEn,
                modificadoEn: modificadoEn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GimPerfilTable, GimPerfilFila>(table),
                  BaseReferences<_$BaseLocal, $GimPerfilTable, GimPerfilFila>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GimPerfilTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseLocal,
      $GimPerfilTable,
      GimPerfilFila,
      $$GimPerfilTableFilterComposer,
      $$GimPerfilTableOrderingComposer,
      $$GimPerfilTableAnnotationComposer,
      $$GimPerfilTableCreateCompanionBuilder,
      $$GimPerfilTableUpdateCompanionBuilder,
      (
        GimPerfilFila,
        BaseReferences<_$BaseLocal, $GimPerfilTable, GimPerfilFila>,
      ),
      GimPerfilFila,
      PrefetchHooks Function()
    >;
typedef $$GimPlanDiasTableCreateCompanionBuilder =
    GimPlanDiasCompanion Function({
      required String personaId,
      required int diaSemana,
      required String tipo,
      Value<String> version,
      Value<String?> hora,
      required DateTime modificadoEn,
      Value<int> rowid,
    });
typedef $$GimPlanDiasTableUpdateCompanionBuilder =
    GimPlanDiasCompanion Function({
      Value<String> personaId,
      Value<int> diaSemana,
      Value<String> tipo,
      Value<String> version,
      Value<String?> hora,
      Value<DateTime> modificadoEn,
      Value<int> rowid,
    });

class $$GimPlanDiasTableFilterComposer
    extends Composer<_$BaseLocal, $GimPlanDiasTable> {
  $$GimPlanDiasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diaSemana => $composableBuilder(
    column: $table.diaSemana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hora => $composableBuilder(
    column: $table.hora,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GimPlanDiasTableOrderingComposer
    extends Composer<_$BaseLocal, $GimPlanDiasTable> {
  $$GimPlanDiasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diaSemana => $composableBuilder(
    column: $table.diaSemana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hora => $composableBuilder(
    column: $table.hora,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GimPlanDiasTableAnnotationComposer
    extends Composer<_$BaseLocal, $GimPlanDiasTable> {
  $$GimPlanDiasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get personaId =>
      $composableBuilder(column: $table.personaId, builder: (column) => column);

  GeneratedColumn<int> get diaSemana =>
      $composableBuilder(column: $table.diaSemana, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get hora =>
      $composableBuilder(column: $table.hora, builder: (column) => column);

  GeneratedColumn<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => column,
  );
}

class $$GimPlanDiasTableTableManager
    extends
        RootTableManager<
          _$BaseLocal,
          $GimPlanDiasTable,
          GimPlanDiaFila,
          $$GimPlanDiasTableFilterComposer,
          $$GimPlanDiasTableOrderingComposer,
          $$GimPlanDiasTableAnnotationComposer,
          $$GimPlanDiasTableCreateCompanionBuilder,
          $$GimPlanDiasTableUpdateCompanionBuilder,
          (
            GimPlanDiaFila,
            BaseReferences<_$BaseLocal, $GimPlanDiasTable, GimPlanDiaFila>,
          ),
          GimPlanDiaFila,
          PrefetchHooks Function()
        > {
  $$GimPlanDiasTableTableManager(_$BaseLocal db, $GimPlanDiasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GimPlanDiasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GimPlanDiasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GimPlanDiasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> personaId = const Value.absent(),
                Value<int> diaSemana = const Value.absent(),
                Value<String> tipo = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String?> hora = const Value.absent(),
                Value<DateTime> modificadoEn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GimPlanDiasCompanion(
                personaId: personaId,
                diaSemana: diaSemana,
                tipo: tipo,
                version: version,
                hora: hora,
                modificadoEn: modificadoEn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String personaId,
                required int diaSemana,
                required String tipo,
                Value<String> version = const Value.absent(),
                Value<String?> hora = const Value.absent(),
                required DateTime modificadoEn,
                Value<int> rowid = const Value.absent(),
              }) => GimPlanDiasCompanion.insert(
                personaId: personaId,
                diaSemana: diaSemana,
                tipo: tipo,
                version: version,
                hora: hora,
                modificadoEn: modificadoEn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GimPlanDiasTable, GimPlanDiaFila>(table),
                  BaseReferences<
                    _$BaseLocal,
                    $GimPlanDiasTable,
                    GimPlanDiaFila
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GimPlanDiasTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseLocal,
      $GimPlanDiasTable,
      GimPlanDiaFila,
      $$GimPlanDiasTableFilterComposer,
      $$GimPlanDiasTableOrderingComposer,
      $$GimPlanDiasTableAnnotationComposer,
      $$GimPlanDiasTableCreateCompanionBuilder,
      $$GimPlanDiasTableUpdateCompanionBuilder,
      (
        GimPlanDiaFila,
        BaseReferences<_$BaseLocal, $GimPlanDiasTable, GimPlanDiaFila>,
      ),
      GimPlanDiaFila,
      PrefetchHooks Function()
    >;
typedef $$GimInventarioTableCreateCompanionBuilder =
    GimInventarioCompanion Function({
      required String personaId,
      required String itemId,
      required String estado,
      Value<String> confirmado,
      Value<String?> notas,
      required DateTime modificadoEn,
      Value<int> rowid,
    });
typedef $$GimInventarioTableUpdateCompanionBuilder =
    GimInventarioCompanion Function({
      Value<String> personaId,
      Value<String> itemId,
      Value<String> estado,
      Value<String> confirmado,
      Value<String?> notas,
      Value<DateTime> modificadoEn,
      Value<int> rowid,
    });

class $$GimInventarioTableFilterComposer
    extends Composer<_$BaseLocal, $GimInventarioTable> {
  $$GimInventarioTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmado => $composableBuilder(
    column: $table.confirmado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notas => $composableBuilder(
    column: $table.notas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GimInventarioTableOrderingComposer
    extends Composer<_$BaseLocal, $GimInventarioTable> {
  $$GimInventarioTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmado => $composableBuilder(
    column: $table.confirmado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notas => $composableBuilder(
    column: $table.notas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GimInventarioTableAnnotationComposer
    extends Composer<_$BaseLocal, $GimInventarioTable> {
  $$GimInventarioTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get personaId =>
      $composableBuilder(column: $table.personaId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<String> get confirmado => $composableBuilder(
    column: $table.confirmado,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notas =>
      $composableBuilder(column: $table.notas, builder: (column) => column);

  GeneratedColumn<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => column,
  );
}

class $$GimInventarioTableTableManager
    extends
        RootTableManager<
          _$BaseLocal,
          $GimInventarioTable,
          GimInventarioFila,
          $$GimInventarioTableFilterComposer,
          $$GimInventarioTableOrderingComposer,
          $$GimInventarioTableAnnotationComposer,
          $$GimInventarioTableCreateCompanionBuilder,
          $$GimInventarioTableUpdateCompanionBuilder,
          (
            GimInventarioFila,
            BaseReferences<_$BaseLocal, $GimInventarioTable, GimInventarioFila>,
          ),
          GimInventarioFila,
          PrefetchHooks Function()
        > {
  $$GimInventarioTableTableManager(_$BaseLocal db, $GimInventarioTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GimInventarioTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GimInventarioTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GimInventarioTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> personaId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> estado = const Value.absent(),
                Value<String> confirmado = const Value.absent(),
                Value<String?> notas = const Value.absent(),
                Value<DateTime> modificadoEn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GimInventarioCompanion(
                personaId: personaId,
                itemId: itemId,
                estado: estado,
                confirmado: confirmado,
                notas: notas,
                modificadoEn: modificadoEn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String personaId,
                required String itemId,
                required String estado,
                Value<String> confirmado = const Value.absent(),
                Value<String?> notas = const Value.absent(),
                required DateTime modificadoEn,
                Value<int> rowid = const Value.absent(),
              }) => GimInventarioCompanion.insert(
                personaId: personaId,
                itemId: itemId,
                estado: estado,
                confirmado: confirmado,
                notas: notas,
                modificadoEn: modificadoEn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GimInventarioTable, GimInventarioFila>(table),
                  BaseReferences<
                    _$BaseLocal,
                    $GimInventarioTable,
                    GimInventarioFila
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GimInventarioTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseLocal,
      $GimInventarioTable,
      GimInventarioFila,
      $$GimInventarioTableFilterComposer,
      $$GimInventarioTableOrderingComposer,
      $$GimInventarioTableAnnotationComposer,
      $$GimInventarioTableCreateCompanionBuilder,
      $$GimInventarioTableUpdateCompanionBuilder,
      (
        GimInventarioFila,
        BaseReferences<_$BaseLocal, $GimInventarioTable, GimInventarioFila>,
      ),
      GimInventarioFila,
      PrefetchHooks Function()
    >;
typedef $$GimBandasTableCreateCompanionBuilder = GimBandasCompanion Function({
  required String id,
  required String personaId,
  required String nombre,
  required int orden,
  Value<int?> resistenciaKgX10,
  required int cantidad,
  Value<bool> activa,
  required DateTime modificadoEn,
  Value<int> rowid,
});
typedef $$GimBandasTableUpdateCompanionBuilder = GimBandasCompanion Function({
  Value<String> id,
  Value<String> personaId,
  Value<String> nombre,
  Value<int> orden,
  Value<int?> resistenciaKgX10,
  Value<int> cantidad,
  Value<bool> activa,
  Value<DateTime> modificadoEn,
  Value<int> rowid,
});

class $$GimBandasTableFilterComposer
    extends Composer<_$BaseLocal, $GimBandasTable> {
  $$GimBandasTableFilterComposer({
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

  ColumnFilters<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orden => $composableBuilder(
    column: $table.orden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resistenciaKgX10 => $composableBuilder(
    column: $table.resistenciaKgX10,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cantidad => $composableBuilder(
    column: $table.cantidad,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get activa => $composableBuilder(
    column: $table.activa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GimBandasTableOrderingComposer
    extends Composer<_$BaseLocal, $GimBandasTable> {
  $$GimBandasTableOrderingComposer({
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

  ColumnOrderings<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orden => $composableBuilder(
    column: $table.orden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resistenciaKgX10 => $composableBuilder(
    column: $table.resistenciaKgX10,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cantidad => $composableBuilder(
    column: $table.cantidad,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get activa => $composableBuilder(
    column: $table.activa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GimBandasTableAnnotationComposer
    extends Composer<_$BaseLocal, $GimBandasTable> {
  $$GimBandasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get personaId =>
      $composableBuilder(column: $table.personaId, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<int> get orden =>
      $composableBuilder(column: $table.orden, builder: (column) => column);

  GeneratedColumn<int> get resistenciaKgX10 => $composableBuilder(
    column: $table.resistenciaKgX10,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cantidad =>
      $composableBuilder(column: $table.cantidad, builder: (column) => column);

  GeneratedColumn<bool> get activa =>
      $composableBuilder(column: $table.activa, builder: (column) => column);

  GeneratedColumn<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => column,
  );
}

class $$GimBandasTableTableManager
    extends
        RootTableManager<
          _$BaseLocal,
          $GimBandasTable,
          GimBandaFila,
          $$GimBandasTableFilterComposer,
          $$GimBandasTableOrderingComposer,
          $$GimBandasTableAnnotationComposer,
          $$GimBandasTableCreateCompanionBuilder,
          $$GimBandasTableUpdateCompanionBuilder,
          (
            GimBandaFila,
            BaseReferences<_$BaseLocal, $GimBandasTable, GimBandaFila>,
          ),
          GimBandaFila,
          PrefetchHooks Function()
        > {
  $$GimBandasTableTableManager(_$BaseLocal db, $GimBandasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GimBandasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GimBandasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GimBandasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> personaId = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<int> orden = const Value.absent(),
                Value<int?> resistenciaKgX10 = const Value.absent(),
                Value<int> cantidad = const Value.absent(),
                Value<bool> activa = const Value.absent(),
                Value<DateTime> modificadoEn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GimBandasCompanion(
                id: id,
                personaId: personaId,
                nombre: nombre,
                orden: orden,
                resistenciaKgX10: resistenciaKgX10,
                cantidad: cantidad,
                activa: activa,
                modificadoEn: modificadoEn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String personaId,
                required String nombre,
                required int orden,
                Value<int?> resistenciaKgX10 = const Value.absent(),
                required int cantidad,
                Value<bool> activa = const Value.absent(),
                required DateTime modificadoEn,
                Value<int> rowid = const Value.absent(),
              }) => GimBandasCompanion.insert(
                id: id,
                personaId: personaId,
                nombre: nombre,
                orden: orden,
                resistenciaKgX10: resistenciaKgX10,
                cantidad: cantidad,
                activa: activa,
                modificadoEn: modificadoEn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GimBandasTable, GimBandaFila>(table),
                  BaseReferences<_$BaseLocal, $GimBandasTable, GimBandaFila>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GimBandasTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseLocal,
      $GimBandasTable,
      GimBandaFila,
      $$GimBandasTableFilterComposer,
      $$GimBandasTableOrderingComposer,
      $$GimBandasTableAnnotationComposer,
      $$GimBandasTableCreateCompanionBuilder,
      $$GimBandasTableUpdateCompanionBuilder,
      (
        GimBandaFila,
        BaseReferences<_$BaseLocal, $GimBandasTable, GimBandaFila>,
      ),
      GimBandaFila,
      PrefetchHooks Function()
    >;
typedef $$GimSesionesTableCreateCompanionBuilder =
    GimSesionesCompanion Function({
      required String id,
      required String personaId,
      required String fecha,
      required String plantilla,
      required String version,
      required String semanaTipo,
      required String ventana,
      Value<String?> bloqueId,
      required DateTime inicio,
      Value<DateTime?> fin,
      required String estado,
      Value<int?> esfuerzo,
      Value<int?> energia,
      Value<String> plan,
      required int catalogoVersion,
      Value<String?> tiempos,
      required DateTime modificadoEn,
      Value<int> rowid,
    });
typedef $$GimSesionesTableUpdateCompanionBuilder =
    GimSesionesCompanion Function({
      Value<String> id,
      Value<String> personaId,
      Value<String> fecha,
      Value<String> plantilla,
      Value<String> version,
      Value<String> semanaTipo,
      Value<String> ventana,
      Value<String?> bloqueId,
      Value<DateTime> inicio,
      Value<DateTime?> fin,
      Value<String> estado,
      Value<int?> esfuerzo,
      Value<int?> energia,
      Value<String> plan,
      Value<int> catalogoVersion,
      Value<String?> tiempos,
      Value<DateTime> modificadoEn,
      Value<int> rowid,
    });

class $$GimSesionesTableFilterComposer
    extends Composer<_$BaseLocal, $GimSesionesTable> {
  $$GimSesionesTableFilterComposer({
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

  ColumnFilters<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plantilla => $composableBuilder(
    column: $table.plantilla,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semanaTipo => $composableBuilder(
    column: $table.semanaTipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ventana => $composableBuilder(
    column: $table.ventana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bloqueId => $composableBuilder(
    column: $table.bloqueId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get inicio => $composableBuilder(
    column: $table.inicio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fin => $composableBuilder(
    column: $table.fin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get esfuerzo => $composableBuilder(
    column: $table.esfuerzo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get energia => $composableBuilder(
    column: $table.energia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plan => $composableBuilder(
    column: $table.plan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get catalogoVersion => $composableBuilder(
    column: $table.catalogoVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tiempos => $composableBuilder(
    column: $table.tiempos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GimSesionesTableOrderingComposer
    extends Composer<_$BaseLocal, $GimSesionesTable> {
  $$GimSesionesTableOrderingComposer({
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

  ColumnOrderings<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plantilla => $composableBuilder(
    column: $table.plantilla,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semanaTipo => $composableBuilder(
    column: $table.semanaTipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ventana => $composableBuilder(
    column: $table.ventana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bloqueId => $composableBuilder(
    column: $table.bloqueId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get inicio => $composableBuilder(
    column: $table.inicio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fin => $composableBuilder(
    column: $table.fin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get esfuerzo => $composableBuilder(
    column: $table.esfuerzo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get energia => $composableBuilder(
    column: $table.energia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plan => $composableBuilder(
    column: $table.plan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get catalogoVersion => $composableBuilder(
    column: $table.catalogoVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tiempos => $composableBuilder(
    column: $table.tiempos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GimSesionesTableAnnotationComposer
    extends Composer<_$BaseLocal, $GimSesionesTable> {
  $$GimSesionesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get personaId =>
      $composableBuilder(column: $table.personaId, builder: (column) => column);

  GeneratedColumn<String> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);

  GeneratedColumn<String> get plantilla =>
      $composableBuilder(column: $table.plantilla, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get semanaTipo => $composableBuilder(
    column: $table.semanaTipo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ventana =>
      $composableBuilder(column: $table.ventana, builder: (column) => column);

  GeneratedColumn<String> get bloqueId =>
      $composableBuilder(column: $table.bloqueId, builder: (column) => column);

  GeneratedColumn<DateTime> get inicio =>
      $composableBuilder(column: $table.inicio, builder: (column) => column);

  GeneratedColumn<DateTime> get fin =>
      $composableBuilder(column: $table.fin, builder: (column) => column);

  GeneratedColumn<String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<int> get esfuerzo =>
      $composableBuilder(column: $table.esfuerzo, builder: (column) => column);

  GeneratedColumn<int> get energia =>
      $composableBuilder(column: $table.energia, builder: (column) => column);

  GeneratedColumn<String> get plan =>
      $composableBuilder(column: $table.plan, builder: (column) => column);

  GeneratedColumn<int> get catalogoVersion => $composableBuilder(
    column: $table.catalogoVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tiempos =>
      $composableBuilder(column: $table.tiempos, builder: (column) => column);

  GeneratedColumn<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => column,
  );
}

class $$GimSesionesTableTableManager
    extends
        RootTableManager<
          _$BaseLocal,
          $GimSesionesTable,
          GimSesionFila,
          $$GimSesionesTableFilterComposer,
          $$GimSesionesTableOrderingComposer,
          $$GimSesionesTableAnnotationComposer,
          $$GimSesionesTableCreateCompanionBuilder,
          $$GimSesionesTableUpdateCompanionBuilder,
          (
            GimSesionFila,
            BaseReferences<_$BaseLocal, $GimSesionesTable, GimSesionFila>,
          ),
          GimSesionFila,
          PrefetchHooks Function()
        > {
  $$GimSesionesTableTableManager(_$BaseLocal db, $GimSesionesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GimSesionesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GimSesionesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GimSesionesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> personaId = const Value.absent(),
                Value<String> fecha = const Value.absent(),
                Value<String> plantilla = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> semanaTipo = const Value.absent(),
                Value<String> ventana = const Value.absent(),
                Value<String?> bloqueId = const Value.absent(),
                Value<DateTime> inicio = const Value.absent(),
                Value<DateTime?> fin = const Value.absent(),
                Value<String> estado = const Value.absent(),
                Value<int?> esfuerzo = const Value.absent(),
                Value<int?> energia = const Value.absent(),
                Value<String> plan = const Value.absent(),
                Value<int> catalogoVersion = const Value.absent(),
                Value<String?> tiempos = const Value.absent(),
                Value<DateTime> modificadoEn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GimSesionesCompanion(
                id: id,
                personaId: personaId,
                fecha: fecha,
                plantilla: plantilla,
                version: version,
                semanaTipo: semanaTipo,
                ventana: ventana,
                bloqueId: bloqueId,
                inicio: inicio,
                fin: fin,
                estado: estado,
                esfuerzo: esfuerzo,
                energia: energia,
                plan: plan,
                catalogoVersion: catalogoVersion,
                tiempos: tiempos,
                modificadoEn: modificadoEn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String personaId,
                required String fecha,
                required String plantilla,
                required String version,
                required String semanaTipo,
                required String ventana,
                Value<String?> bloqueId = const Value.absent(),
                required DateTime inicio,
                Value<DateTime?> fin = const Value.absent(),
                required String estado,
                Value<int?> esfuerzo = const Value.absent(),
                Value<int?> energia = const Value.absent(),
                Value<String> plan = const Value.absent(),
                required int catalogoVersion,
                Value<String?> tiempos = const Value.absent(),
                required DateTime modificadoEn,
                Value<int> rowid = const Value.absent(),
              }) => GimSesionesCompanion.insert(
                id: id,
                personaId: personaId,
                fecha: fecha,
                plantilla: plantilla,
                version: version,
                semanaTipo: semanaTipo,
                ventana: ventana,
                bloqueId: bloqueId,
                inicio: inicio,
                fin: fin,
                estado: estado,
                esfuerzo: esfuerzo,
                energia: energia,
                plan: plan,
                catalogoVersion: catalogoVersion,
                tiempos: tiempos,
                modificadoEn: modificadoEn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GimSesionesTable, GimSesionFila>(table),
                  BaseReferences<_$BaseLocal, $GimSesionesTable, GimSesionFila>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GimSesionesTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseLocal,
      $GimSesionesTable,
      GimSesionFila,
      $$GimSesionesTableFilterComposer,
      $$GimSesionesTableOrderingComposer,
      $$GimSesionesTableAnnotationComposer,
      $$GimSesionesTableCreateCompanionBuilder,
      $$GimSesionesTableUpdateCompanionBuilder,
      (
        GimSesionFila,
        BaseReferences<_$BaseLocal, $GimSesionesTable, GimSesionFila>,
      ),
      GimSesionFila,
      PrefetchHooks Function()
    >;
typedef $$GimSeriesTableCreateCompanionBuilder = GimSeriesCompanion Function({
  required String id,
  required String personaId,
  required String sesionId,
  required String ejercicioId,
  required String varianteId,
  required int n,
  Value<String?> lado,
  Value<int?> reps,
  Value<int?> segundos,
  Value<int?> cargaPasos,
  Value<String?> bandaId,
  Value<int?> esfuerzo,
  Value<int?> descansoRealS,
  Value<String?> sustituyeA,
  Value<String?> motivoCambio,
  required DateTime modificadoEn,
  Value<int> rowid,
});
typedef $$GimSeriesTableUpdateCompanionBuilder = GimSeriesCompanion Function({
  Value<String> id,
  Value<String> personaId,
  Value<String> sesionId,
  Value<String> ejercicioId,
  Value<String> varianteId,
  Value<int> n,
  Value<String?> lado,
  Value<int?> reps,
  Value<int?> segundos,
  Value<int?> cargaPasos,
  Value<String?> bandaId,
  Value<int?> esfuerzo,
  Value<int?> descansoRealS,
  Value<String?> sustituyeA,
  Value<String?> motivoCambio,
  Value<DateTime> modificadoEn,
  Value<int> rowid,
});

class $$GimSeriesTableFilterComposer
    extends Composer<_$BaseLocal, $GimSeriesTable> {
  $$GimSeriesTableFilterComposer({
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

  ColumnFilters<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sesionId => $composableBuilder(
    column: $table.sesionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ejercicioId => $composableBuilder(
    column: $table.ejercicioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get varianteId => $composableBuilder(
    column: $table.varianteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get n => $composableBuilder(
    column: $table.n,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lado => $composableBuilder(
    column: $table.lado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segundos => $composableBuilder(
    column: $table.segundos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cargaPasos => $composableBuilder(
    column: $table.cargaPasos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bandaId => $composableBuilder(
    column: $table.bandaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get esfuerzo => $composableBuilder(
    column: $table.esfuerzo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get descansoRealS => $composableBuilder(
    column: $table.descansoRealS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sustituyeA => $composableBuilder(
    column: $table.sustituyeA,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get motivoCambio => $composableBuilder(
    column: $table.motivoCambio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GimSeriesTableOrderingComposer
    extends Composer<_$BaseLocal, $GimSeriesTable> {
  $$GimSeriesTableOrderingComposer({
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

  ColumnOrderings<String> get personaId => $composableBuilder(
    column: $table.personaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sesionId => $composableBuilder(
    column: $table.sesionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ejercicioId => $composableBuilder(
    column: $table.ejercicioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get varianteId => $composableBuilder(
    column: $table.varianteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get n => $composableBuilder(
    column: $table.n,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lado => $composableBuilder(
    column: $table.lado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segundos => $composableBuilder(
    column: $table.segundos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cargaPasos => $composableBuilder(
    column: $table.cargaPasos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bandaId => $composableBuilder(
    column: $table.bandaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get esfuerzo => $composableBuilder(
    column: $table.esfuerzo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get descansoRealS => $composableBuilder(
    column: $table.descansoRealS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sustituyeA => $composableBuilder(
    column: $table.sustituyeA,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get motivoCambio => $composableBuilder(
    column: $table.motivoCambio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GimSeriesTableAnnotationComposer
    extends Composer<_$BaseLocal, $GimSeriesTable> {
  $$GimSeriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get personaId =>
      $composableBuilder(column: $table.personaId, builder: (column) => column);

  GeneratedColumn<String> get sesionId =>
      $composableBuilder(column: $table.sesionId, builder: (column) => column);

  GeneratedColumn<String> get ejercicioId => $composableBuilder(
    column: $table.ejercicioId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get varianteId => $composableBuilder(
    column: $table.varianteId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get n =>
      $composableBuilder(column: $table.n, builder: (column) => column);

  GeneratedColumn<String> get lado =>
      $composableBuilder(column: $table.lado, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get segundos =>
      $composableBuilder(column: $table.segundos, builder: (column) => column);

  GeneratedColumn<int> get cargaPasos => $composableBuilder(
    column: $table.cargaPasos,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bandaId =>
      $composableBuilder(column: $table.bandaId, builder: (column) => column);

  GeneratedColumn<int> get esfuerzo =>
      $composableBuilder(column: $table.esfuerzo, builder: (column) => column);

  GeneratedColumn<int> get descansoRealS => $composableBuilder(
    column: $table.descansoRealS,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sustituyeA => $composableBuilder(
    column: $table.sustituyeA,
    builder: (column) => column,
  );

  GeneratedColumn<String> get motivoCambio => $composableBuilder(
    column: $table.motivoCambio,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get modificadoEn => $composableBuilder(
    column: $table.modificadoEn,
    builder: (column) => column,
  );
}

class $$GimSeriesTableTableManager
    extends
        RootTableManager<
          _$BaseLocal,
          $GimSeriesTable,
          GimSerieFila,
          $$GimSeriesTableFilterComposer,
          $$GimSeriesTableOrderingComposer,
          $$GimSeriesTableAnnotationComposer,
          $$GimSeriesTableCreateCompanionBuilder,
          $$GimSeriesTableUpdateCompanionBuilder,
          (
            GimSerieFila,
            BaseReferences<_$BaseLocal, $GimSeriesTable, GimSerieFila>,
          ),
          GimSerieFila,
          PrefetchHooks Function()
        > {
  $$GimSeriesTableTableManager(_$BaseLocal db, $GimSeriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GimSeriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GimSeriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GimSeriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> personaId = const Value.absent(),
                Value<String> sesionId = const Value.absent(),
                Value<String> ejercicioId = const Value.absent(),
                Value<String> varianteId = const Value.absent(),
                Value<int> n = const Value.absent(),
                Value<String?> lado = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<int?> segundos = const Value.absent(),
                Value<int?> cargaPasos = const Value.absent(),
                Value<String?> bandaId = const Value.absent(),
                Value<int?> esfuerzo = const Value.absent(),
                Value<int?> descansoRealS = const Value.absent(),
                Value<String?> sustituyeA = const Value.absent(),
                Value<String?> motivoCambio = const Value.absent(),
                Value<DateTime> modificadoEn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GimSeriesCompanion(
                id: id,
                personaId: personaId,
                sesionId: sesionId,
                ejercicioId: ejercicioId,
                varianteId: varianteId,
                n: n,
                lado: lado,
                reps: reps,
                segundos: segundos,
                cargaPasos: cargaPasos,
                bandaId: bandaId,
                esfuerzo: esfuerzo,
                descansoRealS: descansoRealS,
                sustituyeA: sustituyeA,
                motivoCambio: motivoCambio,
                modificadoEn: modificadoEn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String personaId,
                required String sesionId,
                required String ejercicioId,
                required String varianteId,
                required int n,
                Value<String?> lado = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<int?> segundos = const Value.absent(),
                Value<int?> cargaPasos = const Value.absent(),
                Value<String?> bandaId = const Value.absent(),
                Value<int?> esfuerzo = const Value.absent(),
                Value<int?> descansoRealS = const Value.absent(),
                Value<String?> sustituyeA = const Value.absent(),
                Value<String?> motivoCambio = const Value.absent(),
                required DateTime modificadoEn,
                Value<int> rowid = const Value.absent(),
              }) => GimSeriesCompanion.insert(
                id: id,
                personaId: personaId,
                sesionId: sesionId,
                ejercicioId: ejercicioId,
                varianteId: varianteId,
                n: n,
                lado: lado,
                reps: reps,
                segundos: segundos,
                cargaPasos: cargaPasos,
                bandaId: bandaId,
                esfuerzo: esfuerzo,
                descansoRealS: descansoRealS,
                sustituyeA: sustituyeA,
                motivoCambio: motivoCambio,
                modificadoEn: modificadoEn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GimSeriesTable, GimSerieFila>(table),
                  BaseReferences<_$BaseLocal, $GimSeriesTable, GimSerieFila>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GimSeriesTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseLocal,
      $GimSeriesTable,
      GimSerieFila,
      $$GimSeriesTableFilterComposer,
      $$GimSeriesTableOrderingComposer,
      $$GimSeriesTableAnnotationComposer,
      $$GimSeriesTableCreateCompanionBuilder,
      $$GimSeriesTableUpdateCompanionBuilder,
      (
        GimSerieFila,
        BaseReferences<_$BaseLocal, $GimSeriesTable, GimSerieFila>,
      ),
      GimSerieFila,
      PrefetchHooks Function()
    >;

class $BaseLocalManager {
  final _$BaseLocal _db;
  $BaseLocalManager(this._db);
  $$PendientesTableTableManager get pendientes =>
      $$PendientesTableTableManager(_db, _db.pendientes);
  $$GimPerfilTableTableManager get gimPerfil =>
      $$GimPerfilTableTableManager(_db, _db.gimPerfil);
  $$GimPlanDiasTableTableManager get gimPlanDias =>
      $$GimPlanDiasTableTableManager(_db, _db.gimPlanDias);
  $$GimInventarioTableTableManager get gimInventario =>
      $$GimInventarioTableTableManager(_db, _db.gimInventario);
  $$GimBandasTableTableManager get gimBandas =>
      $$GimBandasTableTableManager(_db, _db.gimBandas);
  $$GimSesionesTableTableManager get gimSesiones =>
      $$GimSesionesTableTableManager(_db, _db.gimSesiones);
  $$GimSeriesTableTableManager get gimSeries =>
      $$GimSeriesTableTableManager(_db, _db.gimSeries);
}
