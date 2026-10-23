import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/ordenes/interprete_ordenes.dart';
import 'package:gravity/modulos/gravity/ordenes/texto_ordenes.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/herramientas/herramientas.dart';

/// Ruta que abre [texto] para [rol] en [dispositivo], o `null` si no se
/// entendió un único destino.
String? rutaDe(
  String texto, {
  Rol rol = Rol.dueno,
  TipoDispositivo? dispositivo = TipoDispositivo.laptop,
}) => switch (InterpreteOrdenes(
  rol: rol,
  dispositivo: dispositivo,
).interpretar(texto)) {
  OrdenEntendida(:final destino) => destino.ruta,
  _ => null,
};

/// Herramienta que entiende [texto] para [rol], o `null`.
HerramientaNavegacion? destinoDe(
  String texto, {
  Rol rol = Rol.dueno,
  bool esMaestra = false,
}) => switch (InterpreteOrdenes(
  rol: rol,
  dispositivo: TipoDispositivo.laptop,
  esMaestra: esMaestra,
).interpretar(texto)) {
  OrdenEntendida(:final destino) => destino,
  _ => null,
};

/// Destinos que ofrece un resultado ("¿Quisiste decir…?" o "No entendí").
List<HerramientaNavegacion> destinosDe(ResultadoOrden r) => switch (r) {
  OrdenEntendida(:final destino) => [destino],
  OrdenParecida(:final opciones) => opciones,
  OrdenNoEntendida(:final disponibles) => disponibles,
  OrdenVacia() => const [],
};

List<String> opcionesDe(ResultadoOrden r) => switch (r) {
  OrdenParecida(:final opciones) => [for (final o in opciones) o.ruta],
  OrdenNoEntendida(:final disponibles) => [for (final o in disponibles) o.ruta],
  _ => const [],
};

void main() {
  group('Texto', () {
    test('normaliza acentos, mayúsculas y signos', () {
      expect(normalizarTexto('¡Ábreme el MENÚ!'), 'abreme el menu');
      expect(normalizarTexto('  Ir   a   Hábitos  '), 'ir a habitos');
      expect(normalizarTexto('Cuidados de PAPÁ.'), 'cuidados de papa');
      expect(normalizarTexto('¿Configuración?'), 'configuracion');
    });

    test('distancia de edición con transposiciones', () {
      expect(distanciaEdicion('finanzas', 'finanzas'), 0);
      expect(distanciaEdicion('finansas', 'finanzas'), 1);
      expect(distanciaEdicion('hbaitos', 'habitos'), 1);
      expect(distanciaEdicion('presupusto', 'presupuesto'), 1);
      expect(distanciaEdicion('', 'casa'), 4);
      expect(distanciaEdicion('kasa', 'casa'), 1);
    });

    test('quita relleno y el llamado "gravity"', () {
      expect(quitarRelleno(palabrasDe('Ábreme el presupuesto, por favor')), [
        'presupuesto',
      ]);
      expect(quitarRelleno(palabrasDe('Gravity, abre finanzas')), ['finanzas']);
      expect(quitarRelleno(palabrasDe('gravity')), ['gravity']);
    });
  });

  group('Órdenes que entiende', () {
    test('las del ejemplo', () {
      expect(rutaDe('abre presupuesto'), Rutas.finanzas);
      expect(rutaDe('abrir finanzas'), Rutas.finanzas);
      expect(rutaDe('ir a hábitos'), Rutas.habitos);
      expect(rutaDe('ajustes'), Rutas.ajustes);
      expect(rutaDe('desarrollador'), Rutas.desarrollador);
    });

    test('sin importar acentos ni mayúsculas', () {
      expect(rutaDe('ABRE PRESUPUESTO'), Rutas.finanzas);
      expect(rutaDe('ir a habitos'), Rutas.habitos);
      expect(rutaDe('Ir A HÁBITOS'), Rutas.habitos);
      expect(rutaDe('  ¡Ábreme el presupuesto, por favor!  '), Rutas.finanzas);
      expect(rutaDe('Gravity, abre finanzas'), Rutas.finanzas);
    });

    test('sinónimos', () {
      expect(rutaDe('dinero'), Rutas.finanzas);
      expect(rutaDe('abre cuidados'), Rutas.cuidados);
      expect(rutaDe('ve a papá'), Rutas.cuidados);
      expect(rutaDe('cuidados de papa'), Rutas.cuidados);
      for (final palabra in ['comida', 'cocina', 'menú', 'menu', 'recetas']) {
        expect(rutaDe('abre $palabra'), Rutas.alimentacion, reason: palabra);
      }
      expect(rutaDe('casa'), Rutas.casa);
      expect(rutaDe('abre hogar'), Rutas.casa);
      expect(rutaDe('configuración'), Rutas.ajustes);
      expect(rutaDe('inicio'), Rutas.inicio);
      expect(rutaDe('gravity'), Rutas.inicio);
    });

    test('gana la frase más larga', () {
      expect(rutaDe('abre el menú principal'), Rutas.inicio);
      expect(rutaDe('abre el menú'), Rutas.alimentacion);
    });

    test('vacía o solo relleno', () {
      final interprete = InterpreteOrdenes(rol: Rol.dueno);
      expect(interprete.interpretar('   '), isA<OrdenVacia>());
      expect(interprete.interpretar('¡!'), isA<OrdenVacia>());
      final soloVerbo = interprete.interpretar('abre');
      expect(soloVerbo, isA<OrdenNoEntendida>());
      expect(opcionesDe(soloVerbo), contains(Rutas.finanzas));
    });
  });

  group('¿Quisiste decir…?', () {
    test('errores de dedo dan opciones parecidas, no navegan solos', () {
      final interprete = InterpreteOrdenes(rol: Rol.dueno);
      final r = interprete.interpretar('abre presupusto');
      expect(r, isA<OrdenParecida>());
      expect(opcionesDe(r).first, Rutas.finanzas);

      expect(opcionesDe(interprete.interpretar('abitos')).first, Rutas.habitos);
      expect(
        opcionesDe(interprete.interpretar('finansas')).first,
        Rutas.finanzas,
      );
      expect(
        opcionesDe(interprete.interpretar('ajsutes')).first,
        Rutas.ajustes,
      );
    });

    test('palabras a medias', () {
      final r = InterpreteOrdenes(rol: Rol.dueno).interpretar('abre presu');
      expect(r, isA<OrdenParecida>());
      // "presupuesto" y "presupuesto de la semana": primero Finanzas.
      expect(opcionesDe(r), [
        Rutas.finanzas,
        RutasDeHerramientas.semanaFinanzas,
      ]);
    });

    test('dos destinos a la vez', () {
      final r = InterpreteOrdenes(rol: Rol.dueno)
          .interpretar('abre finanzas y hábitos');
      expect(r, isA<OrdenParecida>());
      expect(opcionesDe(r), [Rutas.finanzas, Rutas.habitos]);
    });

    test('lo que no se parece a nada', () {
      final r = InterpreteOrdenes(
        rol: Rol.dueno,
        dispositivo: TipoDispositivo.laptop,
      ).interpretar('xyzzy');
      expect(r, isA<OrdenNoEntendida>());
      // Todo lo del dueño en la laptop menos la bandeja de la cuidadora.
      expect(opcionesDe(r), hasLength(herramientasNavegacion.length - 1));
      expect(opcionesDe(r), isNot(contains(RutasDeHerramientas.solicitudes)));
    });
  });

  group('Permisos', () {
    test('familiar: finanzas no existe, ni exacta ni parecida', () {
      final interprete = InterpreteOrdenes(rol: Rol.familiar);
      for (final orden in [
        'abre presupuesto',
        'abre finanzas',
        'dinero',
        'presupusto',
        'finansas',
      ]) {
        final r = interprete.interpretar(orden);
        expect(r, isNot(isA<OrdenEntendida>()), reason: orden);
        expect(opcionesDe(r), isNot(contains(Rutas.finanzas)), reason: orden);
      }
      expect(
        interprete.destinos.map((d) => d.ruta),
        isNot(contains(Rutas.finanzas)),
      );
      expect(rutaDe('ir a hábitos', rol: Rol.familiar), Rutas.habitos);
    });

    test('Desarrollador solo para el dueño', () {
      expect(rutaDe('desarrollador', rol: Rol.coadministrador), isNull);
      final r = InterpreteOrdenes(rol: Rol.coadministrador)
          .interpretar('swagger');
      expect(opcionesDe(r), isNot(contains(Rutas.desarrollador)));
    });

    test('cuidador: solo su bandeja de solicitudes (D18)', () {
      for (final dispositivo in [...TipoDispositivo.values, null]) {
        final interprete = InterpreteOrdenes(
          rol: Rol.cuidador,
          dispositivo: dispositivo,
        );
        expect(interprete.destinos.map((d) => d.nombre), [
          'gravity.abrir_solicitudes',
        ], reason: '$dispositivo');
      }
      for (final orden in [
        'abre solicitudes',
        'solicitudes',
        'mis recordatorios',
        'abre la bandeja',
      ]) {
        expect(
          rutaDe(orden, rol: Rol.cuidador),
          RutasDeHerramientas.solicitudes,
          reason: orden,
        );
      }
      // Nada de dinero, de la familia ni de los demás módulos desde GRAVITY
      // (Cuidados y sus ajustes los abre desde su navegación).
      final interprete = InterpreteOrdenes(rol: Rol.cuidador);
      for (final orden in [
        'abre presupuesto',
        'registrar gasto',
        'mi semana',
        'dinero',
        'presupusto',
        'abre hábitos',
        'abre recetas',
        'papá',
        'inicio',
        'ajustes',
      ]) {
        final r = interprete.interpretar(orden);
        expect(r, isNot(isA<OrdenEntendida>()), reason: orden);
        expect(
          opcionesDe(r),
          everyElement(RutasDeHerramientas.solicitudes),
          reason: orden,
        );
      }
      expect(
        interprete.sugerir('a').map((s) => s.destino.ruta),
        everyElement(RutasDeHerramientas.solicitudes),
      );
    });

    test('casa: sin Finanzas ni la bandeja', () {
      final interprete = InterpreteOrdenes(rol: Rol.casa);
      final nombres = interprete.destinos.map((d) => d.nombre).toList();
      expect(nombres, isNot(contains('gravity.abrir_solicitudes')));
      expect(
        interprete.destinos.where((d) => d.modulo == Modulo.finanzas),
        isEmpty,
      );
      for (final orden in [
        'abre presupuesto',
        'registrar gasto',
        'mi semana',
      ]) {
        expect(rutaDe(orden, rol: Rol.casa), isNull, reason: orden);
      }
    });

    test('puedeVer inyectable', () {
      final interprete = InterpreteOrdenes(
        rol: Rol.dueno,
        puedeVer: (m) => m != Modulo.habitos,
      );
      expect(interprete.interpretar('ir a hábitos'), isA<OrdenNoEntendida>());
      expect(
        interprete.sugerir('hab').map((s) => s.destino.ruta),
        isNot(contains(Rutas.habitos)),
      );
      expect(interprete.interpretar('abre finanzas'), isA<OrdenEntendida>());
    });

    test('puedeVer no amplía lo que el rol tiene prohibido', () {
      final interprete = InterpreteOrdenes(
        rol: Rol.familiar,
        puedeVer: (_) => true,
      );
      expect(
        interprete.interpretar('abre finanzas'),
        isNot(isA<OrdenEntendida>()),
      );
    });

    test('Desarrollador solo en la laptop (D16, M6)', () {
      expect(rutaDe('desarrollador'), Rutas.desarrollador);
      for (final dispositivo in [
        TipoDispositivo.telefono,
        TipoDispositivo.tablet,
        null,
      ]) {
        final interprete = InterpreteOrdenes(
          rol: Rol.dueno,
          dispositivo: dispositivo,
        );
        for (final orden in ['desarrollador', 'swagger', 'desarolador']) {
          final r = interprete.interpretar(orden);
          expect(
            r,
            isNot(isA<OrdenEntendida>()),
            reason: '$orden en $dispositivo',
          );
          expect(
            opcionesDe(r),
            isNot(contains(Rutas.desarrollador)),
            reason: '$orden en $dispositivo',
          );
        }
        expect(
          interprete.sugerir('desa').map((s) => s.destino.ruta),
          isNot(contains(Rutas.desarrollador)),
          reason: '$dispositivo',
        );
        expect(
          interprete.destinos.map((d) => d.ruta),
          isNot(contains(Rutas.desarrollador)),
        );
        // El resto sigue igual.
        expect(rutaDe('ajustes', dispositivo: dispositivo), Rutas.ajustes);
      }
    });

    test('módulos inactivos', () {
      final interprete = InterpreteOrdenes(
        rol: Rol.dueno,
        modulosActivos: const {Modulo.finanzas},
      );
      expect(interprete.interpretar('ir a hábitos'), isA<OrdenNoEntendida>());
      expect(interprete.interpretar('abre finanzas'), isA<OrdenEntendida>());
    });
  });

  group('Finanzas (Fase 1)', () {
    test('"abre presupuesto" y "abre finanzas" abren Finanzas', () {
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        for (final orden in [
          'abre presupuesto',
          'abre finanzas',
          'Abre el presupuesto',
          'ir a finanzas',
          'mi dinero',
        ]) {
          expect(
            destinoDe(orden, rol: rol)?.nombre,
            'finanzas.abrir',
            reason: '$orden / ${rol.name}',
          );
        }
      }
    });

    test('"registrar gasto" abre la hoja del gasto (no guarda nada)', () {
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        for (final orden in [
          'registrar gasto',
          'Registrar gasto',
          'REGISTRAR GASTO',
          'registra gasto',
          'Registra un gasto',
          'registrar un gasto',
          'registrar el gasto',
          '¡Registra un gasto, por favor!',
          'gravity, registrar gasto',
          'registrar gasto de 100 pesos',
        ]) {
          final destino = destinoDe(orden, rol: rol);
          expect(
            destino?.nombre,
            'finanzas.registrar_gasto',
            reason: '$orden / ${rol.name}',
          );
          expect(destino!.hoja, HojaDeRegistro.gasto);
          expect(destino.escribe, isFalse);
          expect(destino.soloLocal, isTrue);
        }
      }
    });

    test('el gasto exige el verbo (23/oct): la palabra suelta, "nuevo gasto" '
        'y "anota gasto" ya no abren la hoja', () {
      final gasto = herramientaRegistrarGasto;
      // Solo las frases con el verbo "registrar".
      expect(gasto.palabrasClave, [
        'registrar gasto',
        'registra gasto',
        'registrar un gasto',
        'registra un gasto',
      ]);
      for (final orden in [
        'gasto',
        'Gasto',
        'un gasto',
        'mi gasto',
        'nuevo gasto',
        'anota gasto',
        'anotar gasto',
        'apunta gasto',
      ]) {
        for (final rol in [Rol.dueno, Rol.coadministrador]) {
          final interprete = InterpreteOrdenes(
            rol: rol,
            dispositivo: TipoDispositivo.laptop,
          );
          // Nunca se entiende como una orden que abre algo: a lo más sale
          // "¿Quisiste decir…?", que no abre nada sin que la persona elija.
          final r = interprete.interpretar(orden);
          expect(
            r,
            isNot(isA<OrdenEntendida>()),
            reason: '$orden / ${rol.name}',
          );
          expect(r, isA<OrdenParecida>(), reason: '$orden / ${rol.name}');
        }
      }
    });

    test('"mi semana" abre la semana de Finanzas', () {
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        for (final orden in [
          'mi semana',
          'abre mi semana',
          'presupuesto semanal',
          'abre el presupuesto de la semana',
          '¿cuánto me queda?',
        ]) {
          expect(
            destinoDe(orden, rol: rol)?.ruta,
            RutasDeHerramientas.semanaFinanzas,
            reason: '$orden / ${rol.name}',
          );
        }
      }
    });

    test('familiar, cuidador y casa: ninguna orden de Finanzas', () {
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        final interprete = InterpreteOrdenes(
          rol: rol,
          dispositivo: TipoDispositivo.laptop,
        );
        expect(
          interprete.destinos.where((d) => d.modulo == Modulo.finanzas),
          isEmpty,
          reason: rol.name,
        );
        for (final orden in [
          'abre presupuesto',
          'abre finanzas',
          'registrar gasto',
          'mi semana',
          'gasto',
        ]) {
          final r = interprete.interpretar(orden);
          expect(r, isNot(isA<OrdenEntendida>()), reason: '$orden / $rol');
          expect(
            opcionesDe(r).where((ruta) => ruta.startsWith(Rutas.finanzas)),
            isEmpty,
            reason: '$orden / ${rol.name}',
          );
        }
      }
    });

    test('las sugerencias de Finanzas salen al escribir', () {
      final s = InterpreteOrdenes(rol: Rol.dueno).sugerir('regis');
      expect(s.first.destino.nombre, 'finanzas.registrar_gasto');
      final semana = InterpreteOrdenes(rol: Rol.dueno).sugerir('mi sem');
      expect(semana.first.destino.ruta, RutasDeHerramientas.semanaFinanzas);
    });
  });

  group('Cuenta maestra (D19)', () {
    test('no recibe nada que escriba o administre lo ajeno', () {
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        final maestra = InterpreteOrdenes(
          rol: rol,
          dispositivo: TipoDispositivo.laptop,
          esMaestra: true,
        );
        expect(
          maestra.destinos.map((d) => d.ruta),
          isNot(contains(Rutas.desarrollador)),
          reason: rol.name,
        );
        for (final d in maestra.destinos) {
          expect(
            d.pertenencia == Pertenencia.ajena && d.accion != Accion.leer,
            isFalse,
            reason: '${d.nombre} / ${rol.name}',
          );
        }
        expect(
          maestra.interpretar('desarrollador'),
          isNot(isA<OrdenEntendida>()),
        );
      }
    });

    test('la maestra con login propio (coadministrador) solo lee: Finanzas y '
        'su semana sí; la hoja de registro no (23/oct)', () {
      final maestra = InterpreteOrdenes(
        rol: Rol.coadministrador,
        dispositivo: TipoDispositivo.laptop,
        esMaestra: true,
      );
      for (final (orden, nombre) in [
        ('abre presupuesto', 'finanzas.abrir'),
        ('abre finanzas', 'finanzas.abrir'),
        ('mi semana', 'finanzas.abrir_semana'),
      ]) {
        expect(
          switch (maestra.interpretar(orden)) {
            OrdenEntendida(:final destino) => destino.nombre,
            _ => null,
          },
          nombre,
          reason: orden,
        );
      }
      // Ninguna hoja de registro: ni se entiende ni se sugiere ni se ofrece.
      expect(
        maestra.destinos.where(
          (d) => d.hoja != null || d.accion != Accion.leer,
        ),
        isEmpty,
      );
      for (final orden in [
        'registrar gasto',
        'registra un gasto',
        'registrar un gasto',
        'gasto',
        'regis',
      ]) {
        final r = maestra.interpretar(orden);
        expect(r, isNot(isA<OrdenEntendida>()), reason: orden);
        expect(
          destinosDe(r).where((d) => d.hoja != null),
          isEmpty,
          reason: orden,
        );
        expect(
          maestra.sugerir(orden).map((s) => s.destino.hoja),
          everyElement(isNull),
          reason: orden,
        );
      }
      // Sin la marca, la pareja sí la tiene.
      expect(
        destinoDe('registrar gasto', rol: Rol.coadministrador)?.nombre,
        'finanzas.registrar_gasto',
      );
    });

    test('el dueño que además es maestro conserva la hoja de su gasto', () {
      final maestro = InterpreteOrdenes(
        rol: Rol.dueno,
        dispositivo: TipoDispositivo.laptop,
        esMaestra: true,
      );
      for (final (orden, nombre) in [
        ('abre presupuesto', 'finanzas.abrir'),
        ('registrar gasto', 'finanzas.registrar_gasto'),
        ('mi semana', 'finanzas.abrir_semana'),
      ]) {
        expect(
          switch (maestro.interpretar(orden)) {
            OrdenEntendida(:final destino) => destino.nombre,
            _ => null,
          },
          nombre,
          reason: orden,
        );
      }
    });
  });

  group('Orden de ejemplo de la ayuda (M6)', () {
    test('nombra un destino que el rol sí ve', () {
      String? ejemplo(Rol rol) => InterpreteOrdenes(rol: rol).ejemplo;
      expect(ejemplo(Rol.dueno), 'abre presupuesto');
      expect(ejemplo(Rol.coadministrador), 'abre presupuesto');
      expect(ejemplo(Rol.familiar), 'abre hábitos');
      expect(ejemplo(Rol.cuidador), 'abre solicitudes');
    });

    test(
      'para cada rol, el ejemplo se entiende y no es Finanzas si no la ve',
      () {
        for (final rol in Rol.values) {
          final interprete = InterpreteOrdenes(
            rol: rol,
            dispositivo: TipoDispositivo.laptop,
          );
          final ejemplo = interprete.ejemplo;
          if (interprete.destinos.length <= 1) continue;
          expect(ejemplo, isNotNull, reason: rol.name);
          expect(
            interprete.interpretar(ejemplo!),
            isA<OrdenEntendida>(),
            reason: '${rol.name}: $ejemplo',
          );
          final veFinanzas = interprete.destinos.any(
            (d) => d.ruta == Rutas.finanzas,
          );
          if (!veFinanzas) {
            expect(ejemplo, isNot(contains('presupuesto')), reason: rol.name);
          }
        }
      },
    );

    test('sin destinos, no hay ejemplo', () {
      final interprete = InterpreteOrdenes(
        rol: Rol.dueno,
        puedeVer: (_) => false,
      );
      expect(interprete.ejemplo, isNull);
    });
  });

  group('Sugerencias mientras se escribe', () {
    List<String> rutas(String texto, {Rol rol = Rol.dueno, int maximo = 5}) => [
      for (final s in InterpreteOrdenes(
        rol: rol,
      ).sugerir(texto, maximo: maximo))
        s.destino.ruta,
    ];

    test('por prefijo, con la palabra que coincidió', () {
      final s = InterpreteOrdenes(rol: Rol.dueno).sugerir('abre pre');
      expect(s.first.destino.ruta, Rutas.finanzas);
      expect(s.first.palabra, 'presupuesto');
      expect(rutas('fin').first, Rutas.finanzas);
      expect(rutas('ir a háb').first, Rutas.habitos);
    });

    test('si coincide el nombre, no repite la palabra', () {
      final s = InterpreteOrdenes(rol: Rol.dueno).sugerir('finanzas');
      expect(s.first.destino.ruta, Rutas.finanzas);
      expect(s.first.palabra, isNull);
    });

    test('una letra ya sugiere', () {
      expect(
        rutas('a', maximo: 8),
        containsAll([Rutas.ajustes, Rutas.alimentacion]),
      );
    });

    test('con errores de dedo', () {
      expect(rutas('presup').first, Rutas.finanzas);
      expect(rutas('finanz').first, Rutas.finanzas);
      expect(rutas('fimanzas').first, Rutas.finanzas);
      expect(rutas('abre recteas ').first, Rutas.alimentacion);
    });

    test('solo el verbo: todos los destinos del rol', () {
      expect(rutas('abre ', rol: Rol.familiar, maximo: 10), [
        Rutas.inicio,
        Rutas.habitos,
        Rutas.alimentacion,
        Rutas.casa,
        Rutas.ajustes,
      ]);
    });

    test('nunca sugiere lo que el rol no ve', () {
      for (final texto in ['fin', 'pre', 'din', 'desa', 'swa', 'a', 'abre ']) {
        expect(
          rutas(texto, rol: Rol.familiar, maximo: 10),
          isNot(anyOf(contains(Rutas.finanzas), contains(Rutas.desarrollador))),
          reason: texto,
        );
      }
    });

    test('respeta el máximo y el texto vacío', () {
      expect(rutas('abre ', maximo: 3), hasLength(3));
      expect(rutas(''), isEmpty);
      expect(rutas('qqqq'), isEmpty);
    });
  });
}
