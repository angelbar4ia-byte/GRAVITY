// CA-G-36: las molestias son SOLO LOCALES. Se guardan únicamente en el almacén
// local cifrado con la llave local; ninguna cola, subida ni consulta a la red
// las contiene (se busca una cadena marcada en todo lo persistido y en todo lo
// enviado); activar la nube de los otros dos tipos sensibles no las sube; la
// laptop y la tablet pública ni las muestran ni las guardan. El respaldo
// automático de Android no incluye nada (allowBackup=false y reglas de
// extracción que excluyen todo).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart'
    show TipoEquipoAvisos;
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/enviador_supabase.dart';
import 'package:gravity/nucleo/gimnasio/molestias_locales.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/mis_datos.dart';
import 'package:gravity/nucleo/sensibles/nube_cifrada.dart';
import 'package:gravity/nucleo/sensibles/nube_habitos.dart';
import 'package:gravity/nucleo/sensibles/sobres.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';
import 'package:habitos_dominio/habitos_dominio.dart'
    show DocumentoSensible, ElementoDoc, Molestia, Zonas;

import 'servidor_gimnasio_simulado.dart';

const persona = 'uid-ana';

/// Cadena que nunca debe aparecer en claro en ningún lado.
const marcador = 'MARCADOR-ROTURA-XQZ-7731';

Molestia molestia({
  String id = 'm1',
  String zona = 'hombro',
  int intensidad = 1,
  String? nota = marcador,
  DateTime? hasta,
}) => Molestia(
  id: id,
  zona: zona,
  intensidad: intensidad,
  desde: DateTime.utc(2026, 11, 20),
  hasta: hasta,
  nota: nota,
);

class _Enviador implements Enviador {
  final List<PeticionEnvio> vistas = [];

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    vistas.add(peticion);
    return ResultadoEnvio.enviado;
  }
}

class _Equipo {
  _Equipo({
    this.equipo = TipoEquipoAvisos.telefono,
    bool llavesPermitidas = true,
  }) {
    almacen = AlmacenSeguroEnMemoria();
    llaves = LlavesHabitos(almacen, permitido: () => llavesPermitidas);
    sobres = AlmacenDeSobres(almacen);
    modos = ModosLocales(almacen);
    molestias = MolestiasLocales(
      llaves: llaves,
      sobres: sobres,
      modos: modos,
      persona: persona,
      equipoLasAdmite: () => equipoAdmiteMolestias(equipo),
    );
  }

  final TipoEquipoAvisos equipo;
  late final AlmacenSeguroEnMemoria almacen;
  late final LlavesHabitos llaves;
  late final AlmacenDeSobres sobres;
  late final ModosLocales modos;
  late final MolestiasLocales molestias;

  /// TODO lo que hay persistido en el almacén seguro (claves y valores).
  String get todoLoPersistido =>
      jsonEncode(almacen.datos) + almacen.datos.keys.join(' ');
}

void main() {
  late _Equipo telefono;

  setUp(() => telefono = _Equipo());

  group('guardar y leer, solo en el equipo', () {
    test('se guardan, se leen y se pueden cerrar o quitar', () async {
      expect((await telefono.molestias.leer()).molestias, isEmpty);
      await telefono.molestias.guardar(molestia());
      await telefono.molestias.guardar(
        molestia(id: 'm2', zona: 'rodilla', intensidad: 2, nota: null),
      );
      var l = await telefono.molestias.leer();
      expect(l.enEsteEquipo, isTrue);
      expect(l.bloqueada, isFalse);
      expect(l.molestias.map((m) => m.id), unorderedEquals(['m1', 'm2']));
      expect(l.molestias.firstWhere((m) => m.id == 'm1').nota, marcador);
      expect(l.activas, hasLength(2));

      // «Ya no»: queda cerrada y deja de tenerse en cuenta.
      await telefono.molestias.guardar(
        molestia().yaNo(DateTime.utc(2026, 11, 22)),
      );
      l = await telefono.molestias.leer();
      expect(l.activas.map((m) => m.id), ['m2']);
      expect(l.molestias, hasLength(2));

      await telefono.molestias.quitar('m2');
      expect((await telefono.molestias.leer()).molestias.map((m) => m.id), [
        'm1',
      ]);
      expect(await telefono.molestias.activas(), isEmpty);
    });

    test('van como sobre del tercer tipo salud_local y cifradas con la llave local', () async {
      await telefono.molestias.guardar(molestia());
      final sobres = await telefono.sobres.todos(persona);
      expect(sobres, hasLength(1));
      expect(sobres.single.tipo, TipoSensible.saludLocal);
      expect(sobres.single.tipo.valor, 'salud_local');
      // La llave de ese tipo es la derivada de la LOCAL, aunque se pida la de
      // la nube.
      final local = await telefono.llaves.llaveDeTipo(
        persona,
        TipoSensible.saludLocal,
        ModoSensible.soloTelefono,
      );
      final pidiendoNube = await telefono.llaves.llaveDeTipo(
        persona,
        TipoSensible.saludLocal,
        ModoSensible.nubeCifrada,
      );
      expect(pidiendoNube, local);
      // En un tipo que sí admite nube, pedir la nube sin llave maestra da null.
      expect(
        await telefono.llaves.llaveDeTipo(
          persona,
          TipoSensible.diarioOracion,
          ModoSensible.nubeCifrada,
        ),
        isNull,
      );
    });

    test(
      'nada en claro: ni el texto, ni la zona, ni el id de la molestia',
      () async {
        await telefono.molestias.guardar(
          molestia(id: 'id-secreto-rodilla', zona: 'rodilla'),
        );
        final todo = telefono.todoLoPersistido;
        expect(todo, isNot(contains(marcador)));
        expect(todo, isNot(contains('rodilla')));
        expect(todo, isNot(contains('id-secreto')));
        expect(todo, isNot(contains('molest')));
        // El tipo del sobre sí está (es lo que el servidor jamás debe ver).
        expect(todo, contains('salud_local'));
      },
    );

    test('caso malo: zona fuera del catálogo, intensidad 0 o 4 y nota de más de 200', () async {
      for (final m in [
        molestia(zona: 'cerebro'),
        molestia(intensidad: 0),
        molestia(intensidad: 4),
        molestia(nota: 'x' * 201),
      ]) {
        await expectLater(
          telefono.molestias.guardar(m),
          throwsA(isA<MolestiaInvalida>()),
        );
      }
      expect((await telefono.molestias.leer()).molestias, isEmpty);
      expect(Zonas.todas, contains('hombro'));
    });

    test('R6: ningún error lleva el texto de una molestia', () async {
      for (final e in <Object>[
        const MolestiaInvalida(),
        const MolestiasNoDisponibles(),
      ]) {
        expect('$e', isNot(contains(marcador)));
      }
      try {
        await telefono.molestias.guardar(molestia(zona: 'cerebro'));
      } on MolestiaInvalida catch (e) {
        expect('$e', isNot(contains(marcador)));
        expect('$e', isNot(contains('cerebro')));
      }
    });
  });

  group('no tiene modo ni nube', () {
    test(
      'siempre solo teléfono; no se puede pasar a la nube ni se guarda un modo',
      () async {
        expect(TipoSensible.saludLocal.admiteNube, isFalse);
        expect(TipoSensible.enNube, [
          TipoSensible.habitosSensibles,
          TipoSensible.diarioOracion,
        ]);
        expect(
          await telefono.modos.modo(persona, TipoSensible.saludLocal),
          ModoSensible.soloTelefono,
        );
        await telefono.modos.fijar(
          persona,
          TipoSensible.saludLocal,
          ModoSensible.soloTelefono,
        );
        expect(
          () => telefono.modos.fijar(
            persona,
            TipoSensible.saludLocal,
            ModoSensible.nubeCifrada,
          ),
          throwsArgumentError,
        );
        // Ni siquiera se guarda una clave de modo para él.
        expect(
          telefono.almacen.datos.keys.where((k) => k.contains('salud_local')),
          isEmpty,
        );
        // Un valor "nube" colado a mano en el almacén no lo cambia.
        await telefono.almacen.escribir(
          'hab.modo.$persona.salud_local',
          'nube_cifrada',
        );
        expect(
          await telefono.modos.modo(persona, TipoSensible.saludLocal),
          ModoSensible.soloTelefono,
        );
      },
    );

    test('el servidor de la nube ni lo conoce: pedirle algo de salud_local lanza antes de la red', () async {
      final servidor = AdministracionNubeHabitosEnMemoria();
      expect(servidor.modos.keys, isNot(contains(TipoSensible.saludLocal)));
      await expectLater(
        servidor.cambiarModo(TipoSensible.saludLocal, ModoSensible.nubeCifrada),
        throwsArgumentError,
      );
      await expectLater(
        servidor.sobresDeLaNube(TipoSensible.saludLocal),
        throwsArgumentError,
      );
      final nube = NubeCifradaHabitos(
        llaves: telefono.llaves,
        sobres: telefono.sobres,
        modos: telefono.modos,
        almacen: telefono.almacen,
        servidor: servidor,
      );
      await expectLater(
        nube.activar(
          persona,
          FraseDeRecuperacion.generar(),
          tipos: {TipoSensible.saludLocal},
        ),
        throwsArgumentError,
      );
      await expectLater(
        nube.reiniciar(persona, tipo: TipoSensible.saludLocal),
        throwsArgumentError,
      );
      expect(servidor.llamadas, 0);
    });
  });

  group(
    'caso malo: activar la nube de habitos_sensibles no sube las molestias',
    () {
      test(
        'subida diferida, nube y cola: nada de salud_local, ni cifrado',
        () async {
          await telefono.molestias.guardar(molestia());
          final servidor = AdministracionNubeHabitosEnMemoria();
          final nube = NubeCifradaHabitos(
            llaves: telefono.llaves,
            sobres: telefono.sobres,
            modos: telefono.modos,
            almacen: telefono.almacen,
            servidor: servidor,
          );
          final base = BaseLocal.enMemoria();
          addTearDown(base.close);
          final enviador = _Enviador();
          final cola = ColaSinConexion(base: base, enviador: enviador);
          addTearDown(cola.cerrar);

          // La persona activa la nube para sus DOS tipos (con una frase real).
          final frase = FraseDeRecuperacion.generar();
          await nube.activar(persona, frase);
          expect(
            servidor.modos[TipoSensible.habitosSensibles],
            ModoSensible.nubeCifrada,
          );
          expect(
            servidor.modos[TipoSensible.diarioOracion],
            ModoSensible.nubeCifrada,
          );
          // Y escribe algo en un tipo que sí va a la nube.
          final llaveTipo = (await telefono.llaves.llaveDeTipo(
            persona,
            TipoSensible.diarioOracion,
            ModoSensible.nubeCifrada,
          ))!;
          final llaveIds = (await telefono.llaves.llaveDeIds(
            persona,
            ModoSensible.nubeCifrada,
          ))!;
          await telefono.sobres.guardar(
            persona,
            cifrarDocumento(
              llaveDeTipo: llaveTipo,
              llaveDeIds: llaveIds,
              persona: persona,
              tipo: TipoSensible.diarioOracion,
              claveDoc: 'dia:2026-11-23',
              documento: {
                'clave': 'dia:2026-11-23',
                'doc': DocumentoSensible({
                  'x': const ElementoDoc(
                    id: 'x',
                    clase: 'nota',
                    modificadoEn: 1,
                    datos: {'texto': 'oración'},
                  ),
                }).aJson(),
              },
            ),
          );

          final subida = SubidaDiferidaDeSobres(
            sobres: telefono.sobres,
            modos: telefono.modos,
            cola: cola,
            almacen: telefono.almacen,
          );
          expect(await subida.encolarPendientes(persona, forzar: true), 1);
          await cola.procesar();

          // Lo enviado: solo el diario; nada de salud_local, ni el marcador.
          expect(enviador.vistas, hasLength(1));
          final enviado = jsonEncode(
            enviador.vistas.map((p) => p.carga).toList(),
          );
          expect(enviado, isNot(contains('salud_local')));
          expect(enviado, isNot(contains(marcador)));
          expect(
            SubidaDiferidaDeSobres.sobresDeCarga(enviador.vistas.single.carga)
                .map((s) => s['tipo']),
            ['diario_oracion'],
          );
          // Lo que la cola persistió tampoco.
          final persistido = jsonEncode([
            for (final r in await cola.registros()) r.carga,
          ]);
          expect(persistido, isNot(contains('salud_local')));
          // Lo que el "servidor" guardó.
          final enElServidor = jsonEncode([
            for (final lista in servidor.sobresPorTipo.values)
              for (final s in lista) s.aJson(),
          ]);
          expect(enElServidor, isNot(contains('salud_local')));
          // Y las molestias siguen abriéndose en el equipo, con la llave local.
          expect(
            (await telefono.molestias.leer()).molestias.single.nota,
            marcador,
          );
          // Nunca "por subir".
          expect(
            await telefono.sobres.porSubir(persona, TipoSensible.saludLocal),
            isEmpty,
          );
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );

      test(
        '«Reiniciar la nube» y volver a solo teléfono no tocan las molestias',
        () async {
          await telefono.molestias.guardar(molestia());
          final servidor = AdministracionNubeHabitosEnMemoria();
          final nube = NubeCifradaHabitos(
            llaves: telefono.llaves,
            sobres: telefono.sobres,
            modos: telefono.modos,
            almacen: telefono.almacen,
            servidor: servidor,
          );
          await nube.activar(persona, FraseDeRecuperacion.generar());
          await nube.reiniciar(persona);
          expect((await telefono.molestias.leer()).molestias, hasLength(1));
          expect(
            (await telefono.sobres.todos(
              persona,
              tipo: TipoSensible.saludLocal,
            )),
            hasLength(1),
          );
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );

      test(
        'el enviador rechaza un lote con un sobre salud_local sin tocar la red',
        () async {
          final servidor = await ServidorGimnasioSimulado.iniciar();
          addTearDown(servidor.cerrar);
          final cliente = await servidor.cliente(persona);
          addTearDown(cliente.dispose);
          final base = BaseLocal.enMemoria();
          addTearDown(base.close);
          final cola = ColaSinConexion(
            base: base,
            enviador: EnviadorSupabase(
              cliente,
              tablas: const {},
              funciones: const {tipoColaSobres: funcionSubirSobres},
            ),
          );
          addTearDown(cola.cerrar);
          // Un error de la app que intentara subirlo (cifrado o no).
          await cola.encolar(
            tipo: tipoColaSobres,
            personaId: persona,
            carga: {
              'p_sobres': [
                {
                  'id': 'x',
                  'tipo': 'salud_local',
                  'revision': 1,
                  'cifrado': 'AAAA',
                  'llave_version': 1,
                  'eliminado': false,
                },
              ],
            },
          );
          final r = await cola.procesar();
          expect(r.rechazados, 1);
          expect(servidor.peticiones, isEmpty);
          expect(
            (await cola.requierenAtencion()).single.ultimoError,
            isNot(contains('salud_local')),
          );
        },
      );
    },
  );

  group('solo donde hay una llave local de la persona', () {
    test('la tablet pública no muestra ni guarda molestias', () async {
      final publica = _Equipo(
        equipo: TipoEquipoAvisos.tabletPublica,
        llavesPermitidas: false, // la tablet pública nunca tiene llaves
      );
      final l = await publica.molestias.leer();
      expect(l.enEsteEquipo, isFalse);
      expect(l.molestias, isEmpty);
      await expectLater(
        publica.molestias.guardar(molestia()),
        throwsA(isA<MolestiasNoDisponibles>()),
      );
      await expectLater(
        publica.molestias.quitar('m1'),
        throwsA(isA<MolestiasNoDisponibles>()),
      );
      expect(publica.almacen.datos, isEmpty);
      expect(await publica.molestias.activas(), isEmpty);
    });

    test('la laptop («no están aquí») tampoco', () async {
      final laptop = _Equipo(equipo: TipoEquipoAvisos.laptop);
      expect((await laptop.molestias.leer()).enEsteEquipo, isFalse);
      await expectLater(
        laptop.molestias.guardar(molestia()),
        throwsA(isA<MolestiasNoDisponibles>()),
      );
      expect(laptop.almacen.datos, isEmpty);
    });

    test('la tablet personal y el teléfono sí', () {
      expect(equipoAdmiteMolestias(TipoEquipoAvisos.telefono), isTrue);
      expect(equipoAdmiteMolestias(TipoEquipoAvisos.tabletPersonal), isTrue);
      expect(equipoAdmiteMolestias(TipoEquipoAvisos.tabletPublica), isFalse);
      expect(equipoAdmiteMolestias(TipoEquipoAvisos.laptop), isFalse);
    });

    test('tablet personal con la llave cerrada (sin PIN): bloqueada, no vacía en falso', () async {
      final almacen = AlmacenSeguroEnMemoria();
      // Con llaves protegidas por PIN y sin liberar: LlaveBloqueada.
      final llaves = LlavesHabitos(almacen, protegidaConPin: true);
      final molestias = MolestiasLocales(
        llaves: llaves,
        sobres: AlmacenDeSobres(almacen),
        modos: ModosLocales(almacen),
        persona: persona,
        equipoLasAdmite: () => true,
      );
      final l = await molestias.leer();
      expect(l.bloqueada, isTrue);
      expect(l.molestias, isEmpty);
    });
  });

  group('Mis datos: borrar', () {
    test(
      'el alcance entrenamiento borra las molestias de este equipo',
      () async {
        await telefono.molestias.guardar(molestia());
        var avisado = false;
        final borrado = BorradoDeMisDatos(
          sobres: telefono.sobres,
          llaves: telefono.llaves,
          modos: telefono.modos,
          almacen: telefono.almacen,
          alBorrarEntrenamiento: (p) async => avisado = p == persona,
        );
        expect(AlcanceDeBorrado.entrenamiento.tipos, {TipoSensible.saludLocal});
        expect(AlcanceDeBorrado.entrenamiento.incluyeEntrenamiento, isTrue);
        expect(AlcanceDeBorrado.todo.incluyeEntrenamiento, isTrue);
        expect(AlcanceDeBorrado.sensibles.incluyeEntrenamiento, isFalse);
        expect(AlcanceDeBorrado.diario.incluyeEntrenamiento, isFalse);
        expect(AlcanceDeBorrado.todo.tipos, contains(TipoSensible.saludLocal));
        await borrado.borrar(persona, AlcanceDeBorrado.entrenamiento);
        expect((await telefono.molestias.leer()).molestias, isEmpty);
        expect(await telefono.sobres.todos(persona), isEmpty);
        expect(avisado, isTrue);
      },
    );

    test('los alcances de Hábitos que no son de entrenamiento no tocan las molestias', () async {
      await telefono.molestias.guardar(molestia());
      final borrado = BorradoDeMisDatos(
        sobres: telefono.sobres,
        llaves: telefono.llaves,
        modos: telefono.modos,
        almacen: telefono.almacen,
      );
      await borrado.borrar(persona, AlcanceDeBorrado.sensibles);
      await borrado.borrar(persona, AlcanceDeBorrado.diario);
      expect((await telefono.molestias.leer()).molestias, hasLength(1));
    });

    test('«Todo» las borra también (y la llave)', () async {
      await telefono.molestias.guardar(molestia());
      final borrado = BorradoDeMisDatos(
        sobres: telefono.sobres,
        llaves: telefono.llaves,
        modos: telefono.modos,
        almacen: telefono.almacen,
      );
      await borrado.borrar(persona, AlcanceDeBorrado.todo);
      expect(await telefono.sobres.todos(persona), isEmpty);
    });

    test('el valor del alcance es el que entiende hab_borrar_mis_datos', () {
      expect(AlcanceDeBorrado.entrenamiento.valor, 'entrenamiento');
    });
  });

  group('el respaldo automático de Android no incluye nada', () {
    String leer(String ruta) {
      final f = [
        File('android/$ruta'),
        File('../app/android/$ruta'),
      ].firstWhere((f) => f.existsSync());
      return f.readAsStringSync();
    }

    test(
      'allowBackup="false" y las reglas excluyen todo (nube y entre equipos)',
      () {
        final manifiesto = leer('app/src/main/AndroidManifest.xml');
        expect(manifiesto, contains('android:allowBackup="false"'));
        expect(manifiesto, contains('android:dataExtractionRules='));
        final reglas = leer('app/src/main/res/xml/reglas_extraccion_datos.xml');
        for (final seccion in ['cloud-backup', 'device-transfer']) {
          final bloque = RegExp(
            '<$seccion>(.*?)</$seccion>',
            dotAll: true,
          ).firstMatch(reglas)!.group(1)!;
          // El almacén seguro vive en las preferencias cifradas y en archivos.
          for (final dominio in [
            'root',
            'file',
            'database',
            'sharedpref',
            'external',
          ]) {
            expect(
              bloque,
              contains('<exclude domain="$dominio" path="."/>'),
              reason: '$seccion/$dominio',
            );
          }
          expect(bloque, isNot(contains('<include')));
        }
      },
    );
  });
}
