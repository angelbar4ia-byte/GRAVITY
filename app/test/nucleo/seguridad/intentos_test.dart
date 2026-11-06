import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/intentos.dart';

void main() {
  late AlmacenSeguroEnMemoria almacen;
  late DateTime ahora;

  Future<LimiteIntentos> abrir() async {
    final limite = LimiteIntentos(
      almacen,
      clave: 'prueba.intentos',
      reloj: () => ahora,
    );
    await limite.cargar();
    return limite;
  }

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    ahora = DateTime(2026, 10, 20, 9);
  });

  test('la espera empieza en 30 s, se duplica y llega a 15 min', () {
    const politica = PoliticaIntentos();
    expect(
      [for (var i = 1; i <= 8; i++) politica.esperaDelBloqueo(i)],
      const [
        Duration(seconds: 30),
        Duration(minutes: 1),
        Duration(minutes: 2),
        Duration(minutes: 4),
        Duration(minutes: 8),
        Duration(minutes: 15),
        Duration(minutes: 15),
        Duration(minutes: 15),
      ],
    );
  });

  test(
    '5 fallos bloquean; sobrevive al reinicio; un acierto reinicia',
    () async {
      var limite = await abrir();
      for (var i = 0; i < 4; i++) {
        expect(limite.anotarFallo('ana'), ResultadoFallo.otraVez);
      }
      expect(limite.anotarFallo('ana'), ResultadoFallo.bloqueado);
      expect(limite.esperaRestante('ana'), const Duration(seconds: 30));
      expect(limite.bloqueado('beto'), isFalse, reason: 'cada quien lo suyo');

      limite = await abrir(); // la app se cerró y se abrió
      expect(limite.bloqueado('ana'), isTrue);
      expect(limite.estadoDe('ana').bloqueos, 1);

      ahora = ahora.add(const Duration(seconds: 30));
      expect(limite.bloqueado('ana'), isFalse);
      limite.anotarAcierto('ana');
      expect(limite.estadoDe('ana').vacio, isTrue);
      limite = await abrir();
      expect(limite.estadoDe('ana').vacio, isTrue);
      expect(almacen.datos.containsKey('prueba.intentos'), isFalse);
    },
  );

  test('dato dañado: se empieza de cero sin fallar', () async {
    almacen.datos['prueba.intentos'] = '{no es json';
    final limite = await abrir();
    expect(limite.bloqueado('ana'), isFalse);
  });

  test('textoEspera', () {
    expect(textoEspera(const Duration(seconds: 30)), '30 segundos');
    expect(textoEspera(const Duration(seconds: 1)), '1 segundo');
    expect(textoEspera(const Duration(seconds: 61)), '2 minutos');
    expect(textoEspera(const Duration(minutes: 1)), '1 minuto');
  });
}
