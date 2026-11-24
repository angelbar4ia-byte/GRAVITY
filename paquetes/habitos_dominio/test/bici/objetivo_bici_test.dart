import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas_bici.dart';

void main() {
  group('CA-B-11 objetivo «Bicicleta»: meta mensual, sin racha', () {
    test('es de tipo meta, «salidas del mes», 3 por omisión y válido', () {
      expect(ObjetivoBici.titulo, 'Bicicleta');
      expect(ObjetivoBici.tipo, TipoObjetivo.meta);
      expect(const ReglasBicicleta().metaMensual, 3);
      expect(ObjetivoBici.validar(), isEmpty);
      expect(
        ObjetivoBici.validar(reglas: const ReglasBicicleta(metaMensual: 0)),
        isNotEmpty,
      );
    });

    test('cuenta las salidas del mes (hechas y parciales) contra la meta', () {
      final s = [
        salida('1', dia(2026, 12, 5)),
        salida('2', dia(2026, 12, 12), estado: EstadoSalida.parcial),
        salida('3', dia(2026, 11, 28)), // otro mes
      ];
      final a = avanceMensual(salidas: s, mes: dia(2026, 12, 20));
      expect(a.salidas, 2);
      expect(a.meta, 3);
      expect(a.faltan, 1);
      expect(a.cumplida, isFalse);
      final b = avanceMensual(
        salidas: [...s, salida('4', dia(2026, 12, 19))],
        mes: dia(2026, 12, 1),
      );
      expect(b.cumplida, isTrue);
      expect(b.faltan, 0);
    });

    test('una salida omitida por clima no suma, no resta y no rompe nada', () {
      final s = [
        salida('1', dia(2026, 12, 5)),
        salida(
          '2',
          dia(2026, 12, 12),
          estado: EstadoSalida.omitida,
          motivo: MotivoOmision.clima,
        ),
      ];
      final a = avanceMensual(salidas: s, mes: dia(2026, 12, 1));
      expect(a.salidas, 1);
      expect(a.faltan, 2);
      expect(mensajeAlOmitir(MotivoOmision.clima), MensajesBici.noSalio);
      expect(mensajeAlOmitir(MotivoOmision.seguridad), MensajesBici.noSalio);
      expect(s[1].validar(), isEmpty);
    });

    test('CASO MALO: una semana sin salida no produce «racha rota»', () {
      final a = avanceMensual(salidas: const [], mes: dia(2026, 12, 1));
      expect(a.salidas, 0);
      expect(a.hayRachaSemanal, isFalse);
      expect(
        MensajesBici.todos.where((t) => t.toLowerCase().contains('racha')),
        isEmpty,
      );
      expect(MensajesBici.todos, isNot(contains(MensajesHabitos.rachaRota)));
    });

    test('el motivo solo acompaña a una salida omitida', () {
      final mal = Salida(
        id: 'x',
        fecha: dia(2026, 12, 5),
        motivo: MotivoOmision.clima,
      );
      expect(mal.validar().map((e) => e.codigo), ['motivo_sin_omision']);
    });

    test('«marcar Salí» (1 toque) es una salida hecha sin más datos', () {
      final s = Salida(id: 'x', fecha: dia(2026, 12, 5));
      expect(s.estado, EstadoSalida.hecha);
      expect(s.validar(), isEmpty);
      expect(s.cuenta, isTrue);
    });
  });
}
