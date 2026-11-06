/// Agenda, ajustes, revisiones y planes de lectura.
library;

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'modelos_agenda.dart';

/// Un plan de lectura con sus días materializados (regla 81).
class PlanGuardado {
  PlanGuardado({
    required this.id,
    required this.nombre,
    required this.plan,
    required this.inicio,
    this.mascara = 127,
    this.version = 'rvr1909',
    this.libro,
    this.estado = 'activo',
  });
  final String id;
  final String nombre;
  final PlanLectura plan;
  final DateTime inicio;
  final int mascara;
  final String version;
  final int? libro;
  String estado;

  static const _tipos = {
    TipoPlan.rutaInicio: 'ruta_inicio',
    TipoPlan.nt90: 'nt_90',
    TipoPlan.salmosProverbios30: 'salmos_proverbios_30',
    TipoPlan.biblia1Ano: 'biblia_1_ano',
    TipoPlan.libro: 'libro',
  };

  /// Segmentos `{libro, cap_ini, cap_fin}` consecutivos de un día.
  static List<Map<String, Object?>> segmentos(List<Capitulo> caps) {
    final r = <Map<String, Object?>>[];
    for (final c in caps) {
      if (r.isNotEmpty && r.last['libro'] == c.libro && r.last['cap_fin'] == c.cap - 1) {
        r.last['cap_fin'] = c.cap;
      } else {
        r.add({'libro': c.libro, 'cap_ini': c.cap, 'cap_fin': c.cap});
      }
    }
    return r;
  }

  static const _estadosDia = {
    EstadoDiaPlan.pendiente: 'pendiente',
    EstadoDiaPlan.hecho: 'hecho',
    EstadoDiaPlan.parcial: 'parcial',
    EstadoDiaPlan.saltado: 'saltado',
    EstadoDiaPlan.movido: 'saltado', // el servidor no tiene "movido"
  };

  Map<String, Object?> aPlanJson(DateTime ahora) => {
        'id': id,
        'tipo': _tipos[plan.tipo],
        'nombre': nombre,
        'fecha_inicio': inicio.toIso8601String().substring(0, 10),
        'dias_semana': mascara,
        'version_biblica': version,
        'estado': estado,
        'libro': libro,
        'modificado_en': ahora.toUtc().toIso8601String(),
      };

  List<Map<String, Object?>> aDiasJson() => [
        for (final d in plan.dias)
          {
            'dia': d.dia,
            'fecha': d.fecha.toIso8601String().substring(0, 10),
            'segmentos': segmentos(d.capitulos),
            'estado': _estadosDia[d.estado],
          }
      ];
}

abstract interface class RepositorioAgenda {
  Future<List<BloqueHab>> bloques();
  Future<void> guardarBloque(BloqueHab b);
  Future<AjustesHab> ajustes();
  Future<void> guardarAjustes(AjustesHab a, DateTime ahora);
  Future<RevisionHab?> revision(DateTime lunes);
  Future<void> guardarRevision(RevisionHab r);
  Future<List<PlanGuardado>> planes();
  Future<void> crearPlan(PlanGuardado p, DateTime ahora);
  Future<void> guardarDiaPlan(PlanGuardado p, DiaPlan d);
}

class RepositorioAgendaEnMemoria implements RepositorioAgenda {
  final Map<String, BloqueHab> _bloques = {};
  AjustesHab _ajustes = const AjustesHab();
  final Map<DateTime, RevisionHab> _revisiones = {};
  final Map<String, PlanGuardado> _planes = {};

  @override
  Future<List<BloqueHab>> bloques() async => _bloques.values.toList();
  @override
  Future<void> guardarBloque(BloqueHab b) async => _bloques[b.id] = b;
  @override
  Future<AjustesHab> ajustes() async => _ajustes;
  @override
  Future<void> guardarAjustes(AjustesHab a, DateTime ahora) async => _ajustes = a;
  @override
  Future<RevisionHab?> revision(DateTime lunes) async => _revisiones[soloDia(lunes)];
  @override
  Future<void> guardarRevision(RevisionHab r) async => _revisiones[soloDia(r.semana)] = r;
  @override
  Future<List<PlanGuardado>> planes() async => _planes.values.toList();
  @override
  Future<void> crearPlan(PlanGuardado p, DateTime ahora) async => _planes[p.id] = p;
  @override
  Future<void> guardarDiaPlan(PlanGuardado p, DiaPlan d) async {}
}

class RepositorioAgendaSupabase implements RepositorioAgenda {
  RepositorioAgendaSupabase(this._cliente);
  final SupabaseClient Function() _cliente;

  @override
  Future<List<BloqueHab>> bloques() async =>
      [for (final f in await _cliente().from('hab_bloques').select()) BloqueHab.deFila(f)];

  @override
  Future<void> guardarBloque(BloqueHab b) async => _cliente().from('hab_bloques').upsert(b.aFila());

  @override
  Future<AjustesHab> ajustes() async {
    final f = await _cliente().from('hab_ajustes').select().maybeSingle();
    return f == null ? const AjustesHab() : AjustesHab.deFila(f);
  }

  @override
  Future<void> guardarAjustes(AjustesHab a, DateTime ahora) async {
    // La fila la crea el servidor; la app solo hace UPDATE de la propia.
    await _cliente().from('hab_ajustes').update(a.aCambios(ahora)).not('persona_id', 'is', null);
  }

  @override
  Future<RevisionHab?> revision(DateTime lunes) async {
    final f = await _cliente()
        .from('hab_revisiones')
        .select()
        .eq('semana', lunes.toIso8601String().substring(0, 10))
        .maybeSingle();
    if (f == null) return null;
    final est = {
      'pendiente': EstadoRevision.pendiente,
      'en_curso': EstadoRevision.enCurso,
      'completada': EstadoRevision.completada,
      'omitida': EstadoRevision.omitida,
    }[f['estado']]!;
    return RevisionHab(
      id: f['id'] as String,
      semana: DateTime.parse(f['semana'] as String),
      estado: est,
      modificadoEn: DateTime.parse(f['modificado_en'] as String),
      resumen: ((f['resumen'] as Map?) ?? const {}).cast<String, Object?>(),
      ajustes: (f['ajustes'] as List?) ?? const [],
      darCumplido: f['dar_cumplido'] as bool?,
    );
  }

  @override
  Future<void> guardarRevision(RevisionHab r) async =>
      _cliente().from('hab_revisiones').upsert(r.aFila(), onConflict: 'persona_id,semana');

  @override
  Future<List<PlanGuardado>> planes() async {
    final r = <PlanGuardado>[];
    for (final f in await _cliente().from('hab_planes_lectura').select()) {
      final tipo = PlanGuardado._tipos.entries.firstWhere((e) => e.value == f['tipo']).key;
      final filas = await _cliente()
          .from('hab_plan_dias')
          .select()
          .eq('plan_id', f['id'] as String)
          .order('dia');
      final estados = {
        'pendiente': EstadoDiaPlan.pendiente,
        'hecho': EstadoDiaPlan.hecho,
        'parcial': EstadoDiaPlan.parcial,
        'saltado': EstadoDiaPlan.saltado,
      };
      final dias = [
        for (final d in filas)
          DiaPlan(
            d['dia'] as int,
            DateTime.parse(d['fecha'] as String),
            [
              for (final sg in (d['segmentos'] as List).cast<Map>())
                for (var c = sg['cap_ini'] as int; c <= (sg['cap_fin'] as int); c++)
                  Capitulo(sg['libro'] as int, c)
            ],
            estados[d['estado']] ?? EstadoDiaPlan.pendiente,
          )
      ];
      r.add(PlanGuardado(
        id: f['id'] as String,
        nombre: f['nombre'] as String,
        plan: PlanLectura(tipo, dias),
        inicio: DateTime.parse(f['fecha_inicio'] as String),
        mascara: f['dias_semana'] as int,
        version: f['version_biblica'] as String,
        libro: f['libro'] as int?,
        estado: f['estado'] as String,
      ));
    }
    return r;
  }

  @override
  Future<void> crearPlan(PlanGuardado p, DateTime ahora) async => _cliente()
      .rpc('hab_crear_plan_lectura', params: {'p_plan': p.aPlanJson(ahora), 'p_dias': p.aDiasJson()});

  @override
  Future<void> guardarDiaPlan(PlanGuardado p, DiaPlan d) async => _cliente().from('hab_plan_dias').upsert({
        'plan_id': p.id,
        'dia': d.dia,
        'fecha': d.fecha.toIso8601String().substring(0, 10),
        'segmentos': PlanGuardado.segmentos(d.capitulos),
        'estado': PlanGuardado._estadosDia[d.estado],
        'hecho_en': d.estado == EstadoDiaPlan.hecho ? DateTime.now().toUtc().toIso8601String() : null,
      });
}
