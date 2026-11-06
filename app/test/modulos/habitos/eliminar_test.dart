import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_eliminar.dart';
import 'package:gravity/modulos/habitos/datos/documentos_sensibles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/sobres.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

void main() {
  late AlmacenSeguroEnMemoria almacen;
  late DateTime ahora;
  late ServicioHabitoEliminar s;
  late DocumentosSensibles docs;

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    ahora = DateTime.utc(2026, 11, 2, 10);
    docs = DocumentosSensibles(
      llaves: LlavesHabitos(almacen),
      sobres: AlmacenDeSobres(almacen),
      modos: ModosLocales(almacen),
      persona: 'ana',
      ahora: () => ahora,
    );
    s = ServicioHabitoEliminar(docs, ahora: () => ahora);
  });

  test('nada en claro en el almacén (regla 93)', () async {
    await s.configurar(
      ConfigHabito(
        tipo: TipoHabito.cigarrillo,
        inicio: DateTime.utc(2026, 11, 2),
        motivos: const ['mi hija MARCA_SECRETA'],
      ),
    );
    await s.registrarConsumo(TipoHabito.cigarrillo, horaMin: 600);
    final todo = almacen.datos.values.join();
    expect(todo, isNot(contains('MARCA_SECRETA')));
    expect(todo, isNot(contains('cigarrillo')));
    expect(todo, isNot(contains('consumo')));
    expect(
      (await s.config(TipoHabito.cigarrillo))!.motivos.single,
      contains('MARCA_SECRETA'),
    );
    // un solo sobre por día y tipo, más uno de config
    expect(
      almacen.datos.keys.where((k) => k.startsWith('hab.sobre.ana.')).length,
      2,
    );
  });

  Future<void> llenarBase(int porDia) async {
    for (var i = 0; i < 7; i++) {
      final f = DateTime.utc(2026, 11, 2 + i);
      for (var k = 0; k < porDia; k++) {
        await s.registrarConsumo(
          TipoHabito.cigarrillo,
          fecha: f,
          horaMin: 600 + k,
        );
      }
    }
  }

  test('línea base, promedio, fases y límites', () async {
    await s.configurar(
      ConfigHabito(
        tipo: TipoHabito.cigarrillo,
        inicio: DateTime.utc(2026, 11, 2),
        diaD: DateTime.utc(2026, 11, 30),
      ),
    );
    await llenarBase(12);
    ahora = DateTime.utc(2026, 11, 8, 20);
    var e = (await s.estado(TipoHabito.cigarrillo))!;
    expect(e.fase, FaseHabito.lineaBase);
    expect(e.promedioCentesimas, 1200);
    expect(e.limite, isNull); // en la línea base no hay metas
    ahora = DateTime.utc(2026, 11, 9, 8);
    e = (await s.estado(TipoHabito.cigarrillo))!;
    expect(e.fase, FaseHabito.reduccion);
    expect(e.limite, 9);
    expect(e.diasParaDiaD, 21);
    await s.registrarConsumo(TipoHabito.cigarrillo);
    expect((await s.estado(TipoHabito.cigarrillo))!.hoy, 1);
  });

  test('deshacer quita el consumo', () async {
    await s.configurar(
      ConfigHabito(
        tipo: TipoHabito.cigarrillo,
        inicio: DateTime.utc(2026, 11, 2),
      ),
    );
    final id = await s.registrarConsumo(TipoHabito.cigarrillo);
    expect((await s.estado(TipoHabito.cigarrillo))!.hoy, 1);
    await s.deshacerConsumo(id);
    expect((await s.estado(TipoHabito.cigarrillo))!.hoy, 0);
  });

  test('Día D, recaída sin culpa y racha libre', () async {
    await s.configurar(
      ConfigHabito(
        tipo: TipoHabito.cigarrillo,
        inicio: DateTime.utc(2026, 11, 2),
        diaD: DateTime.utc(2026, 11, 30),
      ),
    );
    ahora = DateTime.utc(2026, 12, 4, 9);
    var e = (await s.estado(TipoHabito.cigarrillo))!;
    expect(e.fase, FaseHabito.libre);
    expect([e.racha!.actual, e.racha!.mejor, e.racha!.acumulados], [5, 5, 5]);
    expect(e.enFoco, isTrue);
    ahora = DateTime.utc(2026, 12, 5, 9);
    await s.registrarConsumo(TipoHabito.cigarrillo);
    e = (await s.estado(TipoHabito.cigarrillo))!;
    expect(e.recaidaHoy, isTrue);
    expect([e.racha!.actual, e.racha!.mejor, e.racha!.acumulados], [0, 5, 5]);
    ahora = DateTime.utc(2026, 12, 6, 9);
    e = (await s.estado(TipoHabito.cigarrillo))!;
    expect([e.racha!.actual, e.racha!.mejor, e.racha!.acumulados], [1, 5, 6]);
  });

  test('ahorro oculto por defecto y calculado si se pide', () async {
    final base = DateTime.utc(2026, 11, 2);
    await s.configurar(ConfigHabito(tipo: TipoHabito.cigarrillo, inicio: base));
    await llenarBase(12);
    ahora = DateTime.utc(2026, 11, 10, 9);
    await s.cerrarDia(TipoHabito.cigarrillo, fecha: DateTime.utc(2026, 11, 9));
    expect((await s.estado(TipoHabito.cigarrillo))!.ahorroCentavos, isNull);
    await s.configurar(
      ConfigHabito(
        tipo: TipoHabito.cigarrillo,
        inicio: base,
        mostrarAhorro: true,
        precioCajetillaCentavos: 15000,
      ),
    );
    expect((await s.estado(TipoHabito.cigarrillo))!.ahorroCentavos, 9000);
  });

  test('azúcar: semáforo del refresco por periodo', () async {
    await s.configurar(
      ConfigHabito(
        tipo: TipoHabito.azucar,
        inicio: DateTime.utc(2026, 10, 1),
        limiteOcasional: 4,
      ),
    );
    ahora = DateTime.utc(2026, 11, 3, 12);
    var e = (await s.estado(TipoHabito.azucar))!;
    expect(e.semaforo, SemaforoHabito.verde);
    for (var i = 0; i < 3; i++) {
      await s.registrarConsumo(
        TipoHabito.azucar,
        categoria: 'refresco',
        ocasion: 'planeada',
      );
    }
    await s.registrarConsumo(TipoHabito.azucar, categoria: 'postre');
    e = (await s.estado(TipoHabito.azucar))!;
    expect(e.usadasPeriodo, 3);
    expect(e.semaforo, SemaforoHabito.ambar);
    await s.registrarConsumo(TipoHabito.azucar, categoria: 'refresco');
    await s.registrarConsumo(TipoHabito.azucar, categoria: 'refresco');
    expect(
      (await s.estado(TipoHabito.azucar))!.semaforo,
      SemaforoHabito.terracota,
    );
  });

  test(
    'azúcar sin límite definido no muestra semáforo (la app lo pregunta)',
    () async {
      await s.configurar(
        ConfigHabito(
          tipo: TipoHabito.azucar,
          inicio: DateTime.utc(2026, 10, 1),
        ),
      );
      expect((await s.estado(TipoHabito.azucar))!.semaforo, isNull);
    },
  );

  test('antojos superados se cuentan', () async {
    await s.guardarAntojo(
      TipoHabito.cigarrillo,
      resultado: ResultadoAntojo.superado,
      tecnica: 'agua',
    );
    await s.guardarAntojo(
      TipoHabito.cigarrillo,
      resultado: ResultadoAntojo.consumo,
    );
    expect(await s.antojosSuperados(TipoHabito.cigarrillo), 1);
    expect(jsonEncode(almacen.datos).contains('superado'), isFalse);
  });
}
