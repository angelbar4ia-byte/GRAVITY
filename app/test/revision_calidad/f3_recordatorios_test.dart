// Revisión de calidad de la Fase 3: recordatorios locales de Hábitos (reglas
// 113 a 119, criterios 46 y 47).
//
// F3-7  (hallazgo, menor) Un bloque que empieza poco después de la medianoche
//       (o el cierre del día con "dormir" antes de la 1:00) calcula el
//       recordatorio con minutos negativos: DateTime(.., min ~/ 60, min % 60)
//       lo pone a las 00:40 del MISMO día (después de empezar), no a las 23:40.
// F3-8  (hallazgo, menor) El nombre opcional en el aviso se recorta con
//       substring(0, 40): puede partir un emoji y dejar media pareja de
//       sustitutos (UTF-16 inválido) en el título de la notificación.
// Guardias (pasan): lo sensible siempre es "Recordatorio", sin nombre, por el
// canal reservado y con solo "Posponer 10 min"; silencio 22:00 a 07:00; solo
// 7 días; sin tipos silenciados.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/datos/fuentes_plataforma.dart';
import 'package:gravity/modulos/habitos/datos/modelos_agenda.dart';
import 'package:gravity/modulos/habitos/datos/repositorio_agenda.dart';
import 'package:gravity/nucleo/avisos/aviso.dart';
import 'package:gravity/nucleo/avisos/catalogo_avisos.dart';
import 'package:gravity/nucleo/avisos/notificador.dart';
import 'package:gravity/nucleo/avisos/recordatorios_habitos.dart';

void main() {
  test('F3-7: un bloque de las 00:10 con aviso a 30 min se recuerda ANTES de empezar', () async {
    final agenda = RepositorioAgendaEnMemoria();
    await agenda.guardarBloque(
      BloqueHab(
        id: 'b1',
        titulo: 'Bloque',
        area: 'personal',
        inicioMin: 10,
        duracionMin: 30,
        dias: 127,
        desde: DateTime(2026, 11, 1),
        modificadoEn: DateTime(2026, 11, 1),
        recordarMin: 30,
      ),
    );
    final r = await FuenteDeRecordatoriosDeHabitos(
      agenda,
      null,
    ).proximos(desde: DateTime(2026, 11, 2, 12), dias: 3);
    final bloques = r.where((x) => x.tipo == TipoRecordatorioHabito.bloque);
    expect(bloques, isNotEmpty);
    for (final x in bloques) {
      expect(
        x.cuando.hour,
        23,
        reason: 'recordatorio a las ${x.cuando} (el bloque empieza 00:10)',
      );
    }
  });

  test(
    'F3-8: el título con nombre recortado no deja un sustituto UTF-16 suelto',
    () {
      final nombre = '${'a' * 39}😀 resto';
      final t = tituloDeRecordatorio(
        RecordatorioHabito(
          tipo: TipoRecordatorioHabito.bloque,
          objetoId: 'o',
          cuando: DateTime(2026, 11, 3, 9),
          nombreEnAviso: nombre,
        ),
      );
      final ultimo = t.codeUnits.last;
      expect(
        ultimo >= 0xD800 && ultimo <= 0xDBFF,
        isFalse,
        reason: 'termina en medio de un emoji',
      );
    },
  );

  group('guardias', () {
    final ahora = DateTime(2026, 11, 2, 12);
    RecordatorioHabito rec({
      bool sensible = false,
      String? nombre,
      String tipo = TipoRecordatorioHabito.reservado,
      DateTime? cuando,
    }) => RecordatorioHabito(
      tipo: tipo,
      objetoId: 'obj-1',
      cuando: cuando ?? DateTime(2026, 11, 3, 21),
      sensible: sensible,
      nombreEnAviso: nombre,
    );

    test('lo sensible: "Recordatorio", canal reservado, solo Posponer, aunque traiga nombre', () {
      final r = rec(
        sensible: true,
        nombre: 'Dejar de fumar',
        tipo: TipoRecordatorioHabito.cierreDia,
      );
      final n = notificacionDeRecordatorio(r, const PreferenciasAvisos());
      expect(n.titulo, 'Recordatorio');
      expect(n.canal, CanalAviso.habitosReservados);
      expect(n.acciones, [AccionDeNotificacion.posponer10]);
      expect(n.carga, isNot(contains('fumar')));
      expect(claveDeRecordatorio(r), startsWith('hab:hab_reservado:'));
    });

    test('el catálogo de títulos: máximo 40, sin dígitos ni "\$"', () {
      for (final e in titulosDeHabitos.entries) {
        expect(e.value.length <= largoMaximoTituloAviso, isTrue, reason: e.key);
        expect(RegExp(r'[0-9$]').hasMatch(e.value), isFalse, reason: e.value);
      }
    });

    test('silencio 22:00 a 07:00: sin sonido, pero no se cancela', () {
      const p = PreferenciasAvisos();
      expect(sonarEn(p, DateTime(2026, 11, 3, 21, 59)), isTrue);
      expect(sonarEn(p, DateTime(2026, 11, 3, 22)), isFalse);
      expect(sonarEn(p, DateTime(2026, 11, 3, 3)), isFalse);
      expect(sonarEn(p, DateTime(2026, 11, 3, 6, 59)), isFalse);
      expect(sonarEn(p, DateTime(2026, 11, 3, 7)), isTrue);
      final lista = recordatoriosAProgramar(
        candidatos: [rec(cuando: DateTime(2026, 11, 3, 23))],
        preferencias: p,
        ahora: ahora,
      );
      expect(lista, hasLength(1));
    });

    test('solo 7 días, sin pasado y sin tipos silenciados', () {
      final lista = recordatoriosAProgramar(
        candidatos: [
          rec(cuando: DateTime(2026, 11, 2, 11, 59)),
          rec(cuando: DateTime(2026, 11, 9, 12)),
          rec(cuando: DateTime(2026, 11, 9, 12, 1)),
          rec(
            tipo: TipoRecordatorioHabito.lectura,
            cuando: DateTime(2026, 11, 3, 8),
          ),
        ],
        preferencias: const PreferenciasAvisos(
          tiposSilenciados: {TipoRecordatorioHabito.lectura},
        ),
        ahora: ahora,
      );
      expect([for (final r in lista) r.cuando], [DateTime(2026, 11, 9, 12)]);
    });
  });
}
