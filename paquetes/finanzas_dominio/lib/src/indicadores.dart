import 'dinero.dart';

/// Semáforo de los indicadores. En la interfaz siempre va con texto o icono:
/// nunca depende solo del color (5.9 bis, punto 5).
enum Semaforo { verde, ambar, rojo }

/// Umbrales de los semáforos, en puntos base. Son **valores por defecto**
/// editables (5.9 bis, punto 3; pendiente 23 de FINANZAS).
class Umbrales {
  /// Partida: verde hasta 80 % usado, ámbar de 80 % a 100 %, rojo arriba
  /// (5.6 bis, punto 10).
  final int partidaAmbarDesde;
  final int partidaRojoArribaDe;

  /// Remanente ÷ ingreso: verde ≥ 20 %, ámbar de 10 % a 20 %, rojo < 10 %.
  final int remanenteVerdeDesde;
  final int remanenteAmbarDesde;

  /// Carga de deuda: verde < 20 %, ámbar de 20 % a 35 %, rojo > 35 %.
  final int cargaDeudaAmbarDesde;
  final int cargaDeudaRojoArribaDe;

  /// Cumplimiento del presupuesto: verde ≥ 90 %, ámbar de 70 % a 90 %,
  /// rojo < 70 %.
  final int cumplimientoVerdeDesde;
  final int cumplimientoAmbarDesde;

  const Umbrales({
    this.partidaAmbarDesde = 8000,
    this.partidaRojoArribaDe = 10000,
    this.remanenteVerdeDesde = 2000,
    this.remanenteAmbarDesde = 1000,
    this.cargaDeudaAmbarDesde = 2000,
    this.cargaDeudaRojoArribaDe = 3500,
    this.cumplimientoVerdeDesde = 9000,
    this.cumplimientoAmbarDesde = 7000,
  });

  static const Umbrales porDefecto = Umbrales();
}

/// Semáforo de una partida: [gastado] contra [disponible] (asignado más
/// arrastre). Los límites se evalúan con la fracción exacta.
///
/// "Verde hasta 80 %": exactamente 80 % es verde; exactamente 100 % es ámbar;
/// más de 100 % es rojo.
Semaforo semaforoPartida(
  int gastado,
  int disponible, {
  Umbrales umbrales = Umbrales.porDefecto,
}) {
  if (disponible <= 0) return gastado > 0 ? Semaforo.rojo : Semaforo.verde;
  if (compararProporcion(gastado, disponible, umbrales.partidaRojoArribaDe) >
      0) {
    return Semaforo.rojo;
  }
  if (compararProporcion(gastado, disponible, umbrales.partidaAmbarDesde) > 0) {
    return Semaforo.ambar;
  }
  return Semaforo.verde;
}

/// Semáforo del remanente (remanente ÷ ingreso de la semana).
Semaforo semaforoRemanente(
  int remanente,
  int ingreso, {
  Umbrales umbrales = Umbrales.porDefecto,
}) {
  if (ingreso <= 0) return Semaforo.rojo;
  if (compararProporcion(remanente, ingreso, umbrales.remanenteVerdeDesde) >=
      0) {
    return Semaforo.verde;
  }
  if (compararProporcion(remanente, ingreso, umbrales.remanenteAmbarDesde) >=
      0) {
    return Semaforo.ambar;
  }
  return Semaforo.rojo;
}

/// Semáforo de la carga de deuda (pagos de deuda semanales ÷ ingreso semanal).
Semaforo semaforoCargaDeuda(
  int pagosDeuda,
  int ingreso, {
  Umbrales umbrales = Umbrales.porDefecto,
}) {
  if (ingreso <= 0) return pagosDeuda > 0 ? Semaforo.rojo : Semaforo.verde;
  if (compararProporcion(pagosDeuda, ingreso, umbrales.cargaDeudaRojoArribaDe) >
      0) {
    return Semaforo.rojo;
  }
  if (compararProporcion(pagosDeuda, ingreso, umbrales.cargaDeudaAmbarDesde) >=
      0) {
    return Semaforo.ambar;
  }
  return Semaforo.verde;
}

/// Semáforo del cumplimiento (partidas dentro de lo asignado ÷ total).
Semaforo semaforoCumplimiento(
  int partidasDentro,
  int totalPartidas, {
  Umbrales umbrales = Umbrales.porDefecto,
}) {
  if (totalPartidas <= 0) return Semaforo.verde;
  if (compararProporcion(
        partidasDentro,
        totalPartidas,
        umbrales.cumplimientoVerdeDesde,
      ) >=
      0) {
    return Semaforo.verde;
  }
  if (compararProporcion(
        partidasDentro,
        totalPartidas,
        umbrales.cumplimientoAmbarDesde,
      ) >=
      0) {
    return Semaforo.ambar;
  }
  return Semaforo.rojo;
}
