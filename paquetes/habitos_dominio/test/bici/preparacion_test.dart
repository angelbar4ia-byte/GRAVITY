import 'dart:convert';

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

Set<String> ids(List<PuntoPreparacion> p) => {for (final x in p) x.id};

void main() {
  const viernes = {
    'bici_revisada',
    'luces_cargadas',
    'telefono_cargando',
    'agua_lista',
    'comida_lista',
    'herramientas',
    'ropa_lista',
    'clima_visto',
  };
  const antes = {
    'casco_puesto',
    'luces_puestas',
    'frenos_probados',
    'presion_llantas',
    'protector_solar',
    'escucha_exterior',
    'aviso_regreso',
  };
  const calle = {'ropa_visible', 'luces_siempre'};
  const terreno = {'llantas_frenos_terreno'};

  group('CA-B-13 lista de preparación', () {
    test('los dos momentos son los de 4.2', () {
      expect(
        ids(puntosPreparacion(momento: MomentoPreparacion.viernes)),
        viernes,
      );
      expect(
        ids(
          puntosPreparacion(
            momento: MomentoPreparacion.antesDeSalir,
            superficie: SuperficieSalida.mixta,
          ),
        ),
        {...antes, ...calle, ...terreno},
      );
    });

    test('por tipo de ruta: calle, terreno, mixta y sin ruta (todos)', () {
      Set<String> deAntes(SuperficieSalida? s) => ids(
        puntosPreparacion(
          momento: MomentoPreparacion.antesDeSalir,
          superficie: s,
        ),
      );
      expect(deAntes(SuperficieSalida.calle), {...antes, ...calle});
      expect(deAntes(SuperficieSalida.terreno), {...antes, ...terreno});
      expect(deAntes(SuperficieSalida.mixta), {...antes, ...calle, ...terreno});
      expect(deAntes(null), {...antes, ...calle, ...terreno});
      // `herramientas` sale en el viernes para los tres tipos (ya arriba).
      for (final s in SuperficieSalida.values) {
        expect(
          ids(
            puntosPreparacion(
              momento: MomentoPreparacion.viernes,
              superficie: s,
            ),
          ),
          contains('herramientas'),
        );
      }
    });

    test('los ids del catálogo son únicos', () {
      final todos = [for (final p in catalogoPreparacion) p.id];
      expect(todos.toSet().length, todos.length);
    });

    test('la persona apaga un punto y deja de salir', () {
      final personal = const PreparacionPersonal().conActivo(
        'agua_lista',
        false,
      );
      final p = puntosPreparacion(
        momento: MomentoPreparacion.viernes,
        personal: personal,
      );
      expect(ids(p), viernes.difference({'agua_lista'}));
      // Volver a encenderlo.
      expect(
        ids(
          puntosPreparacion(
            momento: MomentoPreparacion.viernes,
            personal: personal.conActivo('agua_lista', true),
          ),
        ),
        viernes,
      );
    });

    test('agrega hasta 10 puntos propios de 60 caracteres; el once se '
        'rechaza', () {
      var p = const PreparacionPersonal();
      for (var i = 1; i <= 10; i++) {
        expect(p.errorAlAgregar('Punto $i'), isNull);
        p = p.conPropio('Punto $i');
      }
      expect(p.propios, hasLength(10));
      expect(p.errorAlAgregar('Punto 11')!.codigo, 'propios_de_mas');
      expect(() => p.conPropio('Punto 11'), throwsArgumentError);
      expect(p.propios, hasLength(10)); // no cambió
      // Quitar uno libera el lugar.
      expect(p.sinPropio(0).errorAlAgregar('Otro'), isNull);
    });

    test('un punto propio de 60 caracteres entra y uno de 61 no', () {
      const p = PreparacionPersonal();
      expect(p.errorAlAgregar('a' * 60), isNull);
      expect(p.errorAlAgregar('a' * 61)!.codigo, 'propio_largo');
      expect(p.errorAlAgregar('   ')!.codigo, 'propio_vacio');
    });

    test('los propios salen al final de la lista', () {
      final personal = const PreparacionPersonal().conPropio(
        'Cargar la cámara',
      );
      final p = puntosPreparacion(
        momento: MomentoPreparacion.viernes,
        personal: personal,
      );
      expect(p.last.texto, 'Cargar la cámara');
      expect(p.last.propio, isTrue);
      expect(p, hasLength(9));
    });

    test('marcar y desmarcar son un toque y no bloquean nada', () {
      final p = puntosPreparacion(momento: MomentoPreparacion.viernes);
      var marcas = <String>{};
      expect(progresoPreparacion(p, marcas).marcados, 0);
      expect(progresoPreparacion(p, marcas).bloquea, isFalse);
      marcas = alternarMarca(marcas, 'agua_lista');
      expect(progresoPreparacion(p, marcas).marcados, 1);
      marcas = alternarMarca(marcas, 'agua_lista');
      expect(progresoPreparacion(p, marcas).marcados, 0);
      // «8 de 8»
      marcas = {for (final x in p) x.id};
      final todo = progresoPreparacion(p, marcas);
      expect((todo.marcados, todo.total, todo.completa), (8, 8, true));
      expect(todo.bloquea, isFalse);
      expect(progresoPreparacion(const [], {}).completa, isFalse);
    });

    test(
      'la preparación guardada es lista de {id, activo} y propios {texto}',
      () {
        final p = const PreparacionPersonal()
            .conActivo('agua_lista', false)
            .conPropio('Cargar la cámara');
        final j = p.aJson();
        final cat = j['catalogo'] as List;
        expect(cat, hasLength(catalogoPreparacion.length));
        expect(
          cat.cast<Map>().firstWhere((x) => x['id'] == 'agua_lista')['activo'],
          isFalse,
        );
        expect(j['propios'], [
          {'texto': 'Cargar la cámara'},
        ]);
        final de = PreparacionPersonal.desdeJson(j);
        expect(de.apagados, {'agua_lista'});
        expect(de.propios, ['Cargar la cámara']);
      },
    );

    test('ningún texto lleva cifras de líquidos o de comida (CA-B-01)', () {
      expect(
        validarContenidoBici([for (final p in catalogoPreparacion) p.texto]),
        isEmpty,
      );
    });

    test(
      'con 10 propios de 60 caracteres la preparación cabe en 4 KB (5.2)',
      () {
        var p = const PreparacionPersonal();
        for (var i = 0; i < 10; i++) {
          p = p.conPropio('p' * 60);
        }
        expect(utf8.encode(jsonEncode(p.aJson())).length, lessThan(4096));
      },
    );
  });
}
