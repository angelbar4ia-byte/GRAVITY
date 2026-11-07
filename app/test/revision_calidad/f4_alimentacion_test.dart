// REVISIÓN DE CALIDAD · FASE 4 (docs/revisiones/fase-4.md) · Alimentación.
//
// Guardias (pasan) y hallazgos (etiqueta `hallazgo`, fallan a propósito) sobre
// D23 y D3:
//  - quién ve y quién edita cada menú (matriz de la spec, en el servicio);
//  - el perfil clínico de Papá (Alzheimer, dieta) solo en el módulo de
//    Alimentación y solo para quien tiene permiso;
//  - el espejo de permisos de la app y la matriz del servidor siguen la
//    decisión D23 (Casa nada; el familiar edita el menú de Papá);
//  - la pantalla del menú de Papá cuenta como pantalla sensible (capturas).
//
// Excluir los hallazgos: flutter test --exclude-tags hallazgo
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/pantalla_segura.dart';
import 'package:gravity/modulos/alimentacion/casos_uso/servicio_alimentacion.dart';
import 'package:gravity/modulos/alimentacion/datos/modelos.dart';
import 'package:gravity/modulos/alimentacion/datos/repositorio.dart';
import 'package:gravity/modulos/alimentacion/estado/proveedores.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';

final _lunes = DateTime(2026, 11, 2);

ServicioAlimentacion _servicio(Rol rol, {bool maestra = false}) =>
    ServicioAlimentacion(
      RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes),
      rol: rol,
      esMaestra: maestra,
    );

Future<bool> _lanza(Future<void> Function() f) async {
  try {
    await f();
    return false;
  } on PermisoDenegado {
    return true;
  }
}

void main() {
  group('Servicio de Alimentación: matriz D23 (guardias)', () {
    test('quién ve qué menú', () {
      expect(_servicio(Rol.dueno).menusVisibles, MenuId.values);
      expect(_servicio(Rol.coadministrador).menusVisibles, MenuId.values);
      expect(_servicio(Rol.familiar).menusVisibles, [MenuId.papa]);
      expect(_servicio(Rol.cuidador).menusVisibles, [MenuId.papa]);
      expect(_servicio(Rol.casa).menusVisibles, isEmpty);
      // Cuenta maestra (coadministradora con es_maestra): lee los dos.
      expect(
        _servicio(Rol.coadministrador, maestra: true).menusVisibles,
        MenuId.values,
      );
    });

    test('quién edita qué menú', () {
      for (final m in MenuId.values) {
        expect(_servicio(Rol.dueno).puedeEditarMenuDe(m), isTrue);
        expect(_servicio(Rol.coadministrador).puedeEditarMenuDe(m), isTrue);
        expect(_servicio(Rol.cuidador).puedeEditarMenuDe(m), isFalse);
        expect(_servicio(Rol.casa).puedeEditarMenuDe(m), isFalse);
        expect(
          _servicio(Rol.coadministrador, maestra: true).puedeEditarMenuDe(m),
          isFalse,
          reason: 'la cuenta maestra no edita ($m)',
        );
      }
      expect(_servicio(Rol.familiar).puedeEditarMenuDe(MenuId.papa), isTrue);
      expect(_servicio(Rol.familiar).puedeEditarMenuDe(MenuId.pareja), isFalse);
    });

    test('lo que el rol no puede, el servicio lo rechaza aunque se llame directo',
        () async {
      final familiar = _servicio(Rol.familiar);
      // Edita platillos de Papá, no el de la pareja.
      await familiar.asignar(MenuId.papa, _lunes, 0, TiempoComida.cena, null);
      expect(
        await _lanza(
          () => familiar.asignar(MenuId.pareja, _lunes, 0, TiempoComida.cena, null),
        ),
        isTrue,
      );
      expect(await _lanza(() => familiar.menu(MenuId.pareja, _lunes)), isTrue);
      expect(await _lanza(() => familiar.suplementos(MenuId.pareja)), isTrue);
      // Ni suplementos ni "comprado" ni la lista de compras de Papá.
      const s = Suplemento(
        id: 'x',
        nombre: 'Prueba',
        dosis: '1',
        horario: 'mañana',
      );
      expect(
        await _lanza(() => familiar.guardarSuplemento(MenuId.papa, s)),
        isTrue,
      );
      expect(
        await _lanza(
          () => familiar.marcar(MenuId.papa, _lunes, 'pollo|kg', true),
        ),
        isTrue,
      );
      expect(
        await _lanza(() => familiar.listaCompras(MenuId.papa, _lunes)),
        isTrue,
      );

      final cuidadora = _servicio(Rol.cuidador);
      expect((await cuidadora.menu(MenuId.papa, _lunes)), isNotEmpty);
      expect(
        await _lanza(
          () => cuidadora.asignar(MenuId.papa, _lunes, 0, TiempoComida.cena, null),
        ),
        isTrue,
      );
      expect(await _lanza(() => cuidadora.menu(MenuId.pareja, _lunes)), isTrue);
      expect(
        await _lanza(() => cuidadora.listaCompras(MenuId.pareja, _lunes)),
        isTrue,
      );
      expect(await cuidadora.listaCompras(MenuId.papa, _lunes), isNotNull);
      expect(
        await _lanza(
          () => cuidadora.marcar(MenuId.papa, _lunes, 'pollo|kg', true),
        ),
        isTrue,
      );

      final maestra = _servicio(Rol.coadministrador, maestra: true);
      expect(await maestra.menu(MenuId.pareja, _lunes), isNotNull);
      expect(
        await _lanza(
          () => maestra.asignar(MenuId.papa, _lunes, 0, TiempoComida.cena, null),
        ),
        isTrue,
      );
      expect(
        await _lanza(() => maestra.marcar(MenuId.pareja, _lunes, 'a|b', true)),
        isTrue,
      );

      final casa = _servicio(Rol.casa);
      for (final m in MenuId.values) {
        expect(await _lanza(() => casa.menu(m, _lunes)), isTrue);
        expect(await _lanza(() => casa.suplementos(m)), isTrue);
        expect(await _lanza(() => casa.listaCompras(m, _lunes)), isTrue);
        expect(() => casa.perfil(m), throwsA(isA<PermisoDenegado>()));
      }
    });

    test('el perfil clínico de Papá solo lo ve quien ve el menú de Papá', () {
      expect(_servicio(Rol.dueno).perfil(MenuId.papa).texturaBlanda, isTrue);
      expect(_servicio(Rol.familiar).perfil(MenuId.papa).texturaBlanda, isTrue);
      expect(_servicio(Rol.cuidador).perfil(MenuId.papa).texturaBlanda, isTrue);
      expect(
        () => _servicio(Rol.familiar).perfil(MenuId.pareja),
        throwsA(isA<PermisoDenegado>()),
      );
    });
  });

  group('D3 en Alimentación (guardias)', () {
    test('el perfil clínico de Papá solo existe en perfiles.dart', () {
      final raiz = Directory('lib');
      final infractores = <String>[];
      for (final f in raiz.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('modulos/alimentacion/datos/perfiles.dart')) continue;
        final t = f.readAsStringSync().toLowerCase();
        if (t.contains('alzheimer') || t.contains('aminoácidos')) {
          infractores.add(f.path);
        }
      }
      expect(infractores, isEmpty);
    });

    test('Alimentación no importa asistente, voz, herramientas ni red', () {
      final prohibido = RegExp(
        r"import '(?:package:gravity/|\.\./)*(?:\.\./)*"
        r"(?:nucleo/herramientas|nucleo/voz|modulos/gravity|nucleo/sesion|"
        r"package:http|package:supabase)",
      );
      final propios = Directory('lib/modulos/alimentacion')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final f in propios) {
        expect(
          prohibido.hasMatch(f.readAsStringSync()),
          isFalse,
          reason: f.path,
        );
      }
    });

    test('el módulo no escribe nada en el disco ni lo manda a ningún lado', () {
      final propios = Directory('lib/modulos/alimentacion')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final f in propios) {
        final t = f.readAsStringSync();
        expect(t.contains('Clipboard'), isFalse, reason: f.path);
        expect(t.contains('Share'), isFalse, reason: f.path);
        expect(t.contains('print('), isFalse, reason: f.path);
      }
    });
  });

  group('HALLAZGOS Fase 4 · Alimentación', () {
    // F4-A1 (IMPORTANTE) · el menú de Papá lleva su perfil clínico (Alzheimer,
    // dieta) y NO está protegido contra capturas ni miniaturas: la lista de
    // rutas sensibles (`esPantallaSensible`) no incluye `/alimentacion`.
    // Reproducir: en un teléfono o en Windows, abrir Alimentación y capturar
    // (o abrir "recientes" / pasar el mouse por la barra de tareas).
    test('F4-A1: /alimentacion es pantalla sensible para quien ve el perfil de Papá',
        () {
      for (final rol in [Rol.dueno, Rol.coadministrador, Rol.familiar]) {
        expect(
          esPantallaSensible(Rutas.alimentacion, rol),
          isTrue,
          reason: '$rol ve el perfil clínico de Papá en ${Rutas.alimentacion}',
        );
      }
    }, tags: 'hallazgo');

    // F4-A2 (IMPORTANTE) · D23 / spec 4: la cuenta Casa (tablet pública) no ve
    // ningún menú. Hoy la navegación le ofrece la pestaña "Alimentación" y le
    // abre la ruta; el servicio la rechaza, pero la matriz (app y servidor)
    // dice "Casa lee el menú y la lista". Si backend arma las políticas desde
    // `permisos_rol` (como Finanzas), Casa leería el perfil clínico de Papá.
    test('F4-A2: Casa no tiene Alimentación en el espejo de permisos, en su navegación ni en las rutas',
        () {
      expect(puede(Rol.casa, Modulo.alimentacion, Accion.leer), isFalse);
      expect(
        destinosDe(Rol.casa).any((d) => d.modulo == Modulo.alimentacion),
        isFalse,
      );
      expect(
        calcularRedireccion(
          ubicacion: Rutas.alimentacion,
          rol: Rol.casa,
          dispositivo: TipoDispositivo.tablet,
        ),
        isNotNull,
        reason: 'la tablet pública no abre /alimentacion',
      );
    }, tags: 'hallazgo');

    // F4-A3 (IMPORTANTE) · ajuste del 6/nov (D23): el familiar edita el menú de
    // Papá. La matriz (`permisos.dart` y `permisos_rol`) solo le da leer
    // "su parte". Una RLS desde la matriz le negaría escribir; una escrita a
    // mano (spec, sección 6) contradiría el espejo de la app.
    test('F4-A3: el espejo de permisos refleja que el familiar edita el menú de Papá',
        () {
      expect(puede(Rol.familiar, Modulo.alimentacion, Accion.escribir), isTrue);
    }, tags: 'hallazgo');

    // F4-A5 (IMPORTANTE, integración) · D23 y la spec 4 piden que la cuidadora
    // vea el menú de Papá. Con el espejo actual ("desde Cuidados", sin acceso
    // directo) el router la manda a /cuidados y no hay otra puerta: el menú
    // solo se ve montando la pantalla suelta. Depende de la Fase 5 (Cuidados)
    // o de abrir la ruta solo para ella.
    test('F4-A5: la cuidadora puede llegar a /alimentacion para ver el menú de Papá',
        () {
      expect(
        calcularRedireccion(
          ubicacion: Rutas.alimentacion,
          rol: Rol.cuidador,
          dispositivo: TipoDispositivo.telefono,
        ),
        isNull,
      );
    }, tags: 'hallazgo');

    // F4-A6 (IMPORTANTE) · I9 de la Fase 1 ("con sesión real no hay cifras de
    // ejemplo") no se aplicó a Alimentación: `repositorioAlimentacionProvider`
    // arma SIEMPRE el repositorio en memoria con el menú y los suplementos de
    // ejemplo, aunque la sesión sea real, sin etiqueta de "datos de ejemplo" y
    // sin guardar nada (se pierde al cerrar). Un cuidador o el familiar vería
    // "Multivitamínico · 1 tableta · Desayuno" como si fuera la indicación de
    // Papá. Hasta que backend entregue las tablas (spec, sección 6), con
    // sesión real debe salir vacío o con una etiqueta de ejemplo.
    test('F4-A6: con sesión real el menú y los suplementos de Papá no son de ejemplo',
        () async {
      final c = ProviderContainer(
        overrides: [
          servicioSesionProvider.overrideWithValue(
            ServicioSesionFalso.con(Rol.dueno),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(servicioSesionProvider).esDemostracion, isFalse);
      final repo = c.read(repositorioAlimentacionProvider);
      expect(await repo.suplementos(MenuId.papa), isEmpty);
      expect(await repo.menu(MenuId.papa, lunesDe(DateTime.now())), isEmpty);
    }, tags: 'hallazgo');

    // F4-A4 (MENOR) · el catálogo de platillos no pide permiso: la cuenta Casa
    // lo puede leer por el servicio. No es clínico por sí mismo, pero `duros`
    // (alimentos duros) delata la textura del perfil de Papá.
    test('F4-A4: Casa no lee el catálogo de platillos', () async {
      expect(
        await _lanza(() async {
          await _servicio(Rol.casa).platillos();
        }),
        isTrue,
      );
    }, tags: 'hallazgo');
  });
}
