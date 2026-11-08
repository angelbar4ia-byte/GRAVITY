import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/control_laptop/acciones.dart';
import 'package:gravity/modulos/gravity/control_laptop/bitacora.dart';
import 'package:gravity/modulos/gravity/control_laptop/confirmacion.dart';
import 'package:gravity/modulos/gravity/control_laptop/control_laptop.dart';
import 'package:gravity/modulos/gravity/control_laptop/ejecutor.dart';
import 'package:gravity/modulos/gravity/control_laptop/ejecutor_windows.dart';

const _config = ConfigControlLaptop(
  programasPermitidos: {'calc.exe'},
  carpetasPermitidas: [r'C:\Docs'],
);

class _Proceso {
  final llamadas = <(String, List<String>)>[];
  Future<bool> lanzar(String e, List<String> a) async {
    llamadas.add((e, a));
    return true;
  }
}

EjecutorLaptopWindows _ej(
  _Proceso p, {
  ConfigControlLaptop config = _config,
  List<String>? pantallas,
  bool esWindows = true,
}) => EjecutorLaptopWindows(
  config: config,
  lanzador: p.lanzar,
  listador: (c, q, l) async => ['recibo luz.pdf'],
  abrirPantalla: pantallas?.add,
  esWindows: esWindows,
);

void main() {
  group('EjecutorLaptopWindows (proceso falso)', () {
    test('abrir_programa: ejecutable permitido y sin argumentos', () async {
      final p = _Proceso();
      final r = await _ej(p).ejecutar(const AbrirPrograma('calc.exe'));
      expect(r.exito, isTrue);
      expect(p.llamadas, [('calc.exe', <String>[])]);
    });

    test('un programa no permitido no se abre', () async {
      final p = _Proceso();
      for (final n in ['cmd.exe', 'calc.exe & del x', 'powershell']) {
        final r = await _ej(p).ejecutar(AbrirPrograma(n));
        expect(r.exito, isFalse, reason: n);
      }
      // Por omisión no hay ninguno permitido.
      final r = await _ej(
        p,
        config: const ConfigControlLaptop(),
      ).ejecutar(const AbrirPrograma('calc.exe'));
      expect(r.exito, isFalse);
      expect(p.llamadas, isEmpty);
    });

    test('un nombre permitido pero con metacaracteres tampoco', () async {
      final p = _Proceso();
      final r = await _ej(
        p,
        config: const ConfigControlLaptop(
          programasPermitidos: {'calc.exe & calc'},
        ),
      ).ejecutar(const AbrirPrograma('calc.exe & calc'));
      expect(r.exito, isFalse);
      expect(p.llamadas, isEmpty);
    });

    test(
      'abrir_archivo: argumentos fijos con la ruta como un solo argumento',
      () async {
        final p = _Proceso();
        final r = await _ej(p)
            .ejecutar(const AbrirArchivo(r'C:\Docs\mi recibo.pdf'));
        expect(r.exito, isTrue);
        expect(p.llamadas, [
          (
            'rundll32.exe',
            ['url.dll,FileProtocolHandler', r'C:\Docs\mi recibo.pdf'],
          ),
        ]);
      },
    );

    test(
      'abrir_archivo: fuera de carpetas, con .. o ejecutable no se abre',
      () async {
        final p = _Proceso();
        for (final ruta in [
          r'C:\Otra\a.pdf',
          r'C:\Docs\..\Windows\a.pdf',
          r'C:\Docs\setup.exe',
          r'C:\Docs\a.BAT',
          r'C:\Docs\a.pdf & calc',
        ]) {
          final r = await _ej(p).ejecutar(AbrirArchivo(ruta));
          expect(r.exito, isFalse, reason: ruta);
        }
        expect(p.llamadas, isEmpty);
      },
    );

    test(
      'buscar_archivos: solo en carpetas permitidas y sin proceso',
      () async {
        final p = _Proceso();
        final ok = await _ej(p).ejecutar(
          const BuscarArchivos(carpeta: r'C:\Docs', consulta: 'recibo'),
        );
        expect(ok.exito, isTrue);
        expect(ok.resumen, contains('recibo luz.pdf'));
        final no = await _ej(p)
            .ejecutar(const BuscarArchivos(carpeta: r'C:\Otra', consulta: 'x'));
        expect(no.exito, isFalse);
        expect(p.llamadas, isEmpty);
      },
    );

    test('abrir_pantalla: usa la ruta de GRAVITY, no un proceso', () async {
      final p = _Proceso();
      final rutas = <String>[];
      final r = await _ej(
        p,
        pantallas: rutas,
      ).ejecutar(const AbrirPantalla('finanzas'));
      expect(r.exito, isTrue);
      expect(rutas, ['/finanzas']);
      expect(p.llamadas, isEmpty);
      final x = await _ej(
        p,
        pantallas: rutas,
      ).ejecutar(const AbrirPantalla('otro'));
      expect(x.exito, isFalse);
    });

    test('Gmail y Calendar no pasan por el ejecutor', () async {
      final p = _Proceso();
      for (final a in <Accion>[
        const GmailLeer(),
        const GmailEnviar('b1'),
        CalendarCrear(titulo: 't', inicio: DateTime(2026), fin: DateTime(2026)),
      ]) {
        expect((await _ej(p).ejecutar(a)).exito, isFalse);
      }
      expect(p.llamadas, isEmpty);
    });

    test('fuera de Windows no lanza nada', () async {
      final p = _Proceso();
      final r = await _ej(
        p,
        esWindows: false,
      ).ejecutar(const AbrirPrograma('calc.exe'));
      expect(r.exito, isFalse);
      expect(p.llamadas, isEmpty);
    });
  });

  testWidgets('el diálogo de confirmación cancela sin enviar', (tester) async {
    final p = _Proceso();
    final bitacora = BitacoraEnMemoria();
    final ctx = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: ctx, home: const Scaffold()),
    );
    var enviado = 0;
    final control = ControlLaptop(
      ejecutor: _Cuenta(() => enviado++),
      bitacora: bitacora,
      confirmar: confirmadorConDialogo(() => ctx.currentContext!),
      quien: 'dueno',
    );
    final f = control.procesar(
      const OrdenAsistente(
        herramienta: 'gmail_enviar',
        argumentos: {'borrador_id': 'b1'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('¿Enviar este correo?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await f, isNull);
    expect(enviado, 0);
    expect(bitacora.entradas.single.resultado, ResultadoBitacora.noConfirmada);
    expect(p.llamadas, isEmpty);

    // Y confirmar sí ejecuta (calendar_crear).
    final g = control.procesar(
      OrdenAsistente(
        herramienta: 'calendar_crear',
        argumentos: {
          'titulo': 'Cita',
          'inicio': '2026-11-12T10:00:00',
          'fin': '2026-11-12T11:00:00',
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('¿Crear este evento?'), findsOneWidget);
    await tester.tap(find.text('Crear evento'));
    await tester.pumpAndSettle();
    expect(await g, isNotNull);
    expect(enviado, 1);
  });
}

class _Cuenta extends EjecutorLaptopWindows {
  _Cuenta(this.alEjecutar);
  final void Function() alEjecutar;
  @override
  Future<ResultadoEjecucion> ejecutar(Accion accion) async {
    alEjecutar();
    return const ResultadoEjecucion(exito: true);
  }
}
