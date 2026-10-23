// Guardia de la revisión de calidad de la Fase 1, criterio 24 (T9): "una semana
// sin cerrar 3 días se cierra con pendientes marcados y se puede reabrir".
//
// El dominio prueba CUÁNDO debe cerrarse sola (`debeCerrarseSola`,
// seguimiento_test) y el caso de uso prueba cerrar y reabrir a mano, pero
// nadie probaba `ServicioFinanzas.cerrarSemanasVencidas`, la rutina que sí
// escribe (la dispara `ConDatosFinanzas` al abrir un libro donde se puede
// escribir). Hoy PASA.
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart'
    show hogarDeEjemplo;

import '../modulos/finanzas/ayuda_finanzas.dart';

void main() {
  const libroDueno = IdsDemostracion.libroDueno;
  const libroPapa = IdsDemostracion.libroPapa;
  final dueno = sesionDe(Rol.dueno);
  final semana = Semana.de(hoyDePrueba); // lunes 19 a domingo 25 de octubre

  test('a los 3 días del domingo se cierra sola, con pendientes, una vez', () async {
    final repo = repositorioDe(dueno);
    final foto = await servicioDe(repo, dueno).activarSemana(libroDueno, semana);

    // Antes de los 3 días no cierra nada (martes 27 de octubre).
    final antes = servicioDe(repo, dueno, ahora: DateTime(2026, 10, 27, 9));
    expect(await antes.cerrarSemanasVencidas(libroDueno), 0);
    expect(repo.datos.semanaGuardada(libroDueno, semana)!.estado,
        isNot(EstadoSemana.cerrada));

    // Viernes 30: pasaron los 3 días.
    final despues = servicioDe(repo, dueno, ahora: DateTime(2026, 10, 30, 9));
    expect(await despues.cerrarSemanasVencidas(libroDueno), 1);
    final cerrada = repo.datos.semanaGuardada(libroDueno, semana)!;
    expect(cerrada.estado, EstadoSemana.cerrada);
    final cierre = repo.datos.cierres.singleWhere((c) => c.semanaId == foto.id);
    expect(cierre.conPendientes, isTrue);
    expect(cierre.accionElegida, AccionCierre.cierreAutomatico);
    expect(cierre.cerradoPor, dueno.persona.id);
    expect(cierre.version, 1);

    // Reintentar no cierra dos veces ni duplica el cierre.
    expect(await despues.cerrarSemanasVencidas(libroDueno), 0);
    expect(repo.datos.cierres.where((c) => c.semanaId == foto.id), hasLength(1));

    // Y se puede reabrir; el siguiente cierre es la versión 2.
    await despues.reabrirSemana(libroDueno, semana);
    expect(repo.datos.semanaGuardada(libroDueno, semana)!.reaperturas, 1);
  });

  test('quien no puede escribir en el libro no lo cierra solo', () async {
    final repo = repositorioDe(dueno);
    await servicioDe(repo, dueno).activarSemana(libroDueno, semana);
    final maestra = sesionDe(Rol.dueno, maestra: true);
    final comoMaestra = ServicioFinanzas(
      repositorio: repo,
      personaId: maestra.persona.id,
      hogarId: hogarDeEjemplo,
      esMaestra: true,
      reloj: () => DateTime(2026, 10, 30, 9),
    );
    expect(await comoMaestra.cerrarSemanasVencidas(libroDueno), 0,
        reason: 'la cuenta maestra no escribe en lo ajeno');
    final pareja = sesionDe(Rol.coadministrador);
    final comoPareja = servicioDe(repo, pareja, ahora: DateTime(2026, 10, 30, 9));
    expect(await comoPareja.cerrarSemanasVencidas(libroDueno), 0,
        reason: 'la pareja no escribe en el libro personal del dueño');
    expect(repo.datos.semanaGuardada(libroDueno, semana)!.estado,
        isNot(EstadoSemana.cerrada));
  });

  test('el suplente de papá no cierra semanas mientras haya albacea', () async {
    final repo = repositorioDe(dueno);
    final pareja = sesionDe(Rol.coadministrador);
    final comoPareja = servicioDe(repo, pareja, ahora: DateTime(2026, 10, 30, 9));
    expect(await comoPareja.cerrarSemanasVencidas(libroPapa), 0);
  });
}
