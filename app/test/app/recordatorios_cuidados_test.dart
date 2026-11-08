// Fase 5 (§3, §7 y §8g): los recordatorios de tomas y comidas se programan
// en el equipo de quien está de turno, a partir de las tomas del servidor.
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/cuidados/datos/modelos.dart';
import 'package:gravity/modulos/cuidados/datos/repositorio.dart';
import 'package:gravity/app/avisos/recordatorios_cuidados.dart';
import 'package:gravity/nucleo/avisos/aviso.dart';
import 'package:gravity/nucleo/avisos/notificador.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';

// Miércoles 11 de noviembre de 2026: la cuidadora está de 7:30 a 18:30.
final _ahora = DateTime(2026, 11, 11, 10);

Future<NotificadorEnMemoria> _corre(
  Rol rol, {
  PerfilCuidados perfil = const PerfilCuidados(),
  bool maestra = false,
  bool conSesion = true,
  DateTime? ahora,
}) async {
  final datos = datosDeEjemploCuidados(_ahora);
  final id = switch (rol) {
    Rol.cuidador => personasDemo.cuidadoraId,
    Rol.dueno => personasDemo.duenoId,
    _ => 'persona-x',
  };
  final n = NotificadorEnMemoria();
  await reprogramarRecordatoriosCuidados(
    repositorio: RepositorioCuidadosEnMemoria(
      datos: datos,
      personaId: id,
      rol: rol,
      perfilActual: perfil,
    ),
    notificador: n,
    almacen: AlmacenSeguroEnMemoria(),
    rol: conSesion ? rol : null,
    personaId: conSesion ? id : null,
    esMaestra: maestra,
    ahora: ahora ?? _ahora,
    preferencias: const PreferenciasAvisos(),
  );
  return n;
}

Iterable<DateTime> _cuando(NotificadorEnMemoria n, String titulo) => n
    .programadas
    .values
    .where((p) => p.notificacion.titulo == titulo)
    .map((p) => p.cuando);

const _toma = 'Hora de un recordatorio de cuidado';
const _comida = 'Hora de la comida';

void main() {
  pruebasRevisionFase5();
  test(
    'al entrar la cuidadora de turno se programan sus tomas y comidas',
    () async {
      final n = await _corre(Rol.cuidador);
      // Toma de las 14:00 (a las 20:00 ya no está de turno).
      expect(_cuando(n, _toma), [DateTime(2026, 11, 11, 14)]);
      // Comida a las 14:00 y colación a las 17:00; desayuno ya pasó y la cena
      // (19:00) es del dueño.
      expect(_cuando(n, _comida).toList()..sort(), [
        DateTime(2026, 11, 11, 14),
        DateTime(2026, 11, 11, 17),
      ]);
    },
  );

  test('las tomas ya dadas no se vuelven a recordar', () async {
    final datos = datosDeEjemploCuidados(_ahora);
    final id = datos.tomas.keys.firstWhere(
      (k) => datos.tomas[k]!.programada == DateTime(2026, 11, 11, 14),
    );
    final t = datos.tomas[id]!;
    datos.tomas[id] = Toma(
      id: id,
      medicamentoId: t.medicamentoId,
      programada: t.programada,
      estado: EstadoToma.dado,
      registradaPor: 'x',
      registradaPorNombre: 'x',
      registradaEn: _ahora,
    );
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
    expect(_cuando(n, _toma), isEmpty);
  });

  test('el dueño recibe lo de su franja (tarde y noche)', () async {
    final n = await _corre(Rol.dueno);
    expect(_cuando(n, _toma), [DateTime(2026, 11, 11, 20)]);
    expect(_cuando(n, _comida), [DateTime(2026, 11, 11, 19)]);
  });

  test('fuera de turno no se programa nada', () async {
    // Cuidadora a las 19:00 del miércoles: ya terminó su turno (18:30) y
    // lo que queda hoy (toma de las 20:00, cena) es del dueño.
    final n = await _corre(Rol.cuidador, ahora: DateTime(2026, 11, 11, 18, 45));
    expect(_cuando(n, _toma), isEmpty);
    expect(_cuando(n, _comida), isEmpty);
  });

  test(
    'la hermana sin visita de turno, la pareja, Casa y sin sesión: nada',
    () async {
      for (final n in [
        await _corre(
          Rol.familiar,
          perfil: const PerfilCuidados(esFamiliar: true),
        ),
        await _corre(Rol.coadministrador),
        await _corre(
          Rol.coadministrador,
          perfil: const PerfilCuidados(consentimiento: true),
        ),
        await _corre(Rol.casa),
        await _corre(Rol.dueno, conSesion: false),
        await _corre(Rol.coadministrador, maestra: true),
      ]) {
        expect(_cuando(n, _toma), isEmpty);
        expect(_cuando(n, _comida), isEmpty);
      }
    },
  );

  test('reprogramar al cambiar de persona cancela lo anterior', () async {
    final datos = datosDeEjemploCuidados(_ahora);
    final n = NotificadorEnMemoria();
    final almacen = AlmacenSeguroEnMemoria();
    Future<void> como(Rol rol, String id) => reprogramarRecordatoriosCuidados(
      repositorio: RepositorioCuidadosEnMemoria(
        datos: datos,
        personaId: id,
        rol: rol,
      ),
      notificador: n,
      almacen: almacen,
      rol: rol,
      personaId: id,
      esMaestra: false,
      ahora: _ahora,
      preferencias: const PreferenciasAvisos(),
    );
    await como(Rol.cuidador, personasDemo.cuidadoraId);
    expect(n.programadas, isNotEmpty);
    await como(Rol.coadministrador, 'persona-pareja');
    expect(n.programadas, isEmpty);
  });

  test('las comidas ya registradas hoy no se recuerdan', () async {
    final datos = datosDeEjemploCuidados(_ahora);
    datos.comidas['c1'] = ComidaRegistro(
      id: 'c1',
      fecha: DateTime(2026, 11, 11),
      tiempo: TiempoComidaPapa.comida,
      resultado: ResultadoComida.comio,
      registradaPor: 'x',
      registradaPorNombre: 'x',
      registradaEn: _ahora,
    );
    final fuente = FuenteCuidadosRepositorio(
      RepositorioCuidadosEnMemoria(datos: datos),
    );
    final e = await fuente.proximos(desde: _ahora, dias: 7);
    expect(
      e.where((x) => x.objetoId == 'comida' && x.tipo == 'recordatorio_comida'),
      isEmpty,
    );
  });
}

// Revisión Fase 5: F5-I3 (toma pospuesta) y F5-M7 (tablet pública).
void _pospuestaALaCuidadora(DatosCuidadosMemoria datos) {
  final id = datos.tomas.keys.firstWhere(
    (k) => datos.tomas[k]!.programada == DateTime(2026, 11, 11, 20),
  );
  final t = datos.tomas[id]!;
  datos.tomas[id] = Toma(
    id: id,
    medicamentoId: t.medicamentoId,
    programada: t.programada,
    estado: EstadoToma.pendiente,
    registradaPor: '',
    registradaPorNombre: '',
    registradaEn: t.programada,
    pospuestaA: personasDemo.cuidadoraId,
    pospuestaTurnoEn: DateTime(2026, 11, 12, 7, 30),
  );
}

Future<NotificadorEnMemoria> _corrIgual(
  DatosCuidadosMemoria datos,
  Rol rol,
  String id, {
  bool tabletPublica = false,
  NotificadorEnMemoria? notificador,
  AlmacenSeguroEnMemoria? almacen,
}) async {
  final n = notificador ?? NotificadorEnMemoria();
  await reprogramarRecordatoriosCuidados(
    repositorio: RepositorioCuidadosEnMemoria(
      datos: datos,
      personaId: id,
      rol: rol,
    ),
    notificador: n,
    almacen: almacen ?? AlmacenSeguroEnMemoria(),
    rol: rol,
    personaId: id,
    esMaestra: false,
    ahora: DateTime(2026, 11, 11, 19),
    preferencias: const PreferenciasAvisos(),
    tabletPublica: tabletPublica,
  );
  return n;
}

void pruebasRevisionFase5() {
  test('F5-I3: la toma pospuesta suena a quien la recibe, a la hora de su turno',
      () async {
    final datos = datosDeEjemploCuidados(_ahora);
    _pospuestaALaCuidadora(datos);
    final cuidadora = await _corrIgual(
      datos,
      Rol.cuidador,
      personasDemo.cuidadoraId,
    );
    expect(_cuando(cuidadora, _toma), contains(DateTime(2026, 11, 12, 7, 30)));
    // Quien la pospuso (el dueño) ya no la recibe: ni a las 20:00 ni después.
    final dueno = await _corrIgual(datos, Rol.dueno, personasDemo.duenoId);
    expect(_cuando(dueno, _toma), isEmpty);
  });

  test('F5-M7: la tablet pública no programa recordatorios de cuidado',
      () async {
    final datos = datosDeEjemploCuidados(_ahora);
    final n = NotificadorEnMemoria();
    final almacen = AlmacenSeguroEnMemoria();
    // Antes, en el teléfono: se programa.
    await _corrIgual(
      datos,
      Rol.dueno,
      personasDemo.duenoId,
      notificador: n,
      almacen: almacen,
    );
    expect(n.programadas, isNotEmpty);
    // La misma persona dentro de la tablet pública: se cancela y no se programa.
    await _corrIgual(
      datos,
      Rol.dueno,
      personasDemo.duenoId,
      tabletPublica: true,
      notificador: n,
      almacen: almacen,
    );
    expect(n.programadas, isEmpty);
  });
}
