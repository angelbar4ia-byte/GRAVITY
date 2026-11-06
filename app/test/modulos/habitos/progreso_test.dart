import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_agenda.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_diario.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_eliminar.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_habitos.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_progreso.dart';
import 'package:gravity/modulos/habitos/datos/documentos_sensibles.dart';
import 'package:gravity/modulos/habitos/datos/fuentes_plataforma.dart';
import 'package:gravity/modulos/habitos/datos/repositorio.dart';
import 'package:gravity/modulos/habitos/datos/repositorio_agenda.dart';
import 'package:gravity/nucleo/avisos/recordatorios_habitos.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/sobres.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

void main() {
  late DateTime ahora;
  late RepositorioHabitosEnMemoria repo;
  late RepositorioAgendaEnMemoria agenda;
  late AlmacenSeguroEnMemoria almacen;
  late DocumentosSensibles docs;

  setUp(() {
    ahora = DateTime.utc(2026, 11, 7, 10); // sábado
    repo = RepositorioHabitosEnMemoria();
    agenda = RepositorioAgendaEnMemoria();
    almacen = AlmacenSeguroEnMemoria();
    docs = DocumentosSensibles(
      llaves: LlavesHabitos(almacen),
      sobres: AlmacenDeSobres(almacen),
      modos: ModosLocales(almacen),
      persona: 'ana',
      ahora: () => ahora,
    );
  });

  test('cumplimiento por área y sin dato; calendario de constancia', () async {
    final h = ServicioHabitos(repo, ahora: () => ahora);
    final o = await h.crearObjetivo(
      titulo: 'Leer',
      area: 'personal',
      inicio: DateTime.utc(2026, 11, 2),
    );
    await h.crearObjetivo(
      titulo: 'Orar',
      area: 'espiritual',
      inicio: DateTime.utc(2026, 11, 9),
    ); // aún no empieza
    for (final d in [2, 3, 4, 6]) {
      await h.marcarHecho(o, fecha: DateTime.utc(2026, 11, d));
    }
    final p = ServicioProgreso(repo, agenda, ahora: () => ahora);
    final c = await p.cumplimientoPorArea(DateTime.utc(2026, 11, 2));
    expect(c['personal'], 66); // 4 de 6 días transcurridos (lun a sáb)
    expect(c.containsKey('espiritual'), isFalse);
    final (racha, dias) = await p.constancia(dias: 7);
    expect(dias.length, 7);
    expect(dias.last.hoy, isTrue);
    expect(racha.estados[DateTime.utc(2026, 11, 5)], EstadoDia.gracia);
    expect(
      racha.actual,
      4,
    ); // lun, mar, mié, vie con la gracia del jueves; hoy sábado abierto
  });

  test(
    'revisión: programación sábado 14:30 con aviso 14:15; completar y omitir',
    () async {
      final diario = ServicioDiario(docs, ahora: () => ahora);
      final p = ServicioProgreso(repo, agenda, ahora: () => ahora);
      final r = ServicioRevision(agenda, p, diario, ahora: () => ahora);
      final (pre, ya) = await r.programacion();
      expect([pre.weekday, pre.hour, pre.minute], [6, 14, 15]);
      expect([ya.hour, ya.minute], [14, 30]);
      expect(r.vigente(), isTrue);
      final hecho = await r.completar(
        respuestas: {'aprendi': 'RESPUESTA_PRIVADA'},
      );
      expect(hecho.estado, EstadoRevision.completada);
      expect((await r.estado())!.estado, EstadoRevision.completada);
      expect(almacen.datos.values.join(), isNot(contains('RESPUESTA_PRIVADA')));
      expect(hecho.aFila().containsKey('persona_id'), isFalse);
      await r.omitir();
      expect((await r.estado())!.estado, EstadoRevision.omitida);
    },
  );

  test(
    'exportar: datos en claro y sensibles descifrados solo en memoria',
    () async {
      final h = ServicioHabitos(repo, ahora: () => ahora);
      await h.crearObjetivo(titulo: 'Leer', area: 'personal');
      final e = ServicioHabitoEliminar(docs, ahora: () => ahora);
      await e.configurar(
        ConfigHabito(
          tipo: TipoHabito.cigarrillo,
          inicio: DateTime.utc(2026, 11, 2),
        ),
      );
      final f = FuenteDeDatosDeHabitos(repo, agenda, docs, ahora: () => ahora);
      final claro = await f.datosEnClaro();
      expect((claro['objetivos']! as List).length, 1);
      expect(claro.toString(), isNot(contains('cigarrillo')));
      final s = await f.datosSensibles(TipoSensible.habitosSensibles);
      expect(s.toString(), contains('cigarrillo'));
      expect(
        await FuenteDeDatosDeHabitos(
          repo,
          agenda,
          null,
        ).datosSensibles(TipoSensible.diarioOracion),
        isEmpty,
      );
    },
  );

  test(
    'recordatorios: bloques, revisión y lo reservado siempre genérico',
    () async {
      final a = ServicioAgenda(agenda, repo, ahora: () => ahora);
      await a.crearBloque(
        titulo: 'Inglés',
        area: 'educacion',
        inicioMin: 1200,
        duracionMin: 30,
        recordarMin: 10,
        desde: DateTime.utc(2026, 11, 7),
      );
      await ServicioHabitoEliminar(docs, ahora: () => ahora).configurar(
        ConfigHabito(
          tipo: TipoHabito.azucar,
          inicio: DateTime.utc(2026, 11, 2),
          limiteOcasional: 3,
        ),
      );
      final f = FuenteDeRecordatoriosDeHabitos(
        agenda,
        ServicioHabitoEliminar(docs, ahora: () => ahora),
      );
      final r = await f.proximos(desde: DateTime(2026, 11, 7, 0), dias: 2);
      expect(r.where((x) => x.tipo == TipoRecordatorioHabito.bloque).length, 2);
      expect(
        r
            .where((x) => x.tipo == TipoRecordatorioHabito.revisionPre)
            .single
            .cuando,
        DateTime(2026, 11, 7, 14, 15),
      );
      final reservados = r.where((x) => x.sensible);
      expect(reservados.length, 2);
      expect(
        reservados.every(
          (x) =>
              x.tipo == TipoRecordatorioHabito.reservado &&
              x.nombreEnAviso == null,
        ),
        isTrue,
      );
    },
  );
}
