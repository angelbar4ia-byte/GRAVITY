// F8-7.1, grupo 2: "Hablar con GRAVITY" ya no dice "llega en la Fase 6": abre
// la conversación por texto (la voz todavía no existe), con el mismo filtro de
// D3 del servidor y avisos claros cuando falta la clave de la IA.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/pantallas/marco_pantalla.dart';
import 'package:gravity/app/pantallas_externas.dart'
    show abrirConversacionGravity;
import 'package:gravity/app/router.dart' show routerProvider;
import 'package:gravity/app/tablet/pantalla_modo_casa.dart';
import 'package:gravity/modulos/ajustes/voz/pantalla_voz.dart';
import 'package:gravity/modulos/gravity/conversacion/abrir_conversacion.dart'
    show mensajeSinConversacion;
import 'package:gravity/modulos/gravity/conversacion/cliente_asistente.dart';
import 'package:gravity/modulos/gravity/conversacion/conversacion.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ayuda_plataforma.dart';
import 'tablet_tipos_test.dart'
    show contenedorDe, escribirPin, id, montarPublica, nombreDueno, ubicacion;

class _Cliente implements ClienteAsistente {
  _Cliente([this.error]);

  final ErrorAsistente? error;
  final mensajes = <String>[];

  @override
  Future<RespuestaAsistente> preguntar({
    required String mensaje,
    required String sesion,
    List<TurnoConversacion> historial = const [],
  }) async {
    mensajes.add(mensaje);
    final e = error;
    if (e != null) throw e;
    return const RespuestaAsistente(texto: 'Aquí estoy.');
  }

  @override
  Future<Object?> sugerirRecetas(Map<String, Object?> contexto) async =>
      throw UnimplementedError();
}

Finder botonGravity() => find.byTooltip('Hablar con GRAVITY');

Future<void> escribir(WidgetTester tester, String texto) async {
  await tester.enterText(
    find.byKey(const ValueKey('campo-conversacion')),
    texto,
  );
  await tester.tap(find.byKey(const ValueKey('boton-enviar-conversacion')));
  await tester.pumpAndSettle();
}

void main() {
  List<Override> con(ClienteAsistente cliente) => [
    clienteAsistenteProvider.overrideWithValue(cliente),
  ];

  group('teléfono: botón de GRAVITY arriba', () {
    testWidgets('abre la conversación y responde (sin "llega en la Fase")', (
      tester,
    ) async {
      final cliente = _Cliente();
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: con(cliente),
      );
      // Una pantalla con el marco (Finanzas) trae el botón.
      contenedorDe(tester).read(routerProvider).go(Rutas.finanzas);
      await tester.pumpAndSettle();
      await tester.tap(botonGravity());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hoja-conversacion')), findsOneWidget);
      expect(find.textContaining('llega en la Fase'), findsNothing);
      await escribir(tester, 'hola');
      expect(cliente.mensajes, ['hola']);
      expect(find.text('Aquí estoy.'), findsOneWidget);
      // El aviso de privacidad (D3) está a la vista.
      expect(find.byKey(const ValueKey('aviso-conversacion')), findsOneWidget);
    });

    testWidgets('el botón de "Hoy" también abre la conversación', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: con(_Cliente()),
      );
      await tester.tap(find.byKey(const ValueKey('boton-hablar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hoja-conversacion')), findsOneWidget);
      expect(find.textContaining('llega en una fase'), findsNothing);
    });

    testWidgets('sin clave de IA (503 sin_clave): aviso claro, no error', (
      tester,
    ) async {
      final cliente = _Cliente(
        const ErrorAsistente(
          'sin_clave',
          'El asistente aún no está configurado: falta la clave del '
              'proveedor en el servidor.',
        ),
      );
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: con(cliente),
      );
      contenedorDe(tester).read(routerProvider).go(Rutas.finanzas);
      await tester.pumpAndSettle();
      await tester.tap(botonGravity());
      await tester.pumpAndSettle();
      await escribir(tester, 'hola');
      expect(find.textContaining('aún no está configurado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // La conversación sigue usable.
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('campo-conversacion')))
            .enabled,
        isTrue,
      );
    });

    testWidgets('sin servidor (demostración) lo dice y no se cae', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
      );
      contenedorDe(tester).read(routerProvider).go(Rutas.finanzas);
      await tester.pumpAndSettle();
      await tester.tap(botonGravity());
      await tester.pumpAndSettle();
      await escribir(tester, 'hola');
      expect(
        find.text(
          'La conversación necesita conexión con el servidor de GRAVITY.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('quien no conversa (la cuidadora) no ve el botón', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.cuidador),
      );
      expect(botonGravity(), findsNothing);
    });
  });

  group('tablet pública (cuenta Casa)', () {
    testWidgets('"Escribir a GRAVITY" pide nombre y PIN y abre su Hoy', (
      tester,
    ) async {
      await montarPublica(tester);
      expect(find.text('Mantén para hablar'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('escribir-a-gravity')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('elegir-nombre')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('nombre-${id(Rol.dueno)}')));
      await tester.pumpAndSettle();
      await escribirPin(tester, '246813');
      expect(ubicacion(tester), Rutas.inicio);
      expect(find.byType(PantallaModoCasa), findsNothing);
      expect(find.byKey(const ValueKey('panel-conversacion')), findsOneWidget);
      expect(find.text(nombreDueno), findsNothing);
    });

    testWidgets('la cuenta Casa no conversa: lo dice en vez de abrir la hoja', (
      tester,
    ) async {
      await montarPublica(tester);
      final contexto = tester.element(find.byType(PantallaModoCasa));
      unawaited(abrirConversacionGravity(contexto));
      await tester.pumpAndSettle();
      expect(find.text(mensajeSinConversacion), findsOneWidget);
      expect(find.byKey(const ValueKey('hoja-conversacion')), findsNothing);
    });
  });

  group('laptop', () {
    testWidgets('la conversación está en la pantalla principal', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
        extras: con(_Cliente()),
      );
      expect(find.byKey(const ValueKey('panel-conversacion')), findsOneWidget);
      // Sin botón de micrófono en el marco de la laptop.
      expect(find.byType(BotonMicrofono), findsNothing);
    });
  });

  group('Ajustes › Voz', () {
    testWidgets('dice con honestidad que la voz aún no está', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
      );
      contenedorDe(tester).read(routerProvider).go('/ajustes/voz');
      await tester.pumpAndSettle();
      expect(find.byType(PantallaVoz), findsOneWidget);
      expect(
        find.textContaining('La voz todavía no está disponible'),
        findsOneWidget,
      );
      expect(
        find.textContaining('puedes escribirle a GRAVITY'),
        findsOneWidget,
      );
      expect(find.textContaining('llega en la Fase'), findsNothing);
    });
  });

  group('cliente real: errores del servidor', () {
    SupabaseClient clienteCon(int estado, Object cuerpo) => SupabaseClient(
      'http://localhost:54321',
      'llave-publica-de-prueba',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(cuerpo),
          estado,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    test('503 sin_clave llega como el mensaje del servidor', () async {
      final cliente = ClienteAsistenteSupabase(
        () => clienteCon(503, {
          'error': 'sin_clave',
          'mensaje': 'El asistente aún no está configurado: falta la clave.',
        }),
      );
      await expectLater(
        cliente.preguntar(mensaje: 'hola', sesion: 's'),
        throwsA(
          isA<ErrorAsistente>()
              .having((e) => e.codigo, 'codigo', 'sin_clave')
              .having((e) => e.mensaje, 'mensaje', contains('aún no está')),
        ),
      );
    });

    test('403 rol_sin_conversacion (cuenta Casa) también se explica', () async {
      final cliente = ClienteAsistenteSupabase(
        () => clienteCon(403, {
          'error': 'rol_sin_conversacion',
          'mensaje': 'Tu perfil no conversa con GRAVITY.',
        }),
      );
      await expectLater(
        cliente.preguntar(mensaje: 'hola', sesion: 's'),
        throwsA(
          isA<ErrorAsistente>().having(
            (e) => e.codigo,
            'codigo',
            'rol_sin_conversacion',
          ),
        ),
      );
    });
  });
}
