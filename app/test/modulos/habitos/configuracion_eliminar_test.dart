import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/avisos/con_avisos.dart' show tipoEquipoAvisosProvider;
import 'package:gravity/app/sensibles/puerta_reservada.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo, relojProvider;
import 'package:gravity/modulos/habitos/casos_uso/servicio_agenda.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_eliminar.dart';
import 'package:gravity/modulos/habitos/datos/documentos_sensibles.dart';
import 'package:gravity/modulos/habitos/datos/fuentes_plataforma.dart';
import 'package:gravity/modulos/habitos/datos/repositorio.dart';
import 'package:gravity/modulos/habitos/datos/repositorio_agenda.dart';
import 'package:gravity/modulos/habitos/estado/proveedores.dart';
import 'package:gravity/modulos/habitos/pantallas/eliminar.dart';
import 'package:gravity/modulos/habitos/pantallas/hoy.dart';
import 'package:gravity/modulos/habitos/pantallas/listas_habito.dart';
import 'package:gravity/modulos/habitos/pantallas/pausa.dart';
import 'package:gravity/modulos/habitos/pantallas/progreso.dart';
import 'package:gravity/nucleo/avisos/notificador.dart' show AccionDeNotificacion;
import 'package:gravity/nucleo/avisos/recordatorios_habitos.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/sobres.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

// Fase 4, E9 a E12 / criterio 33.

class _Abierto extends ReservadoAbierto {
  @override
  bool build() => true;
}

void main() {
  late AlmacenSeguroEnMemoria almacen;
  late DateTime ahora;
  late ServicioHabitoEliminar s;

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    ahora = DateTime.utc(2026, 11, 2, 10);
    s = ServicioHabitoEliminar(
      DocumentosSensibles(
        llaves: LlavesHabitos(almacen),
        sobres: AlmacenDeSobres(almacen),
        modos: ModosLocales(almacen),
        persona: 'ana',
        ahora: () => ahora,
      ),
      ahora: () => ahora,
    );
  });

  Future<void> configurarCigarrillo({DateTime? diaD}) => s.configurar(
    ConfigHabito(
      tipo: TipoHabito.cigarrillo,
      inicio: DateTime.utc(2026, 11, 2),
      diaD: diaD ?? DateTime.utc(2026, 11, 2),
    ),
  );

  group('E9: motivos, disparadores y reemplazos', () {
    test('se guardan cifrados, sin tocar el resto de la configuración', () async {
      await s.configurar(
        ConfigHabito(
          tipo: TipoHabito.azucar,
          inicio: DateTime.utc(2026, 11, 2),
          limiteOcasional: 2,
          periodoSemana: true,
        ),
      );
      ahora = ahora.add(const Duration(minutes: 1));
      await s.guardarListas(
        TipoHabito.azucar,
        motivos: [' Mi salud MOTIVO_SECRETO ', '', 'Mi salud MOTIVO_SECRETO', 'Tener energía'],
        disparadores: ['Después de comer DISPARADOR_SECRETO'],
        reemplazos: ['Fruta'],
      );
      final c = (await s.config(TipoHabito.azucar))!;
      expect(c.motivos, ['Mi salud MOTIVO_SECRETO', 'Tener energía']);
      expect(c.disparadores, ['Después de comer DISPARADOR_SECRETO']);
      expect(c.reemplazos, ['Fruta']);
      expect(c.limiteOcasional, 2);
      expect(c.periodoSemana, isTrue);
      final todo = almacen.datos.values.join();
      expect(todo, isNot(contains('SECRETO')));
      expect(todo, isNot(contains('azucar')));
    });

    test('límites, hábito sin configurar y configuración antigua sin las listas nuevas', () async {
      await expectLater(s.guardarListas(TipoHabito.cigarrillo, motivos: ['x']), throwsArgumentError);
      await configurarCigarrillo();
      await expectLater(
        s.guardarListas(TipoHabito.cigarrillo, motivos: [for (var i = 0; i < 11; i++) 'm$i']),
        throwsArgumentError,
      );
      // una configuración guardada antes de esta fase no trae las claves nuevas
      final viejo = ConfigHabito.deDatos({
        for (final e in ConfigHabito(tipo: TipoHabito.cigarrillo, inicio: DateTime.utc(2026, 11, 2)).aDatos().entries)
          if (e.key != 'disparadores' && e.key != 'reemplazos') e.key: e.value,
      });
      expect(viejo.disparadores, isEmpty);
      expect(viejo.reemplazos, isEmpty);
    });

    testWidgets('los motivos aparecen en el SOS y el disparador se elige al cerrar', (t) async {
      await configurarCigarrillo();
      ahora = ahora.add(const Duration(minutes: 1));
      await s.guardarListas(
        TipoHabito.cigarrillo,
        motivos: ['Quiero jugar con mi hija'],
        disparadores: ['Después del café'],
        reemplazos: ['Masticar menta'],
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
            tipoEquipoAvisosProvider.overrideWithValue(TipoEquipoAvisos.telefono),
            reservadoAbiertoProvider.overrideWith(_Abierto.new),
            servicioEliminarProvider.overrideWithValue(s),
          ],
          child: const MaterialApp(home: PantallaPausa()),
        ),
      );
      await t.pump();
      expect(find.text('Quiero jugar con mi hija'), findsNothing); // aún no se sabe de qué hábito
      await t.tap(find.text('Seguir')); // pausa
      await t.pump();
      await t.tap(find.text('Cigarrillo'));
      await t.tap(find.text('Seguir'));
      await t.pump();
      await t.pump();
      expect(find.text('Recuerda por qué'), findsOneWidget);
      expect(find.text('Quiero jugar con mi hija'), findsOneWidget);
      expect(find.text('Masticar menta'), findsOneWidget); // mi reemplazo, entre las técnicas
    });

    testWidgets('la hoja de listas se edita y guarda', (t) async {
      await configurarCigarrillo();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
            servicioEliminarProvider.overrideWithValue(s),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(padding: EdgeInsets.all(16), child: HojaListasHabito(tipo: TipoHabito.cigarrillo)),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Nuevo motivo'), 'Mi familia');
      await t.tap(find.byTooltip('Agregar').first);
      await t.pump();
      expect(find.text('Mi familia'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Nuevo disparador'), 'Estrés');
      await t.tap(find.byTooltip('Agregar').at(1));
      await t.pump();
      ahora = ahora.add(const Duration(minutes: 1)); // el último cambio gana
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      final c = (await s.config(TipoHabito.cigarrillo))!;
      expect(c.motivos, ['Mi familia']);
      expect(c.disparadores, ['Estrés']);
    });
  });

  group('E10: hitos de constancia', () {
    test('cigarrillo: salen una sola vez y son solo de constancia', () async {
      await configurarCigarrillo(diaD: DateTime.utc(2026, 11, 2));
      ahora = DateTime.utc(2026, 11, 2, 21); // día 1 desde el Día D
      expect(await s.hitosPorVerDe(TipoHabito.cigarrillo), [1]);
      ahora = DateTime.utc(2026, 11, 8, 21); // 7 días libres
      expect(await s.hitosPorVerDe(TipoHabito.cigarrillo), [1, 3, 7]);
      await s.marcarHitosVistos(TipoHabito.cigarrillo, [1, 3, 7]);
      expect(await s.hitosPorVerDe(TipoHabito.cigarrillo), isEmpty);
      ahora = DateTime.utc(2026, 11, 20, 21); // 19 días
      expect(await s.hitosPorVerDe(TipoHabito.cigarrillo), [14]);
      await s.marcarHitosVistos(TipoHabito.cigarrillo, [14]);
      expect(await s.hitosPorVerDe(TipoHabito.cigarrillo), isEmpty);
      // hitos del dominio: 1, 3, 7, 14, 30, 60, 90, 180, 365 (cigarrillo) y 3, 7, 14, 30 (azúcar)
      expect(hitosCigarrillo, [1, 3, 7, 14, 30, 60, 90, 180, 365]);
      expect(hitosAzucar, [3, 7, 14, 30]);
    });

    test('una recaída reinicia la cuenta y los hitos ya vistos no vuelven', () async {
      await configurarCigarrillo(diaD: DateTime.utc(2026, 11, 2));
      ahora = DateTime.utc(2026, 11, 8, 21);
      await s.marcarHitosVistos(TipoHabito.cigarrillo, [1, 3, 7]);
      await s.registrarConsumo(TipoHabito.cigarrillo, fecha: DateTime.utc(2026, 11, 8));
      expect(await s.diasDeConstancia(TipoHabito.cigarrillo), 0);
      ahora = DateTime.utc(2026, 11, 12, 21); // del 9 al 12 de nov
      expect(await s.diasDeConstancia(TipoHabito.cigarrillo), 4);
      expect(await s.hitosPorVerDe(TipoHabito.cigarrillo), isEmpty); // el 3 ya lo vio
    });

    test('azúcar: días seguidos sin refresco desde que termina la línea base', () async {
      await s.configurar(
        ConfigHabito(tipo: TipoHabito.azucar, inicio: DateTime.utc(2026, 11, 2), limiteOcasional: 2),
      );
      ahora = DateTime.utc(2026, 11, 8, 21); // aún en línea base
      expect(await s.diasDeConstancia(TipoHabito.azucar), 0);
      expect(await s.hitosPorVerDe(TipoHabito.azucar), isEmpty);
      ahora = DateTime.utc(2026, 11, 12, 21); // 9 a 12 de nov: 4 días
      expect(await s.diasDeConstancia(TipoHabito.azucar), 4);
      expect(await s.hitosPorVerDe(TipoHabito.azucar), [3]);
      await s.registrarConsumo(TipoHabito.azucar, categoria: 'refresco', fecha: DateTime.utc(2026, 11, 11));
      expect(await s.diasDeConstancia(TipoHabito.azucar), 1);
    });

    test('el texto del hito no dice nada de salud ni culpa', () {
      for (final d in [...hitosCigarrillo, ...hitosAzucar]) {
        final t = textoHito(d).toLowerCase();
        expect(t, isNotEmpty);
        for (final p in ['salud', 'pulmón', 'cáncer', 'riesgo', ...MensajesHabitos.prohibidas]) {
          expect(t.contains(p), isFalse);
        }
      }
    });

    testWidgets('el panel muestra el hito una vez y "Gracias" lo guarda como visto', (t) async {
      await configurarCigarrillo(diaD: DateTime.utc(2026, 11, 2));
      ahora = DateTime.utc(2026, 11, 4, 21); // 3 días
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
            tipoEquipoAvisosProvider.overrideWithValue(TipoEquipoAvisos.telefono),
            reservadoAbiertoProvider.overrideWith(_Abierto.new),
            servicioEliminarProvider.overrideWithValue(s),
          ],
          child: const MaterialApp(home: PantallaHabitoEliminar(tipo: TipoHabito.cigarrillo)),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(textoHito(3)), findsOneWidget);
      await t.tap(find.text('Gracias'));
      await t.pumpAndSettle();
      expect(find.text(textoHito(3)), findsNothing);
      expect(await s.hitosPorVerDe(TipoHabito.cigarrillo), isEmpty);
    });
  });

  group('E11: recordatorio de dar', () {
    late RepositorioAgendaEnMemoria agenda;
    late ServicioAgenda sa;
    setUp(() {
      agenda = RepositorioAgendaEnMemoria();
      sa = ServicioAgenda(agenda, RepositorioHabitosEnMemoria(), ahora: () => ahora);
    });

    Future<List<RecordatorioHabito>> proximos() => FuenteDeRecordatoriosDeHabitos(agenda, null)
        .proximos(desde: DateTime(2026, 11, 2), dias: 7)
        .then((l) => [for (final r in l) if (r.objetoId == 'dar') r]);

    test('apagado por omisión: no programa nada', () async {
      expect((await agenda.ajustes()).darActivo, isFalse);
      expect(await proximos(), isEmpty);
    });

    test('encendido: un aviso por semana, con el texto genérico y sin montos', () async {
      await sa.configurarDar(activo: true, dia: 7, horaMin: 600); // domingo 10:00
      final l = await proximos();
      expect(l.length, 1);
      expect(l.single.cuando, DateTime(2026, 11, 8, 10));
      expect(l.single.sensible, isTrue);
      expect(tituloDeRecordatorio(l.single), 'Recordatorio');
      expect(accionesDeRecordatorio(l.single), const [AccionDeNotificacion.posponer10]);
      // sin dígitos ni "$" en el título
      expect(RegExp(r'[0-9$]').hasMatch(tituloDeRecordatorio(l.single)), isFalse);
    });

    test('se puede apagar y exige día y hora al encender', () async {
      await sa.configurarDar(activo: true, dia: 3, horaMin: 480);
      await sa.configurarDar(activo: false);
      expect((await agenda.ajustes()).darActivo, isFalse);
      expect(await proximos(), isEmpty);
      await expectLater(sa.configurarDar(activo: true), throwsArgumentError);
      await expectLater(sa.configurarDar(activo: true, dia: 8, horaMin: 10), throwsArgumentError);
      await expectLater(sa.configurarDar(activo: true, dia: 1, horaMin: 1440), throwsArgumentError);
    });

    test('las filas de ajustes guardan día y hora (formato de la base)', () async {
      await sa.configurarDar(activo: true, dia: 5, horaMin: 1125);
      final c = (await agenda.ajustes()).aCambios(ahora);
      expect(c['dar_activo'], true);
      expect(c['dar_dia'], 5);
      expect(c['dar_hora'], '18:45');
    });
  });

  group('E12: revisión semanal en el teléfono', () {
    Future<void> montarHoy(WidgetTester t, DateTime reloj, RepositorioAgendaEnMemoria agenda) {
      final repo = RepositorioHabitosEnMemoria();
      return t.pumpWidget(
        ProviderScope(
          overrides: [
            servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
            almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
            relojProvider.overrideWithValue(RelojFijo(reloj)),
            repositorioHabitosProvider.overrideWithValue(repo),
            repositorioAgendaProvider.overrideWithValue(agenda),
          ],
          child: const MaterialApp(home: PantallaHoyHabitos()),
        ),
      );
    }

    testWidgets('el aviso aparece desde su hora, un toque la abre y desaparece al cerrarla', (t) async {
      final agenda = RepositorioAgendaEnMemoria();
      // sábado 14:14: aún no; 14:15: sí (aviso 15 min antes de las 14:30)
      await montarHoy(t, DateTime.utc(2026, 11, 7, 14, 14), agenda);
      await t.pumpAndSettle();
      expect(find.text('Es hora de tu revisión semanal'), findsNothing);
      await montarHoy(t, DateTime.utc(2026, 11, 7, 14, 15), agenda);
      await t.pumpAndSettle();
      expect(find.text('Es hora de tu revisión semanal'), findsOneWidget);
      expect(find.text('Empezar'), findsOneWidget);
      // cerrada: ya no aparece
      final cont = ProviderScope.containerOf(t.element(find.byType(PantallaHoyHabitos)));
      await cont.read(servicioRevisionProvider).omitir();
      cont.read(versionHabitosProvider.notifier).state++;
      await t.pumpAndSettle();
      expect(find.text('Es hora de tu revisión semanal'), findsNothing);
    });

    testWidgets('el aviso sigue el domingo y a media semana no aparece', (t) async {
      final agenda = RepositorioAgendaEnMemoria();
      await montarHoy(t, DateTime.utc(2026, 11, 8, 9), agenda); // domingo
      await t.pumpAndSettle();
      expect(find.text('Es hora de tu revisión semanal'), findsOneWidget);
      await montarHoy(t, DateTime.utc(2026, 11, 11, 9), agenda); // miércoles
      await t.pumpAndSettle();
      expect(find.text('Es hora de tu revisión semanal'), findsNothing);
    });

    testWidgets('en teléfono la revisión es corta por omisión y se puede ampliar', (t) async {
      t.view.physicalSize = const Size(400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
            almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
            repositorioHabitosProvider.overrideWithValue(RepositorioHabitosEnMemoria()),
            repositorioAgendaProvider.overrideWithValue(RepositorioAgendaEnMemoria()),
          ],
          child: const MaterialApp(home: PantallaRevision()),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('¿Qué agradezco?'), findsOneWidget);
      expect(find.text('¿Qué aprendí?'), findsNothing);
      expect(find.text('Versión corta (30 segundos)'), findsOneWidget);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      for (final p in preguntasRevision.values) {
        expect(find.text(p), findsOneWidget);
      }
    });
  });
}
