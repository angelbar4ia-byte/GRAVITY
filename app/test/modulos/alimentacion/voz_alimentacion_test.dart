import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/alimentacion/casos_uso/lectura_voz.dart';
import 'package:gravity/modulos/alimentacion/datos/ejemplo.dart';
import 'package:gravity/modulos/alimentacion/datos/modelos.dart';
import 'package:gravity/modulos/alimentacion/datos/repositorio.dart';
import 'package:gravity/modulos/casa/puente/frases.dart';
import 'package:gravity/modulos/casa/puente/mensaje_bocina.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/herramientas/herramientas.dart';

final _miercoles = DateTime(2026, 11, 4, 12);

LecturaVozAlimentacion _voz(
  RepositorioAlimentacion repo, [
  CocinaPasoAPaso? c,
]) => LecturaVozAlimentacion(repo, c ?? CocinaPasoAPaso(), ahora: () => _miercoles);

Future<RepositorioAlimentacionEnMemoria> _conAvena() async {
  final r = RepositorioAlimentacionEnMemoria(conEjemplo: false);
  await r.asignar(MenuId.pareja, lunesDe(_miercoles), 2, TiempoComida.desayuno, 'p-avena');
  return r;
}

void main() {
  final registro = registroDeGravity();
  const nombres = [
    'alimentacion.receta_siguiente_paso',
    'alimentacion.receta_paso_anterior',
    'alimentacion.receta_repetir_paso',
    'alimentacion.que_cocino_hoy',
    'alimentacion.leer_lista_compras',
  ];

  group('registro', () {
    test('las cinco existen, de solo lectura y solo locales', () {
      for (final n in nombres) {
        final h = registro.buscar(n, rol: Rol.dueno)!;
        expect(h.escribe, isFalse, reason: n);
        expect(h.soloLocal, isTrue, reason: n);
        expect(h.accion, Accion.leer, reason: n);
      }
    });

    test('roles: Casa, dueño, coadministrador y familiar; cuidadora fuera', () {
      for (final n in nombres) {
        final con = {
          for (final r in Rol.values)
            if (registro.buscar(n, rol: r) != null) r,
        };
        expect(con, rolesDeBocina, reason: n);
        expect(con, isNot(contains(Rol.cuidador)), reason: n);
      }
      // Las que usa el puente son exactamente las de la tabla de frases.
      expect({for (final f in frasesFijas) f.herramienta}, nombres.toSet());
    });

    test('la cuenta Casa las recibe aunque no abre Alimentación', () {
      expect(registro.buscar('alimentacion.abrir', rol: Rol.casa), isNull);
      expect(
        registro.buscar('alimentacion.que_cocino_hoy', rol: Rol.casa),
        isNotNull,
      );
    });

    test('no mencionan dinero', () {
      for (final n in nombres) {
        final d = registro.buscar(n, rol: Rol.dueno)!.descripcion.toLowerCase();
        expect(d, isNot(matches(RegExp(r'dinero|\$|precio|costo|pesos'))) , reason: n)
            ;
      }
    });

    test('ejecutar sin datos locales no inventa nada ni va a la IA', () async {
      final r = await registro.ejecutar(
        'alimentacion.receta_siguiente_paso',
        const {},
        const ContextoHerramienta(rol: Rol.casa),
      );
      expect(r.paraIa, isNull);
      expect(r.requiereConfirmacion, isFalse);
      expect(r.contenido, contains('no tiene datos'));
    });

    test('la cuidadora no puede ejecutarlas', () {
      expect(
        () => registro.ejecutar(
          'alimentacion.leer_lista_compras',
          const {},
          const ContextoHerramienta(rol: Rol.cuidador),
        ),
        throwsA(isA<HerramientaNoDisponible>()),
      );
    });
  });

  group('recetas', () {
    test('sin menú de hoy responde que no hay receta, sin inventar pasos', () async {
      final v = _voz(RepositorioAlimentacionEnMemoria(conEjemplo: false));
      for (final n in nombres.take(3)) {
        expect(await v.responder(n), sinRecetaVoz, reason: n);
      }
    });

    test('platillo de hoy sin pasos escritos tampoco inventa pasos', () async {
      final r = RepositorioAlimentacionEnMemoria(conEjemplo: false);
      await r.asignar(MenuId.pareja, lunesDe(_miercoles), 2, TiempoComida.comida, 'p-pollo');
      expect(await _voz(r).responder(nombres[0]), sinRecetaVoz);
    });

    test('siguiente, anterior y repetir recorren los pasos', () async {
      final v = _voz(await _conAvena());
      final pasos = platillosEjemplo.firstWhere((p) => p.id == 'p-avena').pasos;
      expect(await v.responder(nombres[2]), contains('Todavía no empiezas'));
      expect(await v.responder(nombres[0]), pasos[0]);
      expect(await v.responder(nombres[0]), pasos[1]);
      expect(await v.responder(nombres[2]), pasos[1]);
      expect(await v.responder(nombres[1]), pasos[0]);
      expect(await v.responder(nombres[1]), contains(pasos[0]));
      await v.responder(nombres[0]);
      await v.responder(nombres[0]);
      expect(await v.responder(nombres[0]), contains('último paso'));
    });

    test('los pasos de ejemplo pasan el filtro de la bocina (sin cifras)', () {
      final f = FiltroBocina();
      for (final p in platillosEjemplo) {
        for (final paso in p.pasos) {
          expect(
            f.validar(TipoMensajeBocina.pasoReceta, paso).aceptado,
            isTrue,
            reason: '${p.id}: $paso',
          );
        }
      }
    });

    test('nunca usa el menú de Papá', () async {
      final r = RepositorioAlimentacionEnMemoria(conEjemplo: false);
      await r.asignar(MenuId.papa, lunesDe(_miercoles), 2, TiempoComida.desayuno, 'p-avena');
      final v = _voz(r);
      expect(await v.responder(nombres[0]), sinRecetaVoz);
      expect(await v.responder(nombres[3]), 'No hay menú para hoy.');
    });
  });

  group('qué cocino hoy y lista de compras', () {
    test('dice el menú de hoy', () async {
      final t = await _voz(await _conAvena()).responder(nombres[3]);
      expect(t, 'Hoy toca: Desayuno, Avena con fruta.');
    });

    test('la lista no muestra precios ni cantidades y pasa el filtro', () async {
      final r = RepositorioAlimentacionEnMemoria(semanaEjemplo: _miercoles);
      final t = (await _voz(r).responder(nombres[4]))!;
      expect(t, startsWith('Falta comprar: '));
      expect(t, isNot(matches(RegExp(r'\d|\$|precio|pesos|costo'))));
      expect(
        FiltroBocina().validar(TipoMensajeBocina.listaCompras, t).aceptado,
        isTrue,
        reason: t,
      );
    });

    test('lo comprado ya no se lee; todo comprado y lista vacía', () async {
      final r = await _conAvena();
      expect(await _voz(r).responder(nombres[4]), contains('Avena'));
      for (final i in platillosEjemplo.firstWhere((p) => p.id == 'p-avena').ingredientes) {
        await r.marcar(MenuId.pareja, lunesDe(_miercoles), claveCompra(i.nombre, i.unidad), true);
      }
      expect(await _voz(r).responder(nombres[4]), 'Ya compraste todo lo de la lista.');
      expect(
        await _voz(RepositorioAlimentacionEnMemoria(conEjemplo: false)).responder(nombres[4]),
        'La lista de compras está vacía.',
      );
    });
  });
}
