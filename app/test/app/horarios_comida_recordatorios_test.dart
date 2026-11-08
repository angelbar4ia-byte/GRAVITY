// Fase 5 (8h): los recordatorios de comida usan los horarios del hogar y se
// reprograman al cambiarlos.
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/avisos/recordatorios_cuidados.dart';
import 'package:gravity/modulos/cuidados/datos/modelos.dart';
import 'package:gravity/modulos/cuidados/datos/repositorio.dart';
import 'package:gravity/nucleo/avisos/aviso.dart';
import 'package:gravity/nucleo/avisos/notificador.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';

// Miércoles 11 de noviembre de 2026: la cuidadora está de 7:30 a 18:30.
final _ahora = DateTime(2026, 11, 11, 10);

Future<NotificadorEnMemoria> _corre(DatosCuidadosMemoria datos) async {
  final n = NotificadorEnMemoria();
  await reprogramarRecordatoriosCuidados(
    repositorio: RepositorioCuidadosEnMemoria(
      datos: datos,
      personaId: personasDemo.cuidadoraId,
      rol: Rol.cuidador,
    ),
    notificador: n,
    almacen: AlmacenSeguroEnMemoria(),
    rol: Rol.cuidador,
    personaId: personasDemo.cuidadoraId,
    esMaestra: false,
    ahora: _ahora,
    preferencias: const PreferenciasAvisos(),
  );
  return n;
}

List<DateTime> _comidas(NotificadorEnMemoria n) =>
    n.programadas.values
        .where((p) => p.notificacion.titulo == 'Hora de la comida de Papá')
        .map((p) => p.cuando)
        .toList()
      ..sort();

void main() {
  test('sin horarios guardados se usan los de omisión', () async {
    final n = await _corre(datosDeEjemploCuidados(_ahora));
    expect(_comidas(n), [
      DateTime(2026, 11, 11, 14),
      DateTime(2026, 11, 11, 17),
    ]);
  });

  test('al cambiar una hora, la comida se reprograma a esa hora', () async {
    final datos = datosDeEjemploCuidados(_ahora);
    final dueno = RepositorioCuidadosEnMemoria(
      datos: datos,
      personaId: personasDemo.duenoId,
      rol: Rol.dueno,
    );
    await dueno.fijarHorarioComida(
      TiempoComidaPapa.comida,
      const HoraDelDia(13, 15),
    );
    final n = await _corre(datos);
    expect(_comidas(n), [
      DateTime(2026, 11, 11, 13, 15),
      DateTime(2026, 11, 11, 17),
    ]);
  });
}
