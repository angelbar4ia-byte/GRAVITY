// Recordatorios locales de Hábitos (Fase 3, reglas 113 a 119) y rutas por rol.
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/nucleo/avisos/aviso.dart';
import 'package:gravity/nucleo/avisos/catalogo_avisos.dart';
import 'package:gravity/nucleo/avisos/notificador.dart';
import 'package:gravity/nucleo/avisos/recordatorios_habitos.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart';
import 'package:gravity/nucleo/avisos/servicio_avisos.dart';
import 'package:gravity/nucleo/avisos/servicio_recordatorios_habitos.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';

class _Fuente implements FuenteDeRecordatoriosHabitos {
  _Fuente(this.lista);
  final List<RecordatorioHabito> lista;
  @override
  Future<List<RecordatorioHabito>> proximos({
    required DateTime desde,
    required int dias,
  }) async => lista;
}

void main() {
  final ahora = DateTime(2026, 11, 2, 12); // lunes
  RecordatorioHabito r(
    String tipo, {
    int horas = 2,
    bool sensible = false,
    String? nombre,
    String objeto = 'o1',
  }) => RecordatorioHabito(
    tipo: tipo,
    objetoId: objeto,
    cuando: ahora.add(Duration(hours: horas)),
    sensible: sensible,
    nombreEnAviso: nombre,
  );

  group('reglas de texto, canal y botones', () {
    test('todo título del catálogo es discreto', () {
      for (final e in titulosDeHabitos.entries) {
        expect(textoDeAvisoEsDiscreto(e.value), isTrue, reason: e.key);
      }
      expect(titulosDeHabitos.keys.toSet(), TipoRecordatorioHabito.todos);
    });

    test('lo sensible sale como "Recordatorio", sin nombre, por Reservados y '
        'solo con Posponer', () {
      final s = r(
        TipoRecordatorioHabito.cierreDia,
        sensible: true,
        nombre: 'Dejar de fumar',
      );
      expect(tituloDeRecordatorio(s), 'Recordatorio');
      expect(canalDeRecordatorio(s), CanalAviso.habitosReservados);
      expect(accionesDeRecordatorio(s), [AccionDeNotificacion.posponer10]);
      expect(
        claveDeRecordatorio(s),
        startsWith('hab:hab_reservado:o1:2026-11-02:'),
      );
      final n = notificacionDeRecordatorio(s, const PreferenciasAvisos());
      expect(n.titulo, isNot(contains('fumar')));
      expect(n.carga, isNot(contains('fumar')));
    });

    test('lo no sensible: nombre opcional recortado a 40, 3 botones', () {
      final a = r(TipoRecordatorioHabito.bloque, nombre: 'x' * 60);
      expect(tituloDeRecordatorio(a), hasLength(40));
      expect(
        tituloDeRecordatorio(r(TipoRecordatorioHabito.lectura)),
        'Es hora de tu lectura',
      );
      expect(accionesDeRecordatorio(a), hasLength(3));
      expect(canalDeRecordatorio(a), CanalAviso.habitosRecordatorios);
      expect(
        canalDeRecordatorio(r(TipoRecordatorioHabito.revision)),
        CanalAviso.habitosRevision,
      );
    });

    test(
      'el nombre se recorta sin partir emojis ni letras con acento (F3-8)',
      () {
        String titulo(String nombre) => tituloDeRecordatorio(
          RecordatorioHabito(
            tipo: TipoRecordatorioHabito.bloque,
            objetoId: 'o',
            cuando: ahora,
            nombreEnAviso: nombre,
          ),
        );
        for (final emoji in ['😀', '👨\u200d👩\u200d👧', 'e\u0301', '🇲🇽']) {
          final t = titulo('${'a' * 39}$emoji resto');
          expect(t.length, lessThanOrEqualTo(40));
          expect(textoDeAvisoEsDiscreto(t), isTrue, reason: emoji);
          final u = t.codeUnits.last;
          expect(
            u >= 0xD800 && u <= 0xDBFF,
            isFalse,
            reason: 'sustituto suelto: $emoji',
          );
          expect(t.endsWith('\u200d'), isFalse);
          // El grafema entra entero o no entra.
          expect(t == 'a' * 39 || t.endsWith(emoji), isTrue, reason: emoji);
        }
        expect(titulo('Caminar'), 'Caminar');
      },
    );

    test('el id sale del hash de la clave: estable y distinto por objeto', () {
      final a = r(TipoRecordatorioHabito.bloque);
      expect(
        idDeNotificacion(claveDeRecordatorio(a)),
        idDeNotificacion(claveDeRecordatorio(a)),
      );
      expect(
        idDeNotificacion(
          claveDeRecordatorio(r(TipoRecordatorioHabito.bloque, objeto: 'o2')),
        ),
        isNot(idDeNotificacion(claveDeRecordatorio(a))),
      );
    });
  });

  group('qué se programa', () {
    test('solo los próximos 7 días; sin pasado ni tipos silenciados ni desconocidos', () {
      final lista = recordatoriosAProgramar(
        candidatos: [
          r(TipoRecordatorioHabito.bloque, horas: -1),
          r(TipoRecordatorioHabito.bloque, horas: 3),
          r(TipoRecordatorioHabito.lectura, horas: 7 * 24 + 1),
          r(TipoRecordatorioHabito.lectura, horas: 5),
          r('hab_raro', horas: 4),
          r(TipoRecordatorioHabito.momento, horas: 1),
        ],
        preferencias: const PreferenciasAvisos(
          tiposSilenciados: {TipoRecordatorioHabito.momento},
        ),
        ahora: ahora,
      );
      expect(lista.map((x) => x.cuando.difference(ahora).inHours), [3, 5]);
    });

    test('sin tope diario y el modo foco deja solo lo esencial', () {
      final muchos = [
        for (var i = 0; i < 9; i++)
          r(TipoRecordatorioHabito.bloque, horas: i + 1, objeto: 'o$i'),
      ];
      expect(
        recordatoriosAProgramar(
          candidatos: muchos,
          preferencias: const PreferenciasAvisos(),
          ahora: ahora,
        ),
        hasLength(9),
      );
      final foco = recordatoriosAProgramar(
        candidatos: [
          ...muchos,
          r(TipoRecordatorioHabito.cierreDia),
          r(TipoRecordatorioHabito.reservado, sensible: true),
        ],
        preferencias: const PreferenciasAvisos(),
        ahora: ahora,
        modoFoco: true,
      );
      expect(foco.map((x) => x.tipo).toSet(), {
        TipoRecordatorioHabito.cierreDia,
        TipoRecordatorioHabito.reservado,
      });
    });

    test('horas silenciosas: se programa pero sin sonido', () {
      const p = PreferenciasAvisos();
      final noche = RecordatorioHabito(
        tipo: TipoRecordatorioHabito.cierreDia,
        objetoId: 'o',
        cuando: DateTime(2026, 11, 2, 23),
      );
      final dia = RecordatorioHabito(
        tipo: TipoRecordatorioHabito.cierreDia,
        objetoId: 'o',
        cuando: DateTime(2026, 11, 3, 10),
      );
      expect(notificacionDeRecordatorio(noche, p).sonar, isFalse);
      expect(notificacionDeRecordatorio(dia, p).sonar, isTrue);
      expect(
        recordatoriosAProgramar(
          candidatos: [noche],
          preferencias: p,
          ahora: ahora,
        ),
        hasLength(1),
      );
    });
  });

  group('servicio', () {
    late NotificadorEnMemoria nota;
    late AlmacenSeguroEnMemoria almacen;
    var contexto = const ContextoAvisos(
      tipo: TipoEquipoAvisos.telefono,
      personaId: 'ana',
      usaHabitos: true,
    );

    ServicioRecordatoriosHabitos servicio(List<RecordatorioHabito> lista) =>
        ServicioRecordatoriosHabitos(
          notificador: nota,
          fuente: _Fuente(lista),
          almacen: almacen,
          contexto: () => contexto,
          preferencias: () async => const PreferenciasAvisos(),
          ahoraLocal: () => ahora,
        );

    setUp(() {
      nota = NotificadorEnMemoria();
      almacen = AlmacenSeguroEnMemoria();
      contexto = const ContextoAvisos(
        tipo: TipoEquipoAvisos.telefono,
        personaId: 'ana',
        usaHabitos: true,
      );
    });

    test(
      'teléfono y tablet personal programan; laptop, tablet pública, maestra y '
      'quien no usa Hábitos, no',
      () async {
        final lista = [r(TipoRecordatorioHabito.bloque)];
        for (final (c, espera) in <(ContextoAvisos, int)>[
          (
            const ContextoAvisos(
              tipo: TipoEquipoAvisos.telefono,
              personaId: 'a',
              usaHabitos: true,
            ),
            1,
          ),
          (
            const ContextoAvisos(
              tipo: TipoEquipoAvisos.tabletPersonal,
              personaId: 'a',
              usaHabitos: true,
            ),
            1,
          ),
          (
            const ContextoAvisos(
              tipo: TipoEquipoAvisos.laptop,
              personaId: 'a',
              usaHabitos: true,
            ),
            0,
          ),
          (
            const ContextoAvisos(
              tipo: TipoEquipoAvisos.tabletPublica,
              personaId: 'a',
              usaHabitos: true,
            ),
            0,
          ),
          (
            const ContextoAvisos(
              tipo: TipoEquipoAvisos.telefono,
              personaId: 'a',
              usaHabitos: true,
              esMaestra: true,
            ),
            0,
          ),
          (
            const ContextoAvisos(
              tipo: TipoEquipoAvisos.telefono,
              personaId: 'a',
            ),
            0,
          ),
          (const ContextoAvisos(tipo: TipoEquipoAvisos.telefono), 0),
        ]) {
          nota = NotificadorEnMemoria();
          contexto = c;
          await servicio(lista).reprogramar();
          expect(
            nota.programadas,
            hasLength(espera),
            reason: '${c.tipo} ${c.esMaestra} ${c.usaHabitos}',
          );
        }
      },
    );

    test(
      'sin permiso del sistema no programa; apagado, cancela solo lo suyo',
      () async {
        final s = servicio([r(TipoRecordatorioHabito.bloque)]);
        nota.permiso = false;
        await s.reprogramar();
        expect(nota.programadas, isEmpty);
        nota.permiso = true;
        await nota.programar(
          const NotificacionLocal(
            id: 7,
            titulo: 'ajena',
            canal: CanalAviso.resumen,
          ),
          ahora.add(const Duration(hours: 1)),
          zona: 'America/Mexico_City',
        );
        await s.reprogramar();
        expect(nota.programadas, hasLength(2));
        await s.fijarActivado(false);
        expect(nota.programadas.keys, [7]);
        expect(await s.activado(), isFalse);
      },
    );

    test(
      'Hecho y Omitir se guardan en el equipo (solo lo no sensible); Posponer '
      'reprograma 10 min con el mismo texto discreto',
      () async {
        final s = servicio([]);
        final normal = r(TipoRecordatorioHabito.lectura);
        final clave = claveDeRecordatorio(normal);
        await s.alAccion(clave, AccionDeNotificacion.hecho);
        await s.alAccion(clave, AccionDeNotificacion.omitir);
        final guardadas = await s.accionesPendientes();
        expect(guardadas.map((a) => a.accion), [
          AccionDeNotificacion.hecho,
          AccionDeNotificacion.omitir,
        ]);

        final reservado = claveDeRecordatorio(
          r(TipoRecordatorioHabito.cierreDia, sensible: true),
        );
        await s.alAccion(reservado, AccionDeNotificacion.hecho);
        await s.alAccion(reservado, AccionDeNotificacion.omitir);
        expect(
          await s.accionesPendientes(),
          hasLength(2),
          reason: 'lo sensible no escribe nada',
        );

        await s.alAccion(reservado, AccionDeNotificacion.posponer10);
        final p = nota.programadas[idDeNotificacion(reservado)]!;
        expect(p.cuando, ahora.add(const Duration(minutes: 10)));
        expect(p.notificacion.titulo, 'Recordatorio');
        expect(p.notificacion.acciones, [AccionDeNotificacion.posponer10]);

        await s.alAccion(
          'pago_proximo:x',
          AccionDeNotificacion.hecho,
        ); // no es de Hábitos
        expect(await s.accionesPendientes(), hasLength(2));
      },
    );
  });

  group('rutas de Hábitos por rol', () {
    test('espejo: dueño, coadministrador y familiar sí; cuidador y Casa no; '
        'la maestra nunca', () {
      for (final rol in [Rol.dueno, Rol.coadministrador, Rol.familiar]) {
        expect(puedeUsarHabitos(rol, esMaestra: false), isTrue, reason: '$rol');
        expect(
          puedeUsarHabitos(rol, esMaestra: true),
          isFalse,
          reason: '$rol maestra',
        );
      }
      for (final rol in [Rol.cuidador, Rol.casa]) {
        expect(
          puedeUsarHabitos(rol, esMaestra: false),
          isFalse,
          reason: '$rol',
        );
      }
    });

    test('la maestra y los roles sin Hábitos se redirigen al inicio', () {
      String? ir(Rol rol, {bool maestra = false}) => calcularRedireccion(
        ubicacion: Rutas.habitos,
        rol: rol,
        dispositivo: TipoDispositivo.telefono,
        esMaestra: maestra,
      );
      expect(ir(Rol.dueno), isNull);
      expect(ir(Rol.familiar), isNull);
      expect(ir(Rol.dueno, maestra: true), isNotNull);
      expect(ir(Rol.cuidador), isNotNull);
      expect(ir(Rol.casa), isNotNull);
    });

    test('rutas reservadas: solo las del conjunto cerrado', () {
      for (final s in segmentosReservadosDeHabitos) {
        expect(
          esRutaReservadaDeHabitos('${Rutas.habitos}/$s'),
          isTrue,
          reason: s,
        );
        expect(
          esRutaReservadaDeHabitos('${Rutas.habitos}/$s/detalle'),
          isTrue,
          reason: s,
        );
      }
      expect(esRutaReservadaDeHabitos(Rutas.habitos), isFalse);
      expect(esRutaReservadaDeHabitos('${Rutas.habitos}/hoy'), isFalse);
      expect(esRutaReservadaDeHabitos('${Rutas.finanzas}/reservado'), isFalse);
    });

    test(
      'en la tablet pública (alguien entró solo por una acción) lo reservado '
      'regresa a Hábitos',
      () {
        final reservada = calcularRedireccion(
          ubicacion: '${Rutas.habitos}/diario',
          rol: Rol.dueno,
          dispositivo: TipoDispositivo.tablet,
          enAccionDeTabletCasa: true,
        );
        expect(reservada, Rutas.habitos);
        expect(
          calcularRedireccion(
            ubicacion: '${Rutas.habitos}/diario',
            rol: Rol.dueno,
            dispositivo: TipoDispositivo.tablet,
          ),
          isNull,
        );
      },
    );
  });
}
