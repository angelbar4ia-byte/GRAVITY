import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/seguridad/cifrado.dart';

void main() {
  test('solo el PIN correcto descifra; cada cifrado usa un nonce nuevo', () {
    final llave = LlavePin.derivar('2468', iteraciones: 50);
    const credencial = '{"refresh_token":"de-prueba"}';
    final sobre = CifradoPin.cifrar(llave, credencial);
    expect(sobre, isNot(contains('de-prueba')));
    expect(CifradoPin.cifrar(llave, credencial), isNot(sobre));

    expect(CifradoPin.descifrar('1357', sobre), isNull);
    final abierto = CifradoPin.descifrar('2468', sobre);
    expect(abierto?.$2, credencial);

    // La llave devuelta sirve para volver a cifrar (renovaciones).
    final otro = CifradoPin.cifrar(abierto!.$1, 'nuevo');
    expect(CifradoPin.descifrar('2468', otro)?.$2, 'nuevo');
  });

  test('un sobre dañado o alterado no se abre', () {
    final llave = LlavePin.derivar('2468', iteraciones: 50);
    final sobre = CifradoPin.cifrar(llave, 'secreto');
    expect(CifradoPin.descifrar('2468', 'no es json'), isNull);
    expect(CifradoPin.descifrar('2468', '{"v":9}'), isNull);
    final alterado = sobre.replaceFirst('"datos":"', '"datos":"AA');
    expect(CifradoPin.descifrar('2468', alterado), isNull);
  });
}
