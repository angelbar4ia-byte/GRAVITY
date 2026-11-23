// CA-G-35 (parte de la notificación): «Termina tu descanso» se programa al
// iniciar el descanso y se cancela si se salta, se ajusta o termina la sesión;
// usa el texto discreto del catálogo (sin nombres ni datos, sin dígitos, ≤ 40
// caracteres, cuerpo vacío); solo en el teléfono y la tablet personal; no pide
// permiso a media sesión. El temporizador de diseno (DescansoPlanificado)
// alimenta al servicio con su instante final.
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/gimnasio/temporizador_descanso.dart'
    show DescansoPlanificado;
import 'package:gravity/nucleo/avisos/aviso.dart' show PreferenciasAvisos;
import 'package:gravity/nucleo/avisos/aviso_descanso.dart';
import 'package:gravity/nucleo/avisos/catalogo_avisos.dart';
import 'package:gravity/nucleo/avisos/notificador.dart';
import 'package:gravity/nucleo/avisos/recordatorios_habitos.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart'
    show TipoEquipoAvisos;
import 'package:gravity/nucleo/avisos/servicio_avisos.dart' show ContextoAvisos;
import 'package:habitos_dominio/habitos_dominio.dart' show TextoAvisoGimnasio;

void main() {
  late NotificadorEnMemoria notificador;
  late DateTime ahora;
  late ContextoAvisos contexto;
  late PreferenciasAvisos prefs;
  late bool recordatoriosActivos;

  ServicioAvisoDescanso servicio() => ServicioAvisoDescanso(
    notificador: notificador,
    contexto: () => contexto,
    preferencias: () async => prefs,
    activado: () async => recordatoriosActivos,
    ahora: () => ahora,
  );

  setUp(() {
    notificador = NotificadorEnMemoria();
    // Lunes 23/nov/2026, 19:30.
    ahora = DateTime(2026, 11, 23, 19, 30);
    contexto = const ContextoAvisos(
      tipo: TipoEquipoAvisos.telefono,
      personaId: 'ana',
      usaHabitos: true,
    );
    prefs = const PreferenciasAvisos();
    recordatoriosActivos = true;
  });

  group('programar y cancelar', () {
    test(
      'se programa para el instante final con el texto del catálogo',
      () async {
        final s = servicio();
        final fin = ahora.add(const Duration(seconds: 60));
        expect(await s.programar(fin), isTrue);
        final p = notificador.programadas.values.single;
        expect(p.cuando, fin);
        expect(p.notificacion.titulo, 'Termina tu descanso');
        expect(p.notificacion.titulo, TextoAvisoGimnasio.descanso);
        expect(
          TextoAvisoGimnasio.porTipo['hab_descanso'],
          p.notificacion.titulo,
        );
        expect(p.notificacion.cuerpo, isEmpty);
        expect(p.notificacion.id, idNotificacionDescanso);
        expect(p.notificacion.canal, CanalAviso.habitosRecordatorios);
        expect(p.notificacion.acciones, isEmpty);
        expect(s.programadoPara, fin);
      },
    );

    test('discreta: sin dígitos, sin nombres ni cargas, ≤ 40 caracteres; la carga tampoco lleva datos', () async {
      await servicio().programar(ahora.add(const Duration(minutes: 1)));
      final n = notificador.programadas.values.single.notificacion;
      expect(textoDeAvisoEsDiscreto(n.titulo), isTrue);
      expect(n.titulo.length, lessThanOrEqualTo(largoMaximoTituloAviso));
      expect(RegExp(r'\d').hasMatch(n.titulo), isFalse);
      // Es un texto del catálogo de Hábitos, no de un ejercicio.
      expect(titulosDeHabitos[TipoRecordatorioHabito.descanso], n.titulo);
      expect(
        TipoRecordatorioHabito.todos,
        contains(TipoRecordatorioHabito.descanso),
      );
      expect(n.carga, claveAvisoDescanso);
      expect(esCargaDeAvisoDescanso(n.carga), isTrue);
      expect(tipoDeClaveDeHabito(n.carga), 'hab_descanso');
      expect(n.carga, isNot(contains('ana'))); // ni quién es
      expect(RegExp(r'[0-9]{3}').hasMatch(n.carga!), isFalse);
      // Ningún nombre de ejercicio ni de aparato.
      for (final palabra in [
        'press',
        'remo',
        'polea',
        'marcy',
        'placa',
        'banda',
      ]) {
        expect(
          '${n.titulo} ${n.carga}'.toLowerCase(),
          isNot(contains(palabra)),
        );
      }
    });

    test('hay una sola: +15 s o −15 s la reemplazan; el id es fijo', () async {
      final s = servicio();
      final d = DescansoPlanificado.iniciar(ahora, const Duration(seconds: 60));
      await s.alCambiarDescanso(d.instanteFinal);
      final mas = d.ajustar(const Duration(seconds: 15), ahora);
      await s.alCambiarDescanso(mas.instanteFinal);
      expect(notificador.programadas, hasLength(1));
      expect(
        notificador.programadas.values.single.cuando,
        ahora.add(const Duration(seconds: 75)),
      );
      final menos = mas.ajustar(const Duration(seconds: -15), ahora);
      await s.alCambiarDescanso(menos.instanteFinal);
      expect(notificador.programadas, hasLength(1));
      expect(
        notificador.programadas.values.single.cuando,
        ahora.add(const Duration(seconds: 60)),
      );
    });

    test('Saltar o terminar la sesión cancelan el aviso', () async {
      final s = servicio();
      final d = DescansoPlanificado.iniciar(ahora, const Duration(seconds: 60));
      await s.alCambiarDescanso(d.instanteFinal);
      expect(notificador.programadas, isNotEmpty);
      // El temporizador de diseno dice que ya terminó (saltar): hoy.
      final salta = d.saltar(ahora);
      expect(salta.haTerminado(ahora), isTrue);
      await s.alCambiarDescanso(salta.instanteFinal); // instante ya llegado
      expect(notificador.programadas, isEmpty);
      expect(s.programadoPara, isNull);

      await s.alCambiarDescanso(d.instanteFinal);
      await s.alCambiarDescanso(null); // no hay descanso (sesión terminada)
      expect(notificador.programadas, isEmpty);
      await s.cancelar(); // cancelar de más no falla
      expect(notificador.visibles, isEmpty);
    });

    test('un instante que ya pasó no programa nada', () async {
      expect(await servicio().programar(ahora), isFalse);
      expect(
        await servicio().programar(ahora.subtract(const Duration(seconds: 5))),
        isFalse,
      );
      expect(notificador.programadas, isEmpty);
    });
  });

  group('solo donde hay recordatorios de Hábitos', () {
    Future<void> intentar(ContextoAvisos c) async {
      contexto = c;
      expect(
        await servicio().programar(ahora.add(const Duration(minutes: 1))),
        isFalse,
      );
      expect(notificador.programadas, isEmpty);
    }

    test(
      'la tablet pública nunca (no hay recordatorios allí)',
      () => intentar(
        const ContextoAvisos(
          tipo: TipoEquipoAvisos.tabletPublica,
          personaId: 'ana',
          usaHabitos: true,
        ),
      ),
    );

    test(
      'la laptop no',
      () => intentar(
        const ContextoAvisos(
          tipo: TipoEquipoAvisos.laptop,
          personaId: 'ana',
          usaHabitos: true,
        ),
      ),
    );

    test('la cuenta maestra, quien no usa Hábitos y nadie dentro no', () async {
      await intentar(
        const ContextoAvisos(
          tipo: TipoEquipoAvisos.telefono,
          personaId: 'ana',
          usaHabitos: true,
          esMaestra: true,
        ),
      );
      await intentar(
        const ContextoAvisos(tipo: TipoEquipoAvisos.telefono, personaId: 'ana'),
      );
      await intentar(
        const ContextoAvisos(tipo: TipoEquipoAvisos.telefono, usaHabitos: true),
      );
    });

    test('la tablet personal sí', () async {
      contexto = const ContextoAvisos(
        tipo: TipoEquipoAvisos.tabletPersonal,
        personaId: 'ana',
        usaHabitos: true,
      );
      expect(
        await servicio().programar(ahora.add(const Duration(minutes: 1))),
        isTrue,
      );
    });
  });

  group('respeta lo que la persona decidió', () {
    test(
      'sin permiso del sistema no se programa y NO se pide a media sesión',
      () async {
        notificador.permiso = false;
        expect(
          await servicio().programar(ahora.add(const Duration(minutes: 1))),
          isFalse,
        );
        expect(notificador.vecesPedirPermiso, 0);
        expect(notificador.programadas, isEmpty);
      },
    );

    test('con los recordatorios de Hábitos apagados, no', () async {
      recordatoriosActivos = false;
      expect(
        await servicio().programar(ahora.add(const Duration(minutes: 1))),
        isFalse,
      );
    });

    test('con el tipo hab_descanso silenciado, no', () async {
      prefs = const PreferenciasAvisos(tiposSilenciados: {'hab_descanso'});
      expect(
        await servicio().programar(ahora.add(const Duration(minutes: 1))),
        isFalse,
      );
    });

    test('en horas silenciosas llega sin sonido ni vibración', () async {
      ahora = DateTime(2026, 11, 23, 22, 30);
      await servicio().programar(ahora.add(const Duration(minutes: 1)));
      expect(notificador.programadas.values.single.notificacion.sonar, isFalse);
    });

    test('de noche normal (19:30) suena', () async {
      await servicio().programar(ahora.add(const Duration(minutes: 1)));
      expect(notificador.programadas.values.single.notificacion.sonar, isTrue);
    });

    test('la zona horaria es la de la persona', () async {
      prefs = const PreferenciasAvisos(zonaHoraria: 'America/Monterrey');
      await servicio().programar(ahora.add(const Duration(minutes: 1)));
      // El notificador recibe la zona; en memoria no la guarda, basta que no falle.
      expect(notificador.programadas, hasLength(1));
    });
  });
}
