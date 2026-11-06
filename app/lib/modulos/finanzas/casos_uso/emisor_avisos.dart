/// Emite desde la app los avisos que solo ella sabe calcular (Fase 4, E16;
/// F4-3.4): `flujo_negativo` y `abono_bajo_minimo`, con `fin_emitir_aviso`.
///
/// - **Sin dinero** (D3, D20): solo el tipo del catálogo (título discreto), el
///   objeto y una clave estable (tipo + objeto + semana). Nada de montos ni
///   texto libre viaja ni se guarda en la cola.
/// - **Idempotente:** repetir el cálculo no crea un segundo aviso; además de
///   que el servidor lo garantiza por `(persona, clave)`, aquí no se vuelve a
///   llamar por una clave ya emitida en la sesión.
/// - **Sin señal no se encola:** el aviso se emite la próxima vez que se
///   calcule con señal (al abrir el libro, al guardar un movimiento o al
///   reintentar), con el cálculo vigente de ese momento.
/// - Solo si la persona puede escribir en el libro; si el servidor responde
///   que llegó a su tope del día, lo registra y no reintenta en bucle.
/// - **Nunca lanza.**
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

import '../datos/repositorio.dart';
import 'servicio_finanzas.dart';

class EmisorAvisosFinanzas {
  EmisorAvisosFinanzas({DateTime Function()? reloj})
    : _reloj = reloj ?? DateTime.now;

  final DateTime Function() _reloj;
  final Set<String> _emitidas = {};
  DateTime? _topeHasta;

  /// Cuánto se espera después de que el servidor diga que se llegó al tope.
  static const pausaPorTope = Duration(hours: 24);

  /// Claves ya emitidas en esta sesión (para las pruebas).
  Set<String> get emitidas => Set.unmodifiable(_emitidas);

  /// Hasta cuándo no se intenta (tope del día alcanzado), si aplica.
  DateTime? get enPausaHasta => _topeHasta;

  /// Emite lo que corresponda al libro [libroId] con lo cargado ahora.
  /// Devuelve cuántos avisos creó el servidor.
  Future<int> emitir(ServicioFinanzas servicio, String libroId) async {
    try {
      if (servicio.soloLectura) return 0;
      final ahora = _reloj();
      final pausa = _topeHasta;
      if (pausa != null) {
        if (ahora.isBefore(pausa)) return 0;
        _topeHasta = null;
      }
      final libro = servicio.datos.libro(libroId);
      if (libro == null || libro.archivado) return 0;
      if (!servicio.permiso(libroId).escribir) return 0;
      final vista = servicio.vista(libroId, Semana.de(servicio.hoy));
      var creados = 0;
      for (final a in avisosPorEmitir(vista)) {
        if (_emitidas.contains(a.clave)) continue;
        try {
          creados += await servicio.repositorio.emitirAviso(
            libroId: libroId,
            tipo: a.tipo.clave,
            objetoTipo: a.objetoTipo,
            objetoId: a.objetoId,
            clave: a.clave,
          );
          _emitidas.add(a.clave);
        } on ErrorFinanzas catch (e) {
          if (e.topeAlcanzado) {
            _topeHasta = ahora.add(pausaPorTope);
            return creados;
          }
          // Sin señal u otro error: no se encola; se vuelve a intentar con
          // el siguiente cálculo.
          if (e.sinConexion) return creados;
        }
      }
      return creados;
    } catch (_) {
      return 0;
    }
  }

  /// Emite lo de todos los libros en los que la persona escribe.
  Future<int> emitirTodos(ServicioFinanzas servicio) async {
    var total = 0;
    for (final libro in servicio.datos.libros) {
      total += await emitir(servicio, libro.id);
    }
    return total;
  }
}
