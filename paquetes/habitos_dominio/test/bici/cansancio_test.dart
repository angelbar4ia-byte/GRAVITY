import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

void main() {
  group('CA-B-10 cansancio', () {
    test('con «Cansado» propone una ruta más corta o de calle plana y no '
        'bloquea', () {
      final p = propuestaPorAnimo(EstadoAnimo.cansado);
      expect(p, isNotNull);
      expect(p!.texto, contains('más corta'));
      expect(p.texto, contains('calle plana'));
      expect(p.bloquea, isFalse);
    });

    test('con «Descansado» o «Normal» no hay propuesta', () {
      expect(propuestaPorAnimo(EstadoAnimo.descansado), isNull);
      expect(propuestaPorAnimo(EstadoAnimo.normal), isNull);
    });

    test('la propuesta no deja la salida sin disponible en la tarjeta', () {
      final c = tarjetaHoyBici(
        hoy: dia(2026, 12, 5),
        equipo: EquipoBici.celular,
        duracionMin: 240,
        revisionMin: 870,
      );
      expect(c.salidaDisponible, isTrue);
    });
  });
}
