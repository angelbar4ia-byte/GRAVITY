// Repositorio de Alimentación con Supabase, con una fuente de tablas falsa.
// Nombres reales del servidor: el precio vive en `ali_ingredientes` y el
// historial en `ali_precios_historial` (no existe `ali_precios`).
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/alimentacion/repositorio_alimentacion_supabase.dart';
import 'package:gravity/modulos/alimentacion/casos_uso/servicio_alimentacion.dart';
import 'package:gravity/modulos/alimentacion/datos/modelos.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/modulos/alimentacion/datos/votacion.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart' show ErrorFinanzas;

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
  final leidas = <String>[];

  @override
  Future<List<Map<String, dynamic>>> leer(
    String tabla, {
    String columnas = '*',
  }) {
    leidas.add(tabla);
    return super.leer(tabla, columnas: columnas);
  }

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
    test('el precio real no se escribe directo y tampoco falla', () async {
      final f = _Fuente();
      final r = _repo(f);
      await r.guardarPrecio(
        PrecioIngrediente.deCompra(
          clave: 'leche|ml',
          totalCentavos: 2800,
          cantidadComprada: 1000,
        ),
      );
      await r.guardarCompraPrecio(
        CompraPrecio(
          clave: 'leche|ml',
          nombre: 'Leche',
          unidad: 'ml',
          totalCentavos: 2800,
          cantidad: 1000,
          fecha: DateTime(2026, 11, 8),
        ),
      );
      expect(f.escrituras, isEmpty);
      expect(f.llamadas, isEmpty);
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

  group('Conexión de Alimentación (cierre de pendientes)', () {
    final lunes = DateTime(2026, 11, 2);
    const ing = '00000000-0000-4000-8000-0000000000e1';
    const fila = '00000000-0000-4000-8000-0000000000f1';
    const cuentaPago = '00000000-0000-4000-8000-0000000000aa';
    const libro = '00000000-0000-4000-8000-0000000000ab';
    final compra = CompraPrecio(
      clave: 'leche|ml',
      nombre: 'Leche',
      unidad: 'ml',
      totalCentavos: 2800,
      cantidad: 1000,
      fecha: DateTime(2026, 11, 8),
    );
    final precio = PrecioIngrediente.deCompra(
      clave: 'leche|ml',
      totalCentavos: 2800,
      cantidadComprada: 1000,
    );
    const sinDinero = {
      'fin_movimientos',
      'ali_precios_historial',
      'ali_despensa',
      'ali_solicitudes_pago',
      'ali_votos',
    };

    _Fuente conLista() {
      final f = _Fuente();
      f.tabla('ali_ingredientes').add({
        'id': ing,
        'nombre': 'Leche',
        'unidad': 'ml',
        'pasillo': 'Lácteos y huevo',
      });
      f.tabla('ali_compras').add({
        'id': fila,
        'cuenta': 'papa',
        'ingrediente_id': ing,
        'cantidad': 1000,
        'comprado': false,
        'para_el': null,
      });
      return f;
    }

    test('la compra real llama a ali_marcar_comprada y no escribe dinero',
        () async {
      final f = conLista();
      f.funciones['ali_marcar_comprada'] = (p) => {
        'estado_pago': 'movimiento',
        'precio_real_centavos': 3,
      };
      f.tabla('fin_libros').add({
        'id': libro,
        'tipo': 'personal',
        'titular_id': _yo,
      });
      f.tabla('fin_cuentas').add({
        'id': cuentaPago,
        'libro_id': libro,
        'tipo': 'banco',
        'estado': 'activa',
        'nombre': 'Débito',
      });
      f.tabla('ali_compras')
        ..clear()
        ..add({
          'id': fila,
          'cuenta': 'dueno',
          'ingrediente_id': ing,
          'cantidad': 1000,
          'comprado': false,
        });
      final res = await _repo(f).registrarCompraReal(
        menu: MenuId.pareja,
        lunes: lunes,
        compra: compra,
        precio: precio,
        cuenta: CuentaCompra.dueno,
      );
      expect(res.pendienteAlbacea, isFalse);
      final llamada = f.llamadas.single;
      expect(llamada.$1, 'ali_marcar_comprada');
      expect(llamada.$2, {
        'p_compra': fila,
        'p_monto_centavos': 2800,
        'p_cuenta_origen': cuentaPago,
        'p_cuenta_gasto': null,
      });
      // Solo la marca de la lista: nada de dinero, precio ni historial.
      expect(f.escrituras.toSet().intersection(sinDinero), isEmpty);
      expect(f.escrituras.toSet().difference({'ali_compras_marcas'}), isEmpty);
    });

    test('compra de Papá sin cuenta de pago: pendiente del albacea, no error',
        () async {
      final f = conLista();
      f.funciones['ali_marcar_comprada'] = (p) => {
        'estado_pago': 'solicitud',
        'solicitud_id': 's1',
      };
      final res = await _repo(f).registrarCompraReal(
        menu: MenuId.papa,
        lunes: lunes,
        compra: compra,
        precio: precio,
        cuenta: CuentaCompra.papa,
      );
      expect(res.pendienteAlbacea, isTrue);
      expect(f.llamadas.single.$2['p_cuenta_origen'], isNull);
      expect(f.llamadas.single.$2['p_compra'], fila);
    });

    test('sin fila en ali_compras la pide (papa y casa por RPC)', () async {
      final f = _Fuente();
      f.funciones['ali_solicitar_compra'] = (p) => fila;
      f.funciones['ali_marcar_comprada'] = (p) => {'estado_pago': 'solicitud'};
      await _repo(f).registrarCompraReal(
        menu: MenuId.papa,
        lunes: lunes,
        compra: compra,
        precio: precio,
        cuenta: CuentaCompra.papa,
      );
      expect(f.llamadas.map((l) => l.$1), [
        'ali_solicitar_compra',
        'ali_marcar_comprada',
      ]);
      expect(f.llamadas.first.$2['p_cuenta'], 'papa');
      expect(f.llamadas.first.$2['p_cantidad'], 1000);
      // El ingrediente faltante se crea sin precio; nada de dinero.
      expect(f.tabla('ali_ingredientes').single.containsKey('precio_real_centavos'),
          isFalse);
      expect(f.escrituras.toSet().intersection(sinDinero), isEmpty);
    });

    test('un fallo del servidor sale con su mensaje', () async {
      final f = conLista();
      f.sinSenal = true;
      await expectLater(
        _repo(f).registrarCompraReal(
          menu: MenuId.papa,
          lunes: lunes,
          compra: compra,
          precio: precio,
          cuenta: CuentaCompra.papa,
        ),
        throwsA(isA<ErrorAlimentacionServidor>()),
      );
    });

    test('la lista del servidor sale de ali_compras con el pasillo', () async {
      final f = conLista();
      f.tabla('ali_compras').add({
        'id': 'otra',
        'cuenta': 'dueno',
        'ingrediente_id': ing,
        'cantidad': 2,
        'comprado': true,
        'estado_pago': 'movimiento',
        'para_el': '2026-11-03',
      });
      f.tabla('ali_compras').add({
        'id': 'fuera',
        'cuenta': 'papa',
        'ingrediente_id': ing,
        'cantidad': 9,
        'comprado': false,
        'para_el': '2026-12-01',
      });
      final papa = await _repo(f).comprasLista(MenuId.papa, lunes);
      expect(papa.single.nombre, 'Leche');
      expect(papa.single.seccion, isNot(SeccionCompra.otros));
      final pareja = await _repo(f).comprasLista(MenuId.pareja, lunes);
      expect(pareja.single.comprada, isTrue);
    });

    test('el menú del día de Papá va por la RPC, sin leer tablas', () async {
      final f = _Fuente();
      f.funciones['ali_menu_del_dia_papa'] = (p) => [
        {'tiempo': 'comida', 'platillo': 'Sopa'},
      ];
      final hoy = await _repo(f).menuDelDiaPapa(DateTime(2026, 11, 4));
      expect(hoy.single.platillo, 'Sopa');
      expect(hoy.single.tiempo, TiempoComida.comida);
      expect(f.llamadas.single.$1, 'ali_menu_del_dia_papa');
      expect(f.llamadas.single.$2['p_fecha'], '2026-11-04');
      expect(f.leidas, isNot(contains('ali_menu')));
      expect(f.leidas, isNot(contains('ali_platillos')));
    });

    test('presupuesto del total de la lista: solo sí o no', () async {
      final f = _Fuente();
      f.funciones['ali_hay_presupuesto'] = (p) => p['p_monto_centavos'] == 12345;
      final r = _repo(f);
      expect(await r.hayPresupuestoPara(12345), isTrue);
      expect(await r.hayPresupuestoPara(99999), isFalse);
    });

    test('guardar el código llama ali_guardar_codigo_barras', () async {
      final f = _Fuente();
      f.funciones['ali_guardar_codigo_barras'] = (p) => p['p_codigo'];
      final r = _repo(f);
      final enServidor = await r.guardarIngredienteConCodigo(
        const Ingrediente(
          'Galletas',
          1,
          'paq',
          SeccionCompra.otros,
          codigoBarras: '7501000000011',
        ),
      );
      expect(enServidor, isTrue);
      final id = f.tabla('ali_ingredientes').single['id'];
      expect(f.llamadas.single.$1, 'ali_guardar_codigo_barras');
      expect(f.llamadas.single.$2, {
        'p_ingrediente': id,
        'p_codigo': '7501000000011',
      });
      expect(f.escrituras, ['ali_ingredientes']);
      // La columna no se escribe directo.
      expect(f.tabla('ali_ingredientes').single.containsKey('codigo_barras'),
          isFalse);
    });

    test('un código de otro producto (23505) sale sin error técnico', () async {
      final f = _Fuente();
      f.funciones['ali_guardar_codigo_barras'] = (p) => throw const ErrorFinanzas(
        'Ya existe: Ese código ya pertenece a otro ingrediente del hogar.',
      );
      await expectLater(
        _repo(f).guardarIngredienteConCodigo(
          const Ingrediente('Galletas', 1, 'paq', SeccionCompra.otros,
              codigoBarras: '7501000000011'),
        ),
        throwsA(
          isA<ErrorAlimentacionServidor>().having(
            (e) => e.mensaje,
            'mensaje',
            'Ese código ya es de otro producto',
          ),
        ),
      );
    });

    test('el lector busca en codigo_barras de ali_ingredientes', () async {
      final f = _Fuente();
      f.tabla('ali_ingredientes').addAll([
        {'id': _pl1, 'nombre': 'Galletas', 'unidad': 'paq',
          'codigo_barras': '7501000000011'},
        {'id': _o1, 'nombre': 'Sal', 'unidad': 'kg', 'codigo_barras': null},
      ]);
      final c = await _repo(f).ingredientesConCodigo();
      expect(c.single.nombre, 'Galletas');
      expect(c.single.codigoBarras, '7501000000011');
    });

    test('el servicio de Casa usa la RPC; el de compra, la cuenta por rol',
        () async {
      final f = conLista();
      f.funciones['ali_menu_del_dia_papa'] = (p) => [
        {'tiempo': 'cena', 'platillo': 'Avena'},
      ];
      final casa = ServicioAlimentacion(_repo(f), rol: Rol.casa);
      expect((await casa.menuDelDiaPapa(DateTime(2026, 11, 4))).single.platillo,
          'Avena');
      expect(f.leidas, isNot(contains('ali_menu')));

      f.funciones['ali_marcar_comprada'] = (p) => {'estado_pago': 'solicitud'};
      final dueno = ServicioAlimentacion(_repo(f), rol: Rol.dueno);
      expect(dueno.cuentaPorOmisionDe(MenuId.papa), CuentaCompra.papa);
      expect(dueno.cuentaPorOmisionDe(MenuId.pareja), CuentaCompra.dueno);
      final r = await dueno.registrarCompra(
        MenuId.papa,
        lunes,
        'leche|ml',
        cantidadComprada: 1000,
        totalCentavos: 2800,
        nombre: 'Leche',
        unidad: 'ml',
      );
      expect(r.pendienteAlbacea, isTrue);
      expect(f.llamadas.last.$1, 'ali_marcar_comprada');
      final lista = await dueno.listaCompras(MenuId.papa, lunes);
      expect(lista.single.comprado, isFalse); // la fila aún no cambia en el falso
    });
  });

  group('Cuenta elegible, lista por RPC, presentación y albacea (5c)', () {
    const ing = '00000000-0000-4000-8000-0000000000e1';
    const libro = '00000000-0000-4000-8000-0000000000ab';
    const libroPapa = '00000000-0000-4000-8000-0000000000ac';
    const cEfectivo = '00000000-0000-4000-8000-0000000000a5';
    const cBanco = '00000000-0000-4000-8000-0000000000a6';
    const cPapa = '00000000-0000-4000-8000-0000000000a7';
    const fila = '00000000-0000-4000-8000-0000000000f1';
    final lunes = DateTime(2026, 11, 2);
    final compra = CompraPrecio(
      clave: 'leche|ml',
      nombre: 'Leche',
      unidad: 'ml',
      totalCentavos: 2800,
      cantidad: 1000,
      fecha: DateTime(2026, 11, 8),
    );
    final precio = PrecioIngrediente.deCompra(
      clave: 'leche|ml',
      totalCentavos: 2800,
      cantidadComprada: 1000,
    );

    _Fuente base() {
      final f = _Fuente();
      f.tabla('ali_ingredientes').add({
        'id': ing,
        'nombre': 'Leche',
        'unidad': 'ml',
      });
      f.tabla('ali_compras').add({
        'id': fila,
        'cuenta': 'dueno',
        'ingrediente_id': ing,
        'cantidad': 1000,
        'comprado': false,
      });
      f.tabla('fin_libros')
        ..add({'id': libro, 'tipo': 'personal', 'titular_id': _yo})
        ..add({
          'id': libroPapa,
          'tipo': 'representado',
          'activo': true,
          'creado_en': '2026-01-01',
        });
      f.tabla('fin_cuentas')
        ..add({'id': cEfectivo, 'libro_id': libro, 'tipo': 'efectivo', 'nombre': 'Cartera', 'clase': 'activo'})
        ..add({'id': cBanco, 'libro_id': libro, 'tipo': 'banco', 'nombre': 'Débito', 'clase': 'activo'})
        ..add({'id': cPapa, 'libro_id': libroPapa, 'tipo': 'banco', 'nombre': 'Cuenta de Papá', 'clase': 'activo'});
      f.funciones['ali_marcar_comprada'] = (p) => {'estado_pago': 'movimiento'};
      return f;
    }

    Future<void> comprar(_Fuente f, {String? elegida}) =>
        _repo(f).registrarCompraReal(
          menu: MenuId.pareja,
          lunes: lunes,
          compra: compra,
          precio: precio,
          cuenta: CuentaCompra.dueno,
          cuentaPagoId: elegida,
        );

    test('sin elegir usa la omisión; la cuenta elegida la sobrescribe', () async {
      final f = base();
      final ofrecidas = await _repo(f).cuentasDePago(CuentaCompra.dueno);
      expect(ofrecidas.map((c) => c.id), containsAll([cEfectivo, cBanco]));
      expect(ofrecidas.singleWhere((c) => c.porOmision).id, cEfectivo);
      expect(ServicioAlimentacion.cuentaEfectiva(ofrecidas, cBanco)!.id, cBanco);

      await comprar(f);
      expect(f.llamadas.last.$2['p_cuenta_origen'], cEfectivo);
      await comprar(f, elegida: cBanco);
      expect(f.llamadas.last.$2['p_cuenta_origen'], cBanco);
    });

    test('una cuenta ajena a su libro no se manda', () async {
      final f = base();
      await expectLater(
        comprar(f, elegida: cPapa),
        throwsA(isA<ErrorAlimentacionServidor>()),
      );
      expect(f.llamadas.where((l) => l.$1 == 'ali_marcar_comprada'), isEmpty);
    });

    test('Papá no ofrece cuenta; Casa usa el libro de la casa', () async {
      final f = base();
      expect(await _repo(f).cuentasDePago(CuentaCompra.papa), isEmpty);
      f.tabla('ali_ajustes').add({'libro_casa_id': libro});
      expect(
        (await _repo(f).cuentasDePago(CuentaCompra.casa)).map((c) => c.id),
        contains(cEfectivo),
      );
    });

    test('agregar a la lista llama la RPC y no inserta en ali_compras', () async {
      final f = base();
      await _repo(f).agregarALista(nombre: 'Leche', unidad: 'ml', cantidad: 500);
      final l = f.llamadas.single;
      expect(l.$1, 'ali_agregar_a_lista');
      expect(l.$2, {
        'p_hogar_id': _hogar,
        'p_ingrediente': ing,
        'p_cantidad': 500,
        'p_unidad': 'ml',
      });
      expect(f.escrituras, isNot(contains('ali_compras')));
    });

    test('comprar sin fila previa la pide por RPC, no por INSERT', () async {
      final f = base();
      f.tabla('ali_compras').clear();
      f.funciones['ali_agregar_a_lista'] = (p) {
        f.tabla('ali_compras').add({
          'id': fila,
          'cuenta': 'dueno',
          'ingrediente_id': ing,
          'cantidad': 1000,
          'comprado': false,
        });
        return fila;
      };
      await comprar(f);
      expect(f.llamadas.map((l) => l.$1), ['ali_agregar_a_lista', 'ali_marcar_comprada']);
      expect(f.escrituras, isNot(contains('ali_compras')));
    });

    test('editar presentación usa la RPC y no crea otro ingrediente', () async {
      final f = base();
      f.funciones['ali_editar_presentacion'] = (p) => null;
      final r = _repo(f);
      final existente = await r.ingredientePorNombre('  leche ');
      expect(existente!.id, ing);
      final ficha = await r.editarPresentacion(
        ingredienteId: ing,
        unidad: 'l',
        presentacion: 'caja 1 l',
      );
      expect(ficha.unidad, 'l');
      expect(f.llamadas.single.$1, 'ali_editar_presentacion');
      expect(f.llamadas.single.$2, {
        'p_ingrediente': ing,
        'p_unidad': 'l',
        'p_presentacion': 'caja 1 l',
      });
      expect(f.escrituras, isEmpty);
      expect(f.tabla('ali_ingredientes').length, 1);
    });

    test('crear con el mismo nombre abre el existente, no crea otro', () async {
      final f = base();
      final servicio = ServicioAlimentacion(_repo(f), rol: Rol.dueno);
      final r = await servicio.guardarConCodigo(
        codigo: '123',
        nombre: 'LECHE',
        unidad: 'l',
      );
      expect(r.existente!.id, ing);
      expect(f.tabla('ali_ingredientes').length, 1);
      expect(f.escrituras, isEmpty);
    });

    group('Albacea', () {
      void miembro(_Fuente f, String persona, String papel, {String? hasta}) =>
          f.tabla('fin_libro_miembros').add({
            'libro_id': libroPapa,
            'persona_id': persona,
            'papel': papel,
            'hasta': hasta,
          });

      void solicitud(_Fuente f) {
        f.tabla('ali_solicitudes_pago').add({
          'id': 'sol1',
          'compra_id': fila,
          'estado': 'pendiente',
          'monto_centavos': 2800,
        });
      }

      test('solo el albacea vigente: la suplente y el resto no', () async {
        final f = base();
        solicitud(f);
        miembro(f, _yo, 'albacea');
        miembro(f, _otra, 'albacea_suplente');
        expect(await _repo(f).esAlbacea(), isTrue);
        expect(await _repo(f, yo: _otra).esAlbacea(), isFalse);
        expect(await _repo(f, yo: _v1).esAlbacea(), isFalse);
        expect(await _repo(f, yo: _otra).solicitudesPendientes(), isEmpty);
        final s = ServicioAlimentacion(_repo(f, yo: _otra), rol: Rol.coadministrador);
        await expectLater(s.solicitudesPendientes(), throwsA(isA<PermisoDenegado>()));
        await expectLater(
          s.aprobarSolicitud('sol1', cuentaPagoId: cPapa),
          throwsA(isA<PermisoDenegado>()),
        );
        expect(f.llamadas.where((l) => l.$1 == 'ali_resolver_solicitud_pago'), isEmpty);
      });

      test('un cargo vencido no es albacea', () async {
        final f = base();
        miembro(f, _yo, 'albacea', hasta: '2020-01-01T00:00:00Z');
        expect(await _repo(f).esAlbacea(), isFalse);
      });

      test('aprueba con cuenta del libro de Papá y rechaza con motivo', () async {
        final f = base();
        solicitud(f);
        miembro(f, _yo, 'albacea');
        f.funciones['ali_resolver_solicitud_pago'] = (p) => null;
        final s = ServicioAlimentacion(_repo(f), rol: Rol.dueno);
        expect(await s.puedeResolverSolicitudes(), isTrue);
        final lista = await s.solicitudesPendientes();
        expect(lista.single.montoCentavos, 2800);
        final cuentas = await s.cuentasDelLibroDePapa();
        expect(cuentas.map((c) => c.id), [cPapa]);

        await s.aprobarSolicitud('sol1', cuentaPagoId: cPapa);
        expect(f.llamadas.last.$2['p_solicitud'], 'sol1');
        expect(f.llamadas.last.$2['p_aprobar'], isTrue);
        expect(f.llamadas.last.$2['p_cuenta_origen'], cPapa);

        await expectLater(
          s.rechazarSolicitud('sol1', motivo: 'no'),
          throwsArgumentError,
        );
        await s.rechazarSolicitud('sol1', motivo: ' Ya hay ');
        expect(f.llamadas.last.$2['p_aprobar'], isFalse);
        expect(f.llamadas.last.$2['p_motivo'], 'Ya hay');
        expect(f.llamadas.last.$2['p_cuenta_origen'], isNull);
      });

      test('la cuenta maestra no resuelve aunque sea albacea', () async {
        final f = base();
        miembro(f, _yo, 'albacea');
        final s = ServicioAlimentacion(_repo(f), rol: Rol.coadministrador, esMaestra: true);
        expect(await s.puedeResolverSolicitudes(), isFalse);
      });
    });
  });
}
