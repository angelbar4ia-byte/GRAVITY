import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo, relojProvider;
import 'package:gravity/modulos/cuidados/casos_uso/permisos_cuidados.dart';
import 'package:gravity/modulos/cuidados/casos_uso/servicio_cuidados.dart';
import 'package:gravity/modulos/cuidados/datos/modelos.dart';
import 'package:gravity/modulos/cuidados/datos/repositorio.dart';
import 'package:gravity/modulos/cuidados/estado/proveedores.dart';
import 'package:gravity/modulos/cuidados/pantallas/consentimientos.dart';
import 'package:gravity/modulos/cuidados/pantallas/instrucciones.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

final _ahora = DateTime(2026, 11, 4, 10);
const _cuidadora = 'persona-cuidadora';
const _hermana = 'persona-hermana';
const _dueno = 'persona-dueno';
const _pareja = 'persona-pareja';
const _textoInstr = 'Revisar que cene sentado';

const _perfilHermana = PerfilCuidados(esFamiliar: true);

RepositorioCuidadosEnMemoria _repo(
  DatosCuidadosMemoria d,
  String id,
  Rol rol, {
  PerfilCuidados perfil = const PerfilCuidados(),
  bool albacea = false,
}) => RepositorioCuidadosEnMemoria(
  datos: d,
  personaId: id,
  rol: rol,
  perfilActual: perfil,
  esAlbacea: albacea,
);

ServicioCuidados _srv(
  DatosCuidadosMemoria d,
  String id,
  Rol rol, {
  PerfilCuidados perfil = const PerfilCuidados(),
  bool albacea = false,
  bool maestra = false,
}) => ServicioCuidados(
  _repo(d, id, rol, perfil: perfil, albacea: albacea),
  permisos: PermisosCuidados(
    rol: rol,
    perfil: albacea
        ? PerfilCuidados(
            tipo: perfil.tipo,
            esFamiliar: perfil.esFamiliar,
            esAlbacea: true,
          )
        : perfil,
    esMaestra: maestra,
  ),
  personaId: id,
  nombre: id,
  ahora: () => _ahora,
);

Widget _app(
  Widget pantalla,
  DatosCuidadosMemoria d,
  String id,
  Rol rol, {
  PerfilCuidados perfil = const PerfilCuidados(),
  bool albacea = false,
}) => ProviderScope(
  overrides: [
    relojProvider.overrideWithValue(RelojFijo(_ahora)),
    almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
    servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
    sesionEfectivaProvider.overrideWithValue(
      Sesion(
        persona: Persona(id: id, nombre: id),
        rol: rol,
      ),
    ),
    repositorioCuidadosProvider.overrideWithValue(
      _repo(d, id, rol, perfil: perfil, albacea: albacea),
    ),
  ],
  child: MaterialApp(home: pantalla),
);

Future<void> _alto(WidgetTester t) async {
  await t.binding.setSurfaceSize(const Size(400, 3000));
  addTearDown(() => t.binding.setSurfaceSize(null));
}

List<EntradaBitacora> _instrucciones(DatosCuidadosMemoria d) => [
  for (final e in d.bitacora)
    if (e.tipo == TipoBitacora.instruccion) e,
];

void main() {
  group('Instrucciones para la cuidadora (§8f)', () {
    test(
      'dueño, hermana y pareja (con o sin consentimiento) la dejan',
      () async {
        final d = DatosCuidadosMemoria();
        await _srv(d, _dueno, Rol.dueno).dejarInstruccion(_textoInstr);
        await _srv(
          d,
          _hermana,
          Rol.cuidador,
          perfil: _perfilHermana,
        ).dejarInstruccion(_textoInstr);
        await _srv(
          d,
          _pareja,
          Rol.coadministrador,
        ).dejarInstruccion(_textoInstr);
        await _srv(
          d,
          _pareja,
          Rol.coadministrador,
          perfil: const PerfilCuidados(consentimiento: true),
        ).dejarInstruccion(_textoInstr);
        expect(_instrucciones(d).map((e) => e.autorId), [
          _dueno,
          _hermana,
          _pareja,
          _pareja,
        ]);
      },
    );

    test('la cuidadora, la cuenta maestra y Casa no la dejan', () async {
      final d = DatosCuidadosMemoria();
      for (final s in [
        _srv(d, _cuidadora, Rol.cuidador),
        _srv(d, _dueno, Rol.dueno, maestra: true),
        _srv(d, 'persona-casa', Rol.casa),
      ]) {
        await expectLater(
          s.dejarInstruccion(_textoInstr),
          throwsA(isA<ErrorCuidados>()),
        );
      }
      expect(d.bitacora, isEmpty);
    });

    test(
      'el repositorio también lo niega (defensa doble, como el servidor)',
      () {
        final d = DatosCuidadosMemoria();
        expect(
          () => _repo(
            d,
            _cuidadora,
            Rol.cuidador,
          ).dejarInstruccion(_textoInstr, autorNombre: 'x', en: _ahora),
          throwsA(isA<ErrorCuidados>()),
        );
      },
    );

    test('de 1 a 500 letras', () async {
      final d = DatosCuidadosMemoria();
      final s = _srv(d, _dueno, Rol.dueno);
      await expectLater(
        s.dejarInstruccion('   '),
        throwsA(isA<ErrorCuidados>()),
      );
      await expectLater(
        s.dejarInstruccion('a' * 501),
        throwsA(isA<ErrorCuidados>()),
      );
      await s.dejarInstruccion('a' * 500);
      expect(_instrucciones(d), hasLength(1));
    });

    test(
      'la cuidadora ve las instrucciones y sus notas, no las de otros',
      () async {
        final d = DatosCuidadosMemoria();
        await _srv(d, _dueno, Rol.dueno).dejarInstruccion('Del dueño');
        await _srv(
          d,
          _pareja,
          Rol.coadministrador,
        ).dejarInstruccion('De pareja');
        d.bitacora.addAll([
          EntradaBitacora(
            id: 'n1',
            tipo: TipoBitacora.nota,
            texto: 'Nota propia',
            autorId: _cuidadora,
            autorNombre: 'Cuidadora',
            creadaEn: _ahora,
          ),
          EntradaBitacora(
            id: 'n2',
            tipo: TipoBitacora.nota,
            texto: 'Nota de la hermana',
            autorId: _hermana,
            autorNombre: 'Hermana',
            creadaEn: _ahora,
          ),
        ]);
        final lista = await _srv(
          d,
          _cuidadora,
          Rol.cuidador,
        ).instruccionesRecibidas();
        expect(lista.map((e) => e.texto).toSet(), {
          'Del dueño',
          'De pareja',
          'Nota propia',
        });
        // Quien no es cuidadora no usa esta lista.
        expect(
          await _srv(d, _dueno, Rol.dueno).instruccionesRecibidas(),
          isEmpty,
        );
      },
    );

    test(
      'la pareja sin consentimiento no lee la bitácora; con él, sí',
      () async {
        final d = DatosCuidadosMemoria();
        await _srv(
          d,
          _pareja,
          Rol.coadministrador,
        ).dejarInstruccion(_textoInstr);
        final sin = _srv(d, _pareja, Rol.coadministrador);
        expect(await sin.instruccionesRecibidas(), isEmpty);
        expect(await sin.bitacora(), isEmpty);
        await sin.cambiarMiConsentimiento(true);
        final perfil = await _repo(d, _pareja, Rol.coadministrador).perfil();
        final con = _srv(d, _pareja, Rol.coadministrador, perfil: perfil);
        expect(await con.bitacora(), hasLength(1));
      },
    );
  });

  group('Consentimientos (§4)', () {
    test('la pareja concede y retira; el dueño solo lo ve', () async {
      final d = DatosCuidadosMemoria();
      final pareja = _srv(d, _pareja, Rol.coadministrador);
      final dueno = _srv(d, _dueno, Rol.dueno);
      expect((await dueno.estadoConsentimientos())!.parejaConcedido, isFalse);

      await pareja.cambiarMiConsentimiento(true);
      expect((await dueno.estadoConsentimientos())!.parejaConcedido, isTrue);
      expect((await pareja.estadoConsentimientos())!.parejaConcedido, isTrue);

      await pareja.cambiarMiConsentimiento(false);
      expect((await dueno.estadoConsentimientos())!.parejaConcedido, isFalse);
    });

    test('el dueño no cambia el consentimiento de la pareja', () async {
      final d = DatosCuidadosMemoria();
      await expectLater(
        _srv(d, _dueno, Rol.dueno).cambiarMiConsentimiento(true),
        throwsA(isA<ErrorCuidados>()),
      );
      // Ni saltándose el servicio: el repositorio solo deja a su titular.
      await expectLater(
        _repo(d, _dueno, Rol.dueno).cambiarConsentimiento(_pareja, true),
        throwsA(isA<ErrorCuidados>()),
      );
      expect(d.consentimientos, isEmpty);
    });

    test(
      'solo el albacea autoriza o retira el resumen de la hermana',
      () async {
        final d = DatosCuidadosMemoria();
        final albacea = _srv(d, _dueno, Rol.dueno, albacea: true);
        final sinCargo = _srv(d, 'persona-otro', Rol.dueno);

        await expectLater(
          sinCargo.autorizarResumen(_hermana, true),
          throwsA(isA<ErrorCuidados>()),
        );
        expect(d.autorizaciones, isEmpty);

        await albacea.autorizarResumen(_hermana, true);
        expect(
          (await albacea.estadoConsentimientos())!.hermanaAutorizada,
          isTrue,
        );
        final hermana = _repo(
          d,
          _hermana,
          Rol.cuidador,
          perfil: _perfilHermana,
        );
        expect((await hermana.perfil()).resumenAutorizado, isTrue);

        await albacea.autorizarResumen(_hermana, false);
        expect(
          (await albacea.estadoConsentimientos())!.hermanaAutorizada,
          isFalse,
        );
      },
    );

    test('la hermana y la cuidadora no ven esta pantalla', () async {
      final d = DatosCuidadosMemoria();
      expect(
        await _srv(
          d,
          _hermana,
          Rol.cuidador,
          perfil: _perfilHermana,
        ).estadoConsentimientos(),
        isNull,
      );
      expect(
        await _srv(d, _cuidadora, Rol.cuidador).estadoConsentimientos(),
        isNull,
      );
    });
  });

  group('Pantallas', () {
    testWidgets('la pareja deja una instrucción y el aviso no la repite', (
      t,
    ) async {
      await _alto(t);
      final d = DatosCuidadosMemoria();
      await t.pumpWidget(
        _app(const PantallaInstrucciones(), d, _pareja, Rol.coadministrador),
      );
      await t.pumpAndSettle();
      expect(find.text('Enviar instrucción'), findsOneWidget);
      await t.enterText(find.byType(TextField), _textoInstr);
      await t.pump();
      await t.tap(find.text('Enviar instrucción'));
      await t.pumpAndSettle();
      expect(find.text('Instrucción enviada'), findsOneWidget);
      expect(find.text(_textoInstr), findsNothing);
      expect(_instrucciones(d).single.texto, _textoInstr);
    });

    testWidgets('la cuidadora ve la lista y no el formulario', (t) async {
      await _alto(t);
      final d = DatosCuidadosMemoria();
      await _srv(d, _dueno, Rol.dueno).dejarInstruccion(_textoInstr);
      await t.pumpWidget(
        _app(const PantallaInstrucciones(), d, _cuidadora, Rol.cuidador),
      );
      await t.pumpAndSettle();
      expect(find.text(_textoInstr), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Enviar instrucción'), findsNothing);
    });

    testWidgets('la pareja concede y retira su consentimiento', (t) async {
      await _alto(t);
      final d = DatosCuidadosMemoria();
      await t.pumpWidget(
        _app(const PantallaConsentimientos(), d, _pareja, Rol.coadministrador),
      );
      await t.pumpAndSettle();
      expect(find.text('No concedido'), findsOneWidget);
      await t.tap(find.text('Conceder'));
      await t.pumpAndSettle();
      expect(find.text('Consentimiento concedido'), findsOneWidget);
      expect(find.text('Concedido'), findsOneWidget);
      expect(d.consentimientos[_pareja], isTrue);
      await t.tap(find.text('Retirar consentimiento'));
      await t.pumpAndSettle();
      expect(d.consentimientos[_pareja], isFalse);
    });

    testWidgets('el albacea autoriza el resumen de la hermana', (t) async {
      await _alto(t);
      final d = DatosCuidadosMemoria();
      await t.pumpWidget(
        _app(
          const PantallaConsentimientos(),
          d,
          _dueno,
          Rol.dueno,
          albacea: true,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('No autorizado'), findsOneWidget);
      await t.tap(find.text('Autorizar'));
      await t.pumpAndSettle();
      expect(d.autorizaciones[_hermana], isTrue);
      expect(find.text('Retirar autorización'), findsOneWidget);
    });

    testWidgets('el dueño que no es albacea solo ve el estado', (t) async {
      await _alto(t);
      final d = DatosCuidadosMemoria();
      d.consentimientos[_pareja] = true;
      await t.pumpWidget(
        _app(const PantallaConsentimientos(), d, _dueno, Rol.dueno),
      );
      await t.pumpAndSettle();
      expect(find.text('Concedido'), findsOneWidget);
      expect(find.text('No autorizado'), findsOneWidget);
      expect(find.text('Conceder'), findsNothing);
      expect(find.text('Retirar consentimiento'), findsNothing);
      expect(find.text('Autorizar'), findsNothing);
    });
  });
}
