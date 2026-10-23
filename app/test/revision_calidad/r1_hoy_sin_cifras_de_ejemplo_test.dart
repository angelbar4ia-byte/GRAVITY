// R1 (revisión de calidad, Fase 1): con una sesión REAL, "Hoy" del teléfono y
// la pantalla principal de la laptop siguen mostrando los datos de ejemplo de
// los bocetos (`ResumenGravity.ejemplo`): "Quedan $1,330", "Presupuesto usado
// 62 %", "Vence la tarjeta de crédito", la agenda de hábitos y un medicamento
// de las 20:00. Nadie sobrescribe `datosResumenGravityProvider`, aunque desde
// la Fase 1 ya existen los datos reales de la semana de Finanzas. Son cifras
// inventadas en la primera pantalla del dueño ("no se inventan datos").
//
// El modo demostración (sin Supabase) sí puede mostrar el ejemplo: la prueba
// solo exige que una sesión real no lo muestre. Se resuelve conectando el
// resumen a los datos locales (Finanzas, la semana activa) o dejándolo vacío
// hasta que cada módulo entregue los suyos.
//
// FALLA HOY A PROPÓSITO (etiqueta `hallazgo`).
@Tags(['hallazgo'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/pantalla/resumen_gravity.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';

void main() {
  test('con una sesión real, el resumen no trae cifras de ejemplo', () {
    final servicio = ServicioSesionFalso.con(Rol.dueno);
    expect(servicio.esDemostracion, isFalse, reason: 'preparación');
    final contenedor = ProviderContainer(
      overrides: [servicioSesionProvider.overrideWithValue(servicio)],
    );
    addTearDown(contenedor.dispose);

    final datos = contenedor.read(datosResumenGravityProvider);

    expect(
      identical(datos, ResumenGravity.ejemplo),
      isFalse,
      reason:
          'datosResumenGravityProvider devuelve ResumenGravity.ejemplo '
          '(presupuesto 3,500, gastado 2,170, "vence la tarjeta de crédito") '
          'también con sesión real',
    );
    expect(
      datos.finanzas?.presupuestoCentavos,
      isNot(ResumenGravity.ejemplo.finanzas!.presupuestoCentavos),
    );
  });
}
