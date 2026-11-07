// El medidor del arranque registra pasos y marcas sin inventar cifras.
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/rendimiento/medidor_arranque.dart';

void main() {
  test('mide cada paso con el reloj inyectado y calcula hasta el primer cuadro',
      () async {
    var ms = 0;
    final m = MedidorArranque(reloj: () => Duration(milliseconds: ms));
    m.marcar('main');
    final valor = await m.medir('firebase', () async {
      ms += 120;
      return 7;
    });
    await m.medir('sesion', () async => ms += 30);
    ms += 50;
    m.marcar(MedidorArranque.pasoPrimerCuadro);
    expect(valor, 7);
    expect(m.pasos.map((p) => p.nombre), ['main', 'firebase', 'sesion', 'primer_cuadro']);
    expect(m.pasos[1].duracion, const Duration(milliseconds: 120));
    expect(m.hasta('sesion'), const Duration(milliseconds: 150));
    expect(m.hastaPrimerCuadro, const Duration(milliseconds: 200));
    expect(m.hasta('no_existe'), isNull);
    expect(m.resumen(), contains('firebase: 120 (dura 120)'));
    expect(m.aJson().last['paso'], 'primer_cuadro');
  });

  test('un paso que falla se anota y el error sigue', () async {
    final m = MedidorArranque(reloj: () => Duration.zero);
    await expectLater(
      m.medir('malo', () async => throw StateError('x')),
      throwsStateError,
    );
    expect(m.pasos.single.nombre, 'malo');
  });
}
