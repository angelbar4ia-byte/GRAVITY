// Pendientes de Cuidados cerrados en la app (migración 20261121): posponer
// toma, citas en cui_citas, "atendido por" y resumen del día.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/avisos/accion_posponer_toma.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo, relojProvider;
import 'package:gravity/modulos/cuidados/casos_uso/permisos_cuidados.dart';
import 'package:gravity/modulos/cuidados/casos_uso/servicio_cuidados.dart';
import 'package:gravity/modulos/cuidados/datos/modelos.dart';
import 'package:gravity/modulos/cuidados/datos/repositorio.dart';
import 'package:gravity/modulos/cuidados/datos/repositorio_supabase.dart';
import 'package:gravity/modulos/cuidados/estado/proveedores.dart';
import 'package:gravity/modulos/cuidados/pantallas/resumen_dia.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/nucleo/avisos/notificador.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

final _ahora = DateTime(2026, 11, 4, 10);
const _dueno = 'persona-dueno';
const _cuidadora = 'persona-cuidadora';
const _pareja = 'persona-pareja';
const _hermana = 'persona-hermana';
const _toma = '11111111-2222-3333-4444-555555555555';
const _carga = 'cui:recordatorio_toma:$_toma:2026-11-04:08:00';

RepositorioCuidadosSupabase _supa(FuenteTablasEnMemoria f, String quien) =>
    RepositorioCuidadosSupabase(fuente: f, hogarId: 'h1', personaId: quien);

void main() {
  group('Posponer al siguiente turno', () {
    test('la acción llama a cui_posponer_toma con p_toma', () async {
      final fuente = FuenteTablasEnMemoria();
      final n = NotificadorEnMemoria();
      final ok = await posponerTomaDesdeAviso(
        carga: _carga,
        accion: AccionDeNotificacion.posponerTurno,
        repositorio: _supa(fuente, _cuidadora),
        notificador: n,
      );
      expect(ok, isTrue);
      expect(fuente.llamadas.single.$1, 'cui_posponer_toma');
      expect(fuente.llamadas.single.$2, {'p_toma': _toma});
      expect(n.historial, isEmpty);
    });

    test('otra acción u otra carga no llaman al servidor', () async {
      final fuente = FuenteTablasEnMemoria();
      final n = NotificadorEnMemoria();
      for (final (c, a) in [
        (_carga, AccionDeNotificacion.posponer10),
        ('hab:algo', AccionDeNotificacion.posponerTurno),
        (null, AccionDeNotificacion.posponerTurno),
      ]) {
        expect(
          await posponerTomaDesdeAviso(
            carga: c,
            accion: a,
            repositorio: _supa(fuente, _cuidadora),
            notificador: n,
          ),
          isFalse,
        );
      }
      expect(fuente.llamadas, isEmpty);
    });

    test('sin permiso: aviso sobrio, sin datos clínicos', () async {
      final n = NotificadorEnMemoria();
      final ok = await posponerTomaDesdeAviso(
        carga: _carga,
        accion: AccionDeNotificacion.posponerTurno,
        // La pareja no puede: el repositorio en memoria responde 42501.
        repositorio: RepositorioCuidadosEnMemoria(
          datos: DatosCuidadosMemoria(),
          personaId: _pareja,
          rol: Rol.coadministrador,
        ),
        notificador: n,
      );
      expect(ok, isFalse);
      final aviso = n.historial.single;
      expect(aviso.titulo, textoNoSePudoPosponer);
      expect(aviso.cuerpo, isEmpty);
      expect(aviso.titulo, isNot(contains(_toma)));
    });

    test('sin sesión: el mismo aviso sobrio', () async {
      final n = NotificadorEnMemoria();
      expect(
        await posponerTomaDesdeAviso(
          carga: _carga,
          accion: AccionDeNotificacion.posponerTurno,
          repositorio: null,
          notificador: n,
        ),
        isFalse,
      );
      expect(n.historial, hasLength(1));
    });
  });

  group('Citas en cui_citas', () {
    test('agregar manda solo id, hogar, fecha, lugar y nota', () async {
      final fuente = FuenteTablasEnMemoria();
      await _supa(fuente, _dueno).agregarCita(
        Cita(
          id: 'c1',
          programadaEn: DateTime.utc(2026, 11, 12, 16),
          lugar: 'Clínica',
          nota: 'Revisión',
          autorId: _dueno,
          autorNombre: 'D',
          creadaEn: _ahora,
        ),
      );
      expect(fuente.tabla('cui_bitacora'), isEmpty);
      final fila = fuente.tabla('cui_citas').single;
      expect(fila.keys.toSet(), {
        'id',
        'hogar_id',
        'programada_en',
        'lugar',
        'nota',
      });
      expect(fila.containsKey('persona_id'), isFalse);
      expect(fila.containsKey('creada_en'), isFalse);
    });

    test(
      'leer trae cui_citas ordenadas; las notas viejas siguen como nota',
      () async {
        final fuente = FuenteTablasEnMemoria();
        fuente.tabla('cui_citas')
          ..add({
            'id': 'b',
            'persona_id': _dueno,
            'programada_en': '2026-11-20T16:00:00Z',
            'lugar': null,
            'nota': 'Segunda',
            'creada_en': '2026-11-01T10:00:00Z',
          })
          ..add({
            'id': 'a',
            'persona_id': _dueno,
            'programada_en': '2026-11-12T16:00:00Z',
            'lugar': 'Clínica',
            'nota': null,
            'creada_en': '2026-11-01T10:00:00Z',
          });
        fuente.tabla('cui_bitacora').add({
          'id': 'n1',
          'persona_id': _dueno,
          'nota': '[cita 2026-11-12T10:00] Vieja',
          'creada_en': '2026-10-01T10:00:00Z',
        });
        final r = _supa(fuente, _dueno);
        final citas = await r.citas();
        expect([for (final c in citas) c.id], ['a', 'b']);
        expect(citas.first.lugar, 'Clínica');
        final b = (await r.bitacora()).single;
        expect(b.tipo, TipoBitacora.nota);
        expect(b.texto, '[cita 2026-11-12T10:00] Vieja');
      },
    );

    test('el servicio agrega la cita sin pasar por la bitácora', () async {
      final d = DatosCuidadosMemoria();
      final s = ServicioCuidados(
        RepositorioCuidadosEnMemoria(
          datos: d,
          personaId: _dueno,
          rol: Rol.dueno,
        ),
        permisos: const PermisosCuidados(
          rol: Rol.dueno,
          perfil: PerfilCuidados(),
        ),
        personaId: _dueno,
        nombre: 'D',
        ahora: () => _ahora,
      );
      await s.agregarCita('Revisión', DateTime(2026, 11, 12, 10), lugar: ' X ');
      expect(d.bitacora, isEmpty);
      final c = (await s.citas()).single;
      expect(c.nota, 'Revisión');
      expect(c.lugar, 'X');
    });
  });

  group('Cambio urgente atendido', () {
    test('lee atendido_por; sin nombre visible queda sin nombre', () async {
      final fuente = FuenteTablasEnMemoria();
      fuente.tabla('personas'); // sin filas: no se pueden leer nombres
      fuente.tabla('cui_cambios_urgentes')
        ..add({
          'id': 'u1',
          'de_persona': _dueno,
          'para_persona': _cuidadora,
          'texto': 'x',
          'creado_en': '2026-11-04T10:00:00Z',
          'atendido_en': '2026-11-04T10:05:00Z',
          'atendido_por': _hermana,
        })
        ..add({
          'id': 'u2',
          'de_persona': _dueno,
          'para_persona': _cuidadora,
          'texto': 'y',
          'creado_en': '2026-11-04T09:00:00Z',
          'atendido_en': null,
          'atendido_por': null,
        });
      final r = RepositorioCuidadosSupabase(
        fuente: fuente,
        hogarId: 'h1',
        personaId: _dueno,
        nombre: 'Dueño',
      );
      final l = await r.cambiosUrgentes();
      final u1 = l.firstWhere((c) => c.id == 'u1');
      expect(u1.atendido, isTrue);
      expect(u1.atendidoPor, _hermana);
      expect(u1.atendidoNombre, isEmpty);
      expect(l.firstWhere((c) => c.id == 'u2').atendido, isFalse);
      // Con nombre visible, se muestra.
      fuente.tabla('personas').add({'id': _hermana, 'nombre_visible': 'Ana'});
      final r2 = RepositorioCuidadosSupabase(
        fuente: fuente,
        hogarId: 'h1',
        personaId: _dueno,
      );
      expect(
        (await r2.cambiosUrgentes())
            .firstWhere((c) => c.id == 'u1')
            .atendidoNombre,
        'Ana',
      );
    });
  });

  group('Resumen del día: acceso', () {
    test('permisos: dueño y pareja con consentimiento; nadie más', () {
      bool ve(Rol rol, PerfilCuidados p, {bool maestra = false}) =>
          PermisosCuidados(
            rol: rol,
            perfil: p,
            esMaestra: maestra,
          ).veResumenDelDia;
      expect(ve(Rol.dueno, const PerfilCuidados()), isTrue);
      expect(
        ve(Rol.coadministrador, const PerfilCuidados(consentimiento: true)),
        isTrue,
      );
      expect(ve(Rol.coadministrador, const PerfilCuidados()), isFalse);
      expect(
        ve(
          Rol.coadministrador,
          const PerfilCuidados(consentimiento: true),
          maestra: true,
        ),
        isFalse,
      );
      expect(ve(Rol.cuidador, const PerfilCuidados()), isFalse);
      expect(ve(Rol.cuidador, const PerfilCuidados(esFamiliar: true)), isFalse);
    });

    test(
      'el guardia deja pasar a dueño y pareja, no a la maestra de solo lectura',
      () {
        expect(puedeAbrirResumenDia(Rol.dueno), isTrue);
        expect(puedeAbrirResumenDia(Rol.coadministrador), isTrue);
        expect(
          puedeAbrirResumenDia(Rol.coadministrador, esMaestra: true),
          isFalse,
        );
        expect(puedeAbrirResumenDia(Rol.cuidador), isFalse);
        expect(puedeAbrirResumenDia(Rol.casa), isFalse);
        expect(RutasApp.cuidadosResumenDia, '/cuidados/resumen-dia');
      },
    );

    Widget app(String id, Rol rol, PerfilCuidados perfil) {
      final d = datosDeEjemploCuidados(_ahora);
      return ProviderScope(
        overrides: [
          relojProvider.overrideWithValue(RelojFijo(_ahora)),
          almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
          servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
          sesionEfectivaProvider.overrideWithValue(
            Sesion(
              persona: Persona(id: id, nombre: id),
              rol: rol,
            ),
          ),
          repositorioCuidadosProvider.overrideWithValue(
            RepositorioCuidadosEnMemoria(
              datos: d,
              personaId: id,
              rol: rol,
              perfilActual: perfil,
            ),
          ),
        ],
        child: const MaterialApp(home: PantallaResumenDia()),
      );
    }

    testWidgets('el dueño ve solo conteos', (t) async {
      await t.pumpWidget(app(_dueno, Rol.dueno, const PerfilCuidados()));
      await t.pumpAndSettle();
      expect(find.text('Programados'), findsOneWidget);
      expect(find.text('Rechazo', skipOffstage: false), findsNothing);
      expect(find.text('Con rechazo'), findsOneWidget);
    });

    testWidgets('la pareja con consentimiento los ve', (t) async {
      await t.pumpWidget(
        app(
          _pareja,
          Rol.coadministrador,
          const PerfilCuidados(consentimiento: true),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Programados'), findsOneWidget);
    });

    testWidgets('la pareja sin consentimiento no los ve', (t) async {
      await t.pumpWidget(
        app(_pareja, Rol.coadministrador, const PerfilCuidados()),
      );
      await t.pumpAndSettle();
      expect(find.text('Programados'), findsNothing);
      expect(find.text('Esta sección no está disponible'), findsOneWidget);
    });

    testWidgets('la hermana y la cuidadora no los ven', (t) async {
      await t.pumpWidget(
        app(_hermana, Rol.familiar, const PerfilCuidados(esFamiliar: true)),
      );
      await t.pumpAndSettle();
      expect(find.text('Programados'), findsNothing);
    });
  });
}
