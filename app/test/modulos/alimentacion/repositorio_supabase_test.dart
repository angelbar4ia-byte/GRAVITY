// Repositorio de Alimentación con Supabase, con una fuente de tablas falsa.
// Nombres reales del servidor: el precio vive en `ali_ingredientes` y el
// historial en `ali_precios_historial` (no existe `ali_precios`).
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/alimentacion/repositorio_alimentacion_supabase.dart';
import 'package:gravity/modulos/alimentacion/datos/modelos.dart';
import 'package:gravity/modulos/alimentacion/datos/votacion.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';

const _hogar = '00000000-0000-4000-8000-000000000001';
const _yo = '00000000-0000-4000-8000-0000000000a1';
const _otra = '00000000-0000-4000-8000-0000000000a2';
const _v1 = '00000000-0000-4000-8000-0000000000b1';
const _o1 = '00000000-0000-4000-8000-0000000000c1';
const _o2 = '00000000-0000-4000-8000-0000000000c2';
const _pl1 = '00000000-0000-4000-8000-0000000000d1';

/// Anota a qué tablas se escribió directo.
class _Fuente extends FuenteTablasEnMemoria {
  final escrituras = <String>[];

  @override
  Future<void> guardar(
    String tabla,
    List<Map<String, Object?>> filas, {
    String conflicto = 'id',
    bool ignorarDuplicados = false,
  }) {
    escrituras.add(tabla);
    return super.guardar(
      tabla,
      filas,
      conflicto: conflicto,
      ignorarDuplicados: ignorarDuplicados,
    );
  }

  @override
  Future<void> borrar(String tabla, {required Map<String, Object?> donde}) {
    escrituras.add(tabla);
    return super.borrar(tabla, donde: donde);
  }

  @override
  Future<void> actualizar(
    String tabla,
    Map<String, Object?> cambios, {
    required Map<String, Object?> donde,
  }) {
    escrituras.add(tabla);
    return super.actualizar(tabla, cambios, donde: donde);
  }
}

RepositorioAlimentacionSupabase _repo(_Fuente f, {String yo = _yo}) =>
    RepositorioAlimentacionSupabase(
      fuente: f,
      hogarId: _hogar,
      personaId: yo,
      nombre: 'Yo',
    );

/// Tablas que nunca se escriben directo (dinero, precio real, votos, tomas).
const _soloRpc = {
  'ali_votaciones',
  'ali_votacion_opciones',
  'ali_opcion_platillos',
  'ali_votos',
  'ali_compras',
  'ali_solicitudes_pago',
  'ali_precios_historial',
  'ali_despensa',
  'ali_tomas_suplemento',
  'ali_reposiciones_suplemento',
  'fin_movimientos',
};

void main() {
  group('Lectura', () {
    test('platillos: ingredientes, duros, pasos y porciones', () async {
      final f = _Fuente();
      f.tabla('ali_platillos').add({
        'id': _pl1,
        'nombre': 'Caldo',
        'ingredientes': [
          {
            'nombre': 'Pollo',
            'cantidad': 150,
            'unidad': 'g',
            'seccion': 'carnesPescados',
          },
          {
            'nombre': 'Sal',
            'cantidad': 1.5,
            'unidad': 'pizca',
            'seccion': 'rara',
          },
        ],
        'duros': ['zanahoria cruda'],
      });
      f.tabla('ali_recetas').add({
        'id': 'r1',
        'platillo_id': _pl1,
        'titulo': 'Caldo',
        'porciones': 4,
      });
      f.tabla('ali_receta_pasos')
        ..add({'receta_id': 'r1', 'orden': 2, 'texto': 'Servir'})
        ..add({'receta_id': 'r1', 'orden': 1, 'texto': 'Hervir'});
      final p = (await _repo(f).platillos()).single;
      expect(p.nombre, 'Caldo');
      expect(p.ingredientes.first.seccion, SeccionCompra.carnesPescados);
      expect(p.ingredientes.last.seccion, SeccionCompra.otros);
      expect(p.ingredientes.first.cantidad, 150);
      expect(p.duros, ['zanahoria cruda']);
      expect(p.pasos, ['Hervir', 'Servir']);
      expect(p.porciones, 4);
    });

    test('el precio real reemplaza al base; sin precio no hay clave', () async {
      final f = _Fuente();
      f.tabla('ali_ingredientes')
        ..add({
          'id': 'i1',
          'nombre': 'Leche',
          'unidad': 'ml',
          'precio_base_centavos': 20,
          'precio_real_centavos': 28,
        })
        ..add({
          'id': 'i2',
          'nombre': 'Huevo',
          'unidad': 'pza',
          'precio_base_centavos': 300,
          'precio_real_centavos': null,
        })
        ..add({
          'id': 'i3',
          'nombre': 'Sal',
          'unidad': 'g',
          'precio_base_centavos': null,
          'precio_real_centavos': null,
        });
      final p = await _repo(f).precios();
      final leche = p[claveCompra('Leche', 'ml')]!;
      expect(leche.centavos, 28);
      expect(leche.esBase, isFalse);
      final huevo = p[claveCompra('Huevo', 'pza')]!;
      expect(huevo.centavos, 300);
      expect(huevo.esBase, isTrue);
      expect(huevo.nota, isNotNull);
      expect(p.containsKey(claveCompra('Sal', 'g')), isFalse);
    });

    test('historial de compras reales desde ali_precios_historial', () async {
      final f = _Fuente();
      f.tabla('ali_ingredientes').add({
        'id': 'i1',
        'nombre': 'Leche',
        'unidad': 'ml',
      });
      f.tabla('ali_precios_historial').add({
        'ingrediente_id': 'i1',
        'precio_centavos': 28,
        'registrado_en': '2026-11-02T10:00:00Z',
      });
      final h = await _repo(f).historialCompras();
      expect(h.single.clave, claveCompra('Leche', 'ml'));
      expect(h.single.unitarioCentavos, 28);
    });

    test('menú y marcas de la semana', () async {
      final f = _Fuente();
      f.tabla('ali_menu')
        ..add({
          'menu': 'papa',
          'semana': '2026-11-02',
          'dia': 0,
          'tiempo': 'cena',
          'platillo_id': _pl1,
        })
        ..add({
          'menu': 'pareja',
          'semana': '2026-11-02',
          'dia': 1,
          'tiempo': 'comida',
          'platillo_id': _pl1,
        })
        ..add({
          'menu': 'papa',
          'semana': '2026-10-26',
          'dia': 2,
          'tiempo': 'comida',
          'platillo_id': _pl1,
        });
      f.tabla('ali_compras_marcas').add({
        'menu': 'papa',
        'semana': '2026-11-02',
        'clave': 'leche|ml',
      });
      final r = _repo(f);
      final lunes = DateTime(2026, 11, 2);
      final m = await r.menu(MenuId.papa, lunes);
      expect(m.length, 1);
      expect(m.single.tiempo, TiempoComida.cena);
      expect(await r.comprados(MenuId.papa, lunes), {'leche|ml'});
      expect(await r.comprados(MenuId.pareja, lunes), isEmpty);
    });
  });

  group('Votación por RPC', () {
    void sembrar(_Fuente f, {Map<String, String> votos = const {}}) {
      f.tabla('ali_votaciones').add({
        'id': _v1,
        'cuenta': 'casa',
        'para_el': '2026-11-09',
        'creada_en': '2026-11-08T12:00:00Z',
        'estado': 'abierta',
        'ganadora_id': null,
        'ganadora_por_volado': false,
      });
      f.tabla('ali_votacion_opciones')
        ..add({
          'id': _o1,
          'votacion_id': _v1,
          'orden': 1,
          'propuesto_por': _otra,
          'titulo': 'Pastas',
        })
        ..add({
          'id': _o2,
          'votacion_id': _v1,
          'orden': 2,
          'propuesto_por': _yo,
          'titulo': 'Tacos',
        });
      for (final e in votos.entries) {
        f.tabla('ali_votos').add({
          'votacion_id': _v1,
          'persona_id': e.key,
          'opcion_id': e.value,
        });
      }
    }

    test('lee propuestas y votos del servidor', () async {
      final f = _Fuente();
      sembrar(f, votos: {_otra: _o1});
      final v = (await _repo(f).votacion(DateTime(2026, 11, 9)))!;
      expect(v.propuestas.map((p) => p.titulo), ['Pastas', 'Tacos']);
      expect(v.conteo(_o1), 1);
      expect(v.propuestas[1].autorNombre, 'Yo');
      expect(await _repo(f).votacion(DateTime(2026, 11, 10)), isNull);
    });

    test(
      'votar y cambiar el voto llama ali_votar con la opción nueva',
      () async {
        final f = _Fuente();
        sembrar(f, votos: {_yo: _o1});
        final r = _repo(f);
        final ahora = DateTime.utc(2026, 11, 8, 15);
        var v = (await r.votacion(DateTime(2026, 11, 9)))!;
        v = v.conVoto(_yo, _o2, ahora); // cambio de voto
        await r.guardarVotacion(v);
        final llamadas = f.llamadas.where((l) => l.$1 == 'ali_votar').toList();
        expect(llamadas.length, 1);
        expect(llamadas.single.$2, {'p_votacion': _v1, 'p_opcion': _o2});
        // Votar lo mismo otra vez no llama al servidor.
        f.tabla('ali_votos')
          ..clear()
          ..add({'votacion_id': _v1, 'persona_id': _yo, 'opcion_id': _o2});
        f.llamadas.clear();
        await r.guardarVotacion((await r.votacion(DateTime(2026, 11, 9)))!);
        expect(f.llamadas.where((l) => l.$1 == 'ali_votar'), isEmpty);
      },
    );

    test('proponer abre con ali_proponer_menu y la segunda con ali_proponer_alternativa', () async {
      final f = _Fuente();
      f.funciones['ali_proponer_menu'] = (p) {
        sembrar(f);
        f.tabla('ali_votacion_opciones')
          ..removeWhere((o) => o['orden'] == 2)
          ..first['propuesto_por'] = _yo;
        return _v1;
      };
      final r = _repo(f);
      final dia = DateTime(2026, 11, 9);
      final ahora = DateTime.utc(2026, 11, 8, 15);
      var v = VotacionPlan(id: 'v-x', dia: dia, abiertaEn: ahora).conPropuesta(
        const PropuestaMenu(
          id: 'v-x-p1',
          autorId: _yo,
          autorNombre: 'Yo',
          titulo: 'Pastas',
          platilloIds: [_pl1, 'p-local'],
        ),
        ahora,
      );
      await r.guardarVotacion(v);
      final m = f.llamadas.singleWhere((l) => l.$1 == 'ali_proponer_menu').$2;
      expect(m['p_titulo'], 'Pastas');
      expect(m['p_platillos'], [_pl1], reason: 'solo ids de servidor');
      expect(m['p_cuenta'], 'casa');
      expect(m['p_para_el'], '2026-11-09');

      final actual = (await r.votacion(dia))!;
      v = actual.conPropuesta(
        const PropuestaMenu(
          id: 'nuevo',
          autorId: _otra,
          autorNombre: 'Otra',
          titulo: 'Tacos',
        ),
        ahora,
      );
      await r.guardarVotacion(v);
      expect(
        f.llamadas.where((l) => l.$1 == 'ali_proponer_alternativa').length,
        1,
      );
    });

    test('volado: el ganador lo fija el servidor', () async {
      final f = _Fuente();
      sembrar(f);
      f.tabla('ali_votaciones').first
        ..['estado'] = 'cerrada'
        ..['ganadora_id'] = _o2
        ..['ganadora_por_volado'] = true;
      final v = (await _repo(f).votacion(DateTime(2026, 11, 9)))!;
      expect(v.ganadoraVoladoId, _o2);
      await _repo(f).cerrarVotacionesVencidas(DateTime.now());
      expect(f.llamadas.single.$1, 'ali_cerrar_votaciones');
      expect(f.llamadas.single.$2, {'p_hogar_id': _hogar});
    });
  });

  group('Presupuesto: sí o no, sin cifras', () {
    test('devuelve solo true o false', () async {
      final f = _Fuente();
      f.funciones['ali_hay_presupuesto'] = (p) =>
          (p['p_monto_centavos'] as int) <= 5000;
      final r = _repo(f);
      expect(await r.hayPresupuestoPara(4000), isTrue);
      expect(await r.hayPresupuestoPara(9000), isFalse);
      expect(await r.hayPresupuesto(), isTrue);
      expect(f.llamadas.first.$2['p_hogar_id'], _hogar);
    });

    test(
      'un servidor que responde otra cosa, o sin señal, es "sin respuesta"',
      () async {
        final f = _Fuente();
        f.funciones['ali_hay_presupuesto'] = (p) => {'saldo': 12345};
        expect(await _repo(f).hayPresupuesto(), isNull);
        f.sinSenal = true;
        expect(await _repo(f).hayPresupuesto(), isNull);
      },
    );
  });

  group('Solo RPC para dinero, votos y tomas', () {
    test('el precio real no se escribe directo', () async {
      final f = _Fuente();
      final r = _repo(f);
      await expectLater(
        r.guardarPrecio(
          PrecioIngrediente.deCompra(
            clave: 'leche|ml',
            totalCentavos: 2800,
            cantidadComprada: 1000,
          ),
        ),
        throwsA(isA<ErrorAlimentacionServidor>()),
      );
      await expectLater(
        r.guardarCompraPrecio(
          CompraPrecio(
            clave: 'leche|ml',
            nombre: 'Leche',
            unidad: 'ml',
            totalCentavos: 2800,
            cantidad: 1000,
            fecha: DateTime(2026, 11, 8),
          ),
        ),
        throwsA(isA<ErrorAlimentacionServidor>()),
      );
      expect(f.escrituras, isEmpty);
    });

    test('el precio base sí se escribe, solo en ali_ingredientes', () async {
      final f = _Fuente();
      await _repo(f).guardarPrecio(
        const PrecioIngrediente(
          clave: 'leche|ml',
          centavos: 2800,
          porCantidad: 1000,
          esBase: true,
        ),
      );
      expect(f.escrituras, ['ali_ingredientes']);
      final fila = f.tabla('ali_ingredientes').single;
      expect(fila['precio_base_centavos'], 3);
      expect(fila.containsKey('precio_real_centavos'), isFalse);
    });

    test(
      'las RPC del servidor van con los nombres y parámetros exactos',
      () async {
        final f = _Fuente();
        f.funciones['ali_sobrantes'] = (p) => [
          {
            'ingrediente_id': 'i1',
            'nombre': 'Arroz',
            'unidad': 'g',
            'pasillo': 'Abarrotes',
            'sobrante': 200,
          },
        ];
        f.funciones['ali_menu_del_dia_papa'] = (p) => [
          {'tiempo': 'desayuno', 'platillo': 'Avena'},
        ];
        f.funciones['ali_faltantes'] = (p) => [
          {
            'ingrediente_id': 'i1',
            'nombre': 'Arroz',
            'unidad': 'g',
            'necesario': 300,
            'disponible': null,
            'faltante': 300,
          },
        ];
        final r = _repo(f);
        await r.marcarComprada(
          compraId: 'c1',
          montoCentavos: 5000,
          cuentaOrigen: 'a',
          cuentaGasto: 'b',
        );
        await r.solicitarCompra(
          cuenta: 'papa',
          ingredienteId: 'i1',
          cantidad: 2,
        );
        await r.resolverSolicitudPago(
          solicitudId: 's1',
          aprobar: false,
          motivo: 'Sin fondos',
        );
        expect((await r.sobrantes('pareja')).single.cantidad, 200);
        expect((await r.menuDelDiaPapa()).single.platillo, 'Avena');
        await r.proponerMenu(titulo: 'x');
        await r.proponerAlternativa(votacionId: _v1, titulo: 'y');
        await r.votar(votacionId: _v1, opcionId: _o1);
        await r.cerrarVotaciones();
        expect((await r.faltantes(_v1)).single.disponible, isNull);
        await r.pedirCompraFaltantes(_v1);
        await r.programarToma(
          suplementoId: 's',
          previstaEn: DateTime.utc(2026, 11, 9, 8),
        );
        await r.confirmarToma(tomaId: 't', dado: true);
        await r.revisarTomas();
        await r.resolverReposicion(reposicionId: 'r', atendida: true);
        expect(f.llamadas.map((l) => l.$1).toList(), [
          'ali_marcar_comprada',
          'ali_solicitar_compra',
          'ali_resolver_solicitud_pago',
          'ali_sobrantes',
          'ali_menu_del_dia_papa',
          'ali_proponer_menu',
          'ali_proponer_alternativa',
          'ali_votar',
          'ali_cerrar_votaciones',
          'ali_faltantes',
          'ali_pedir_compra_faltantes',
          'ali_programar_toma',
          'ali_confirmar_toma',
          'ali_revisar_tomas',
          'ali_resolver_reposicion',
        ]);
        expect(f.llamadas[0].$2, {
          'p_compra': 'c1',
          'p_monto_centavos': 5000,
          'p_cuenta_origen': 'a',
          'p_cuenta_gasto': 'b',
        });
        expect(f.escrituras, isEmpty, reason: 'ningún insert directo');
      },
    );

    test(
      'un flujo completo de edición no toca tablas de dinero, votos ni tomas',
      () async {
        final f = _Fuente();
        final r = _repo(f);
        await r.guardarPlatillos([
          const Platillo(
            'imp-sopa',
            'Sopa',
            [Ingrediente('Fideo', 100, 'g', SeccionCompra.abarrotes)],
            pasos: ['Hervir'],
            porciones: 2,
          ),
        ]);
        await r.asignar(
          MenuId.papa,
          DateTime(2026, 11, 2),
          0,
          TiempoComida.comida,
          _pl1,
        );
        await r.marcar(MenuId.papa, DateTime(2026, 11, 2), 'fideo|g', true);
        await r.guardarSuplemento(
          MenuId.papa,
          const Suplemento(
            id: 's1',
            nombre: 'Omega',
            dosis: '1',
            horario: 'Comida',
          ),
        );
        await r.quitarSuplemento(MenuId.papa, 's1');
        await r.asignar(
          MenuId.papa,
          DateTime(2026, 11, 2),
          0,
          TiempoComida.comida,
          null,
        );
        expect(f.escrituras.toSet().intersection(_soloRpc), isEmpty);
        expect(
          f.escrituras.toSet(),
          containsAll([
            'ali_platillos',
            'ali_recetas',
            'ali_receta_pasos',
            'ali_menu',
            'ali_compras_marcas',
            'ali_suplementos',
          ]),
        );
        // El platillo importado quedó con un UUID estable y sus pasos.
        final id = f.tabla('ali_platillos').single['id'] as String;
        expect(id.length, 36);
        expect((await r.platillos()).single.pasos, ['Hervir']);
      },
    );
  });
}
