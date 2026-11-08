/// Herramientas de voz de Alimentación (Fase 6b): lo que el puente de Casa
/// pide a las bocinas con las frases fijas aprobadas (D6).
///
/// Solo lectura: ninguna escribe ni marca nada. Su contenido lo entrega
/// Alimentación en local (`ContextoHerramienta.consultaLocal`); la herramienta
/// no inventa pasos ni datos. El filtro de la bocina decide después si el
/// texto se puede decir en voz alta.
library;

import '../contratos/roles.dart';
import 'herramienta.dart';

/// Roles que usan la bocina: Casa, dueño, coadministrador y familiar. La
/// cuidadora queda fuera (D5, D18). Debe coincidir con `rolesDeBocina` del
/// puente (una prueba lo verifica).
const Set<Rol> rolesDeVozAlimentacion = {
  Rol.casa,
  Rol.dueno,
  Rol.coadministrador,
  Rol.familiar,
};

/// Una consulta de Alimentación pensada para la bocina.
final class HerramientaVozAlimentacion extends Herramienta {
  const HerramientaVozAlimentacion({
    required this.nombre,
    required this.descripcion,
  });

  @override
  final String nombre;

  @override
  final String descripcion;

  @override
  Modulo get modulo => Modulo.alimentacion;

  @override
  Modulo get moduloDePermiso => Modulo.casa;

  @override
  Set<Rol> get roles => rolesDeVozAlimentacion;

  @override
  bool get escribe => false;

  /// El resultado se dice en la bocina de la casa, no se manda a la IA.
  @override
  bool get soloLocal => true;

  @override
  Future<ResultadoHerramienta> ejecutar(
    Map<String, Object?> parametros,
    ContextoHerramienta ctx,
  ) async {
    final texto = await ctx.consultaLocal?.call(nombre);
    return ResultadoHerramienta(
      this,
      contenido: texto ?? 'Alimentación no tiene datos para decir ahora.',
    );
  }
}

const herramientaRecetaSiguientePaso = HerramientaVozAlimentacion(
  nombre: 'alimentacion.receta_siguiente_paso',
  descripcion: 'Dice el siguiente paso de la receta que se está cocinando.',
);

const herramientaRecetaPasoAnterior = HerramientaVozAlimentacion(
  nombre: 'alimentacion.receta_paso_anterior',
  descripcion: 'Dice el paso anterior de la receta que se está cocinando.',
);

const herramientaRecetaRepetirPaso = HerramientaVozAlimentacion(
  nombre: 'alimentacion.receta_repetir_paso',
  descripcion: 'Repite el paso actual de la receta que se está cocinando.',
);

const herramientaQueCocinoHoy = HerramientaVozAlimentacion(
  nombre: 'alimentacion.que_cocino_hoy',
  descripcion: 'Dice qué platillos tocan hoy en el menú.',
);

const herramientaLeerListaCompras = HerramientaVozAlimentacion(
  nombre: 'alimentacion.leer_lista_compras',
  descripcion: 'Dice qué falta por comprar, sin cantidades ni precios.',
);

/// Las cinco herramientas que usa el puente de Casa.
const List<HerramientaVozAlimentacion> herramientasVozAlimentacion = [
  herramientaRecetaSiguientePaso,
  herramientaRecetaPasoAnterior,
  herramientaRecetaRepetirPaso,
  herramientaQueCocinoHoy,
  herramientaLeerListaCompras,
];
