// HALLAZGO I4 (IMPORTANTE) · docs/revisiones/fase-0.md
//
// Prueba de regresión: el hallazgo se resolvió el 20/oct/2026 (docs/revisiones/fase-0.md, sección 11).
// Excluir mientras tanto: flutter test --exclude-tags hallazgo
//
// La cola sin conexión no está ligada a la persona ni a la sesión: main.dart
// la procesa cada 30 s aunque nadie haya entrado. Sin sesión, la petición sale
// con la llave pública (rol anon); el servidor responde 42501 (sin permiso) y
// `clasificarErrorPostgrest` lo marca como RECHAZADO: el registro ya no se
// reintenta y nada lo muestra. Caso real: el Dueño registra un gasto sin
// señal, la sesión se cierra (salió, o venció la renovación) y al volver la
// señal el gasto se pierde. Criterio 3: "lo registrado sin señal se sube".
//
// Aquí un servidor HTTP local responde como PostgREST para el rol anon.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/enviador_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('sin sesión, un gasto pendiente no se pierde (no queda rechazado)', () async {
    // PostgREST con la llave pública y sin sesión: 401 + 42501.
    final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => servidor.close(force: true));
    servidor.listen((peticion) async {
      await peticion.drain<void>();
      peticion.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'code': '42501',
            'details': null,
            'hint': null,
            'message': 'permission denied for table movimientos',
          }),
        );
      await peticion.response.close();
    });

    final url = 'http://127.0.0.1:${servidor.port}';
    final cliente = SupabaseClient(
      url,
      'llave-publica-de-prueba',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(cliente.dispose);
    expect(cliente.auth.currentSession, isNull, reason: 'nadie ha entrado');

    final base = BaseLocal.enMemoria();
    addTearDown(base.close);
    final cola = ColaSinConexion(
      base: base,
      enviador: EnviadorSupabase(
        cliente,
        tablas: const {'finanzas.gasto': 'movimientos'},
      ),
    );
    await cola.encolar(
      tipo: 'finanzas.gasto',
      carga: const {'descripcion': 'Despensa (ejemplo)', 'monto_centavos': 18500},
    );

    await cola.procesar();

    final registro = (await cola.registros()).single;
    expect(
      registro.estado,
      isNot(EstadoPendiente.rechazado),
      reason: 'el gasto quedó rechazado para siempre: ${registro.ultimoError}',
    );
  });
}
