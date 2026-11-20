/// Aviso de que algo cambió en un libro de Finanzas, desde otro dispositivo
/// (F8-6.6, `docs/specs/fase-8-finanzas-realtime.md`).
///
/// **Sin datos**: el servidor solo dice «el libro X cambió» por el canal
/// privado `finanzas:libro:<id>` (Supabase Realtime Broadcast). Ningún monto,
/// comercio ni fila viaja por ahí (D3, D20): quien lo oye vuelve a pedir lo suyo
/// con su sesión y ahí se aplican los permisos (RLS).
library;

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Lo que puede pasar en los canales de Finanzas.
sealed class EventoSincronia {
  const EventoSincronia();
}

/// Otro dispositivo (o el servidor) cambió datos de este libro.
class CambioDeLibro extends EventoSincronia {
  const CambioDeLibro(this.libroId);

  final String libroId;
}

/// Un canal volvió a conectarse tras una caída: pudo perderse algún mensaje.
class CanalReconectado extends EventoSincronia {
  const CanalReconectado();
}

/// De dónde llegan los avisos. Detrás de una interfaz para probar sin servidor.
abstract interface class FuenteCambiosFinanzas {
  /// Escucha los libros indicados hasta que se cancele la suscripción.
  Stream<EventoSincronia> escuchar(Set<String> libroIds);
}

/// Tema del canal de un libro (debe coincidir con la migración
/// `20261148000000_finanzas_realtime.sql`).
String temaDeLibroFinanzas(String libroId) => 'finanzas:libro:$libroId';

/// Con Supabase Realtime. No se puede probar sin servidor: las pruebas usan una
/// fuente falsa.
class FuenteCambiosFinanzasSupabase implements FuenteCambiosFinanzas {
  FuenteCambiosFinanzasSupabase(this._cliente);

  /// El cliente con la sesión de quien está dentro.
  final SupabaseClient Function() _cliente;

  @override
  Stream<EventoSincronia> escuchar(Set<String> libroIds) {
    final canales = <RealtimeChannel>[];
    SupabaseClient? cliente;
    late final StreamController<EventoSincronia> control;
    control = StreamController<EventoSincronia>(
      onListen: () {
        cliente = _cliente();
        for (final id in libroIds) {
          var cayo = false;
          final canal = cliente!.channel(
            temaDeLibroFinanzas(id),
            opts: const RealtimeChannelConfig(private: true),
          );
          canal
              .onBroadcast(
                event: 'cambio',
                callback: (_) {
                  if (!control.isClosed) control.add(CambioDeLibro(id));
                },
              )
              .subscribe((estado, _) {
                if (estado == RealtimeSubscribeStatus.subscribed) {
                  if (cayo && !control.isClosed) {
                    control.add(const CanalReconectado());
                  }
                  cayo = false;
                } else {
                  cayo = true;
                }
              });
          canales.add(canal);
        }
      },
      onCancel: () async {
        final c = cliente;
        if (c == null) return;
        for (final canal in canales) {
          try {
            await c.removeChannel(canal);
          } catch (_) {
            // Ya estaba cerrado.
          }
        }
      },
    );
    return control.stream;
  }
}
