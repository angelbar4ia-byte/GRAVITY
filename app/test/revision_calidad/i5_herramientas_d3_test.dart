// HALLAZGO I5 (IMPORTANTE) · docs/revisiones/fase-0.md
//
// Prueba de regresión: el hallazgo se resolvió el 20/oct/2026 (docs/revisiones/fase-0.md, sección 11).
// Excluir mientras tanto: flutter test --exclude-tags hallazgo
//
// RegistroHerramientas es "el único camino" (D1), pero solo revisa el formato
// del nombre: acepta una herramienta de Finanzas que se declara para el rol
// Familiar (fuera de la matriz, D5) y una de Finanzas o Cuidados que lee datos
// sin `soloLocal` (su resultado iría a la IA en la nube, contra D3). Hoy solo
// hay herramientas de navegación; la guardia debe existir antes de la Fase 1.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/herramientas/herramientas.dart';

/// Herramienta de prueba que LEE datos de un módulo (no es de navegación).
final class _Lectora extends Herramienta {
  const _Lectora(this.nombre, this.modulo, this.roles, {this.soloLocal = true});

  @override
  final String nombre;
  @override
  final Modulo modulo;
  @override
  final Set<Rol> roles;
  @override
  final bool soloLocal;

  @override
  String get descripcion => 'Resumen de prueba.';
  @override
  bool get escribe => false;

  @override
  Future<ResultadoHerramienta> ejecutar(
    Map<String, Object?> parametros,
    ContextoHerramienta ctx,
  ) async => ResultadoHerramienta(
    this,
    contenido: 'Quedan \$1,330.00',
    paraIa: 'Quedan \$1,330.00',
  );
}

void main() {
  test('rechaza una herramienta de Finanzas para un rol que no ve dinero', () {
    expect(
      () => RegistroHerramientas([
        const _Lectora('finanzas.resumen_semana', Modulo.finanzas, {
          Rol.dueno,
          Rol.familiar,
        }),
      ]),
      throwsArgumentError,
    );
  });

  test('rechaza una herramienta de Finanzas que lee datos sin soloLocal (D3)', () {
    expect(
      () => RegistroHerramientas([
        const _Lectora(
          'finanzas.resumen_semana',
          Modulo.finanzas,
          {Rol.dueno},
          soloLocal: false,
        ),
      ]),
      throwsArgumentError,
    );
  });

  test('rechaza una herramienta de Cuidados que lee datos sin soloLocal (D3)', () {
    expect(
      () => RegistroHerramientas([
        const _Lectora(
          'cuidados.siguiente_medicamento',
          Modulo.cuidados,
          {Rol.dueno},
          soloLocal: false,
        ),
      ]),
      throwsArgumentError,
    );
  });

  test('las de navegación de la Fase 0 siguen permitidas', () {
    expect(registroFase0().todas, isNotEmpty);
  });
}
