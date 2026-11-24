// Lo que el arranque conecta de «Mi gimnasio» (Fase 8, G3):
//
// - «Borrar mis datos» (entrenamiento o todo) también borra la copia local y lo
//   pendiente en la cola.
// - Salir, una baja o quitar a la persona de la tablet borran la copia local
//   (M5), pero lo que aún no subió SIGUE en la cola.
// - Las molestias (salud_local) no se tocan al salir: viven solo en el equipo,
//   como lo demás que no está en la nube.
// - «Mantener la pantalla encendida» (H-14, aprobado el 24/nov/2026): el
//   arranque pone el canal nativo en Android; sin la parte nativa no falla.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/arranque.dart';
import 'package:gravity/app/gimnasio/proveedores_gimnasio.dart';
import 'package:gravity/app/sensibles/sensibles.dart'
    show alBorrarEntrenamientoProvider, borradoDeMisDatosProvider;
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/proveedores_cola.dart';
import 'package:gravity/nucleo/configuracion/configuracion_entorno.dart';
import 'package:gravity/nucleo/gimnasio/pantalla_encendida.dart';
import 'package:gravity/nucleo/gimnasio/repositorio_gimnasio.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sensibles/mis_datos.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../nucleo/gimnasio/ayuda_gimnasio.dart' as ej;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> arrancar() async {
    final overrides = await prepararArranque(
      configuracion: const ConfiguracionEntorno(dispositivoForzado: 'telefono'),
      abrirBase: BaseLocal.enMemoria,
    );
    final c = ProviderContainer(overrides: overrides);
    addTearDown(() async {
      await c.read(baseLocalProvider).close();
      c.dispose();
    });
    return c;
  }

  Future<void> llenar(RepositorioGimnasio repo, String p) async {
    await repo.guardarPerfil(p, {});
    final ses = (await repo.guardarSesion(p, ej.sesion(p: p))).id;
    await repo.guardarSerie(p, ej.serie(p: p, sesionId: ses));
  }

  test(
    'quitar a la persona borra su copia local y deja lo pendiente en la cola',
    () async {
      final c = await arrancar();
      final repo = c.read(repositorioGimnasioProvider);
      await llenar(repo, ej.persona);
      await llenar(repo, 'uid-bruno');
      final cola = c.read(colaSinConexionProvider);
      final antes = (await cola.registros())
          .where((r) => r.personaId == ej.persona)
          .length;
      expect(antes, 3);

      await c.read(limpiezaLocalProvider).alQuitarPersona(ej.persona);

      expect(await repo.perfil(ej.persona), isNull);
      expect(await repo.sesiones(ej.persona), isEmpty);
      expect(await repo.todasLasSeries(ej.persona), isEmpty);
      // Lo que no subió sigue esperando su sesión; lo de otra persona, intacto.
      expect(
        (await cola.registros()).where((r) => r.personaId == ej.persona),
        hasLength(3),
      );
      expect(await repo.sesiones('uid-bruno'), hasLength(1));
    },
  );

  test('«Borrar mis datos»: entrenamiento y todo borran lo local y lo pendiente; sensibles y diario no', () async {
    final c = await arrancar();
    final repo = c.read(repositorioGimnasioProvider);
    final borrado = c.read(borradoDeMisDatosProvider);
    expect(c.read(alBorrarEntrenamientoProvider), isNotNull);

    for (final (alcance, borra) in [
      (AlcanceDeBorrado.sensibles, false),
      (AlcanceDeBorrado.diario, false),
      (AlcanceDeBorrado.entrenamiento, true),
      (AlcanceDeBorrado.todo, true),
    ]) {
      await llenar(repo, ej.persona);
      await borrado.borrar(ej.persona, alcance);
      expect(
        await repo.perfil(ej.persona),
        borra ? isNull : isNotNull,
        reason: alcance.valor,
      );
      expect(
        (await c.read(colaSinConexionProvider).registros()).where(
          (r) => r.tipo.startsWith('habitos.gim_') && r.personaId == ej.persona,
        ),
        borra ? isEmpty : isNotEmpty,
        reason: alcance.valor,
      );
      await repo.borrarTodoDe(ej.persona);
    }
  });

  test('el borrado en la nube sí queda encolado (hab_borrar_mis_datos entrenamiento)', () async {
    final c = await arrancar();
    await c
        .read(borradoDeMisDatosProvider)
        .borrar(ej.persona, AlcanceDeBorrado.entrenamiento);
    final borrados = (await c.read(colaSinConexionProvider).registros()).where(
      (r) => r.tipo == tipoColaBorrado,
    );
    expect(borrados, hasLength(1));
    expect(borrados.single.carga, contains('entrenamiento'));
  });

  test(
    'mantener la pantalla encendida (H-14): canal nativo solo en Android',
    () async {
      // En las pruebas la plataforma es Android: el arranque pone el canal.
      final c = await arrancar();
      final pantalla = c.read(pantallaEncendidaProvider);
      expect(pantalla, isA<PantallaEncendidaAndroid>());
      // Sin la parte nativa (aquí no hay MainActivity) no falla ni se rompe:
      // la sesión guarda igual.
      expect(await pantalla.mantener(true), isFalse);
      expect(await pantalla.mantener(false), isTrue);
      expect(pantalla.disponible, isFalse);
    },
  );
}
