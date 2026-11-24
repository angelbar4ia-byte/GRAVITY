import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas_bici.dart';

TarjetaHoyBici tarjeta(
  DateTime hoy, {
  EquipoBici equipo = EquipoBici.celular,
  int dur = 240,
  List<TareaEstado> mant = const [],
  bool hecha = false,
}) => tarjetaHoyBici(
  hoy: hoy,
  equipo: equipo,
  duracionMin: dur,
  revisionMin: revision1430,
  mantenimiento: mant,
  salidaHecha: hecha,
);

void main() {
  group('CA-B-15 Hoy', () {
    test('el viernes por la noche muestra «Prepara tu salida»', () {
      final c = tarjeta(dia(2026, 12, 4));
      expect(c.tipo, TipoTarjetaBici.preparaTuSalida);
      expect(c.mensaje, 'Prepara tu salida');
      expect(c.regresoMin, isNull);
    });

    test(
      'el sábado muestra el regreso estimado y el encaje con la revisión',
      () {
        final c = tarjeta(sabado5dic);
        expect(c.tipo, TipoTarjetaBici.salida);
        expect(c.salidaMin, 8 * 60);
        expect(c.regresoMin, 12 * 60);
        expect(c.encaje!.cabe, isTrue);
        expect(c.encaje!.sobranMin, 60);
        expect(c.mensaje, MensajesBici.hoyTocaSalida);
        // Una salida larga: la tarjeta lo dice sin mover la revisión.
        final larga = tarjeta(sabado5dic, dur: 330);
        expect(larga.encaje!.cabe, isFalse);
        expect(larga.encaje!.faltanMin, 30);
        expect(larga.encaje!.revisionMin, revision1430);
      },
    );

    test('CASO MALO: los demás días no hay tarjeta de bicicleta', () {
      for (final d in [1, 2, 3, 6]) {
        // lunes 30/nov + d … ; dom 6/dic
        final dd = dia(2026, 11, 29 + d);
        if (dd.weekday == DateTime.friday || dd.weekday == DateTime.saturday) {
          continue;
        }
        expect(tarjeta(dd).tipo, TipoTarjetaBici.ninguna, reason: '$dd');
      }
      expect(tarjeta(dia(2026, 12, 6)).tipo, TipoTarjetaBici.ninguna);
    });

    test('salida ya registrada: «Salida registrada. Gracias por avisar.»', () {
      expect(
        tarjeta(sabado5dic, hecha: true).mensaje,
        MensajesBici.salidaRegistrada,
      );
    });

    test('el mantenimiento que toca aparece como línea en el viernes y el '
        'sábado', () {
      final mant = estadoMantenimiento(
        bici: biciA,
        mantenimientos: const [],
        hoy: dia(2026, 12, 4),
      );
      expect(tarjeta(dia(2026, 12, 4), mant: mant).mantenimientoToca, isEmpty);
      final toca = [
        const TareaEstado(
          tarea: TareaMantenimiento.lubricarCadena,
          estado: EstadoTarea.toca,
        ),
        const TareaEstado(
          tarea: TareaMantenimiento.limpiarTransmision,
          estado: EstadoTarea.alDia,
        ),
      ];
      expect(tarjeta(dia(2026, 12, 4), mant: toca).mantenimientoToca, [
        TareaMantenimiento.lubricarCadena,
      ]);
      expect(tarjeta(sabado5dic, mant: toca).mantenimientoToca, hasLength(1));
    });
  });

  group('qué ve cada equipo (6.1, 7, CA-B-29 en lo de dominio)', () {
    test('la tablet pública: solo la tarjeta de Hoy, sin ruta ni contacto y '
        'sin recordatorios', () {
      final v = visibilidadBici(EquipoBici.tabletPublica);
      expect(v.tarjetaHoy, isTrue);
      expect(v.rutas, isFalse);
      expect(v.contacto, isFalse);
      expect(v.recibeRecordatorios, isFalse);
      expect(v.textosSeguridad, isFalse);
      expect(
        tarjeta(
          sabado5dic,
          equipo: EquipoBici.tabletPublica,
        ).visibilidad!.contacto,
        isFalse,
      );
    });

    test('la laptop no muestra rutas ni contacto', () {
      final v = visibilidadBici(EquipoBici.laptop);
      expect((v.rutas, v.contacto), (false, false));
      expect(v.textosSeguridad, isTrue);
      expect(v.tarjetaHoy, isTrue);
    });

    test('teléfono y tablet personal ven todo lo de su equipo', () {
      for (final e in [EquipoBici.celular, EquipoBici.tabletPersonal]) {
        final v = visibilidadBici(e);
        expect(
          (v.rutas, v.contacto, v.recibeRecordatorios),
          (true, true, true),
        );
      }
    });
  });

  group('F-B1 / CA-B-34 pocos toques (en el dominio)', () {
    test('marcar la salida no exige ningún dato más', () {
      final s = Salida(id: 'x', fecha: sabado5dic);
      expect(s.validar(), isEmpty);
      expect(s.aJson()['estado'], 'hecha');
    });
  });
}
