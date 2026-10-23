// Hallazgos MENORES de la revisión de calidad de la Fase 1 y el I11
// (docs/revisiones/fase-1.md). Cada prueba demuestra uno y FALLA HOY A
// PROPÓSITO (etiqueta `hallazgo`); pasarán cuando se arreglen.
//
// M1  El espejo de la interfaz toma `hasta` como inclusivo y el servidor, como
//     exclusivo: el día de `hasta` la app ofrece escribir y el servidor niega.
// M2  "12,5" se lee como $125.00 (la coma se trata siempre como separador de
//     miles): un error de diez veces sin aviso.
// M3  La cola acepta registrar dinero con el origen "tablet de la casa" (solo
//     con el nombre, sin PIN). El servidor lo rechazaría (42501), pero la regla
//     de D14 debe estar también en la cola.
// M4  Dos días fijos del mes que caen el mismo día (30 y último en febrero)
//     pierden un pago en el calendario (el equivalente semanal cuenta 24).
// M8  Con letra al 200 % "Hoy" del teléfono (chips de hábitos) se desborda.
// I11 Sin FLAG_SECURE: la miniatura de "recientes" de Android muestra las
//     pantallas de Finanzas (pendiente M9 de la Fase 0).
@Tags(['hallazgo'])
library;

import 'dart:io';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/datos/filas.dart';
import 'package:gravity/modulos/finanzas/pantallas/comunes.dart'
    show centavosDeTexto;
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';

import 'ayuda_calidad.dart';

class _EnviadorQueNoEnvia implements Enviador {
  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async =>
      ResultadoEnvio.sinSesion;
}

void main() {
  test('M1: el día de "hasta" el espejo y el servidor coinciden', () {
    final hoy = Fecha(2026, 10, 21);
    final miembro = MiembroLibro(
      personaId: 'p1',
      papel: PapelLibro.albacea,
      hasta: hoy,
    );
    final fila = filaMiembro('l1', miembro, hogarId: 'h1', id: 'x');
    // El servidor: vigente si `hasta > now()`. `hasta` viaja como el inicio del
    // día local; a mediodía de ese mismo día ya no es vigente.
    final servidorVigente = DateTime.parse(
      '${fila['hasta']}',
    ).isAfter(DateTime(2026, 10, 21, 12));
    expect(
      miembro.vigenteEn(hoy),
      servidorVigente,
      reason:
          'MiembroLibro.vigenteEn toma hasta como inclusivo (libros.dart); '
          'el servidor lo toma como exclusivo. El día del cambio de albacea la '
          'app y el servidor se contradicen',
    );
  });

  test('M2: una coma que no separa miles no se lee como miles', () {
    expect(centavosDeTexto('1,234.50'), 123450, reason: 'esto sí es válido');
    expect(centavosDeTexto('85'), 8500);
    expect(
      centavosDeTexto('12,5'),
      isNull,
      reason: '"12,5" se leyó como \$125.00 (la coma se borra sin mirar)',
    );
    expect(centavosDeTexto('85,50'), isNull, reason: 'se leyó \$8,550.00');
  });

  test('M3: la cola no acepta dinero con el origen "tablet de la casa"', () async {
    final base = BaseLocal.enMemoria();
    addTearDown(base.close);
    final cola = ColaSinConexion(base: base, enviador: _EnviadorQueNoEnvia());
    addTearDown(cola.cerrar);
    await expectLater(
      cola.encolar(
        tipo: 'finanzas.movimiento',
        carga: {'monto_centavos': 5000},
        personaId: 'persona-que-dijo-ser',
        origen: OrigenRegistro.tabletCasa,
      ),
      throwsA(anything),
      reason:
          'Solo lo de la casa (lista de compras, recordatorios genéricos) '
          'se registra con el nombre y sin PIN (D14); el dinero pide nombre y '
          'PIN y sube con la sesión de la persona',
    );
  });

  test('M4: dos días fijos que coinciden en un mes corto no pierden un pago', () {
    final CalendarioPago calendario;
    try {
      calendario = CalendarioPago.diasFijos([
        const DiaDelMes(30),
        DiaDelMes.ultimo,
      ]);
    } on ArgumentError {
      // Rechazarlo al configurar también resuelve el hallazgo.
      return;
    }
    expect(calendario.vecesAlAnio, 24);
    final febrero = calendario.fechasNominales(
      Fecha(2026, 2, 1),
      Fecha(2026, 2, 28),
    );
    expect(
      febrero,
      hasLength(2),
      reason:
          'En febrero el 30 y el último día son el 28: el calendario deja un '
          'solo pago ($febrero) aunque el equivalente semanal cuenta 24 al año',
    );
  });

  testWidgets('M8: "Hoy" del teléfono con la letra al 200 % no se desborda', (
    tester,
  ) async {
    await montarFinanzasConTamano(
      tester,
      dispositivo: TipoDispositivo.telefono,
      tamano: const Size(360, 800),
      escalaDeLetra: 2.0,
    );
    final errores = await recolectar(() => irA(tester, Rutas.inicio));
    expect(
      errores.desbordes,
      isEmpty,
      reason:
          'El chip de un hábito es un Row rígido (hoy_telefono.dart, '
          '_ChipHabito)',
    );
  });

  test('I11: la ventana de Android no se puede capturar (FLAG_SECURE)', () {
    final actividad = File(
      'android/app/src/main/kotlin/mx/segundocerebro/gravity/MainActivity.kt',
    );
    expect(actividad.existsSync(), isTrue, reason: 'preparación');
    expect(
      actividad.readAsStringSync(),
      contains('FLAG_SECURE'),
      reason:
          'Sin FLAG_SECURE ni cubierta al pasar a segundo plano, la miniatura '
          'de "recientes" (también en la tablet de la casa) muestra Finanzas',
    );
  });
}
