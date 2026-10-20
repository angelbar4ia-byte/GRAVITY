import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/ordenes/interprete_ordenes.dart';
import 'package:gravity/modulos/gravity/ordenes/texto_ordenes.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';

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
      expect(opcionesDe(r), [Rutas.finanzas]);
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
      expect(opcionesDe(r), hasLength(8));
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

    test('cuidador: solo Cuidados y sus ajustes', () {
      final interprete = InterpreteOrdenes(rol: Rol.cuidador);
      expect(interprete.destinos.map((d) => d.ruta), [
        Rutas.cuidados,
        Rutas.ajustes,
      ]);
      expect(rutaDe('papá', rol: Rol.cuidador), Rutas.cuidados);
      expect(rutaDe('abre recetas', rol: Rol.cuidador), isNull);
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

  group('Orden de ejemplo de la ayuda (M6)', () {
    test('nombra un destino que el rol sí ve', () {
      String? ejemplo(Rol rol) => InterpreteOrdenes(rol: rol).ejemplo;
      expect(ejemplo(Rol.dueno), 'abre presupuesto');
      expect(ejemplo(Rol.familiar), 'abre hábitos');
      expect(ejemplo(Rol.cuidador), 'abre cuidados');
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
