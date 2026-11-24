import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:habitos_dominio/src/bici/tipos_bici.dart' show horaTexto;
import 'package:test/test.dart';

void main() {
  group('CA-B-08 tono', () {
    test('ningún mensaje usa palabras de culpa ni signos de exclamación', () {
      expect(MensajesBici.todos.length, greaterThan(40));
      for (final t in MensajesBici.todos) {
        for (final p in MensajesHabitos.prohibidas) {
          expect(
            t.toLowerCase().contains(p),
            isFalse,
            reason: '"$t" contiene "$p"',
          );
        }
      }
    });

    test(
      'CASO MALO: un mensaje con «fallaste» o «!» no pasaría la revisión',
      () {
        for (final mala in ['Fallaste esta semana', 'Hoy no saliste!']) {
          expect(
            MensajesHabitos.prohibidas.any(
              (p) => mala.toLowerCase().contains(p),
            ),
            isTrue,
          );
        }
      },
    );

    test('la omisión por clima o seguridad no produce mensaje de ruptura', () {
      for (final m in MotivoOmision.values) {
        final texto = mensajeAlOmitir(m);
        expect(texto, MensajesBici.noSalio);
        expect(texto, isNot(MensajesHabitos.rachaRota));
        expect(texto.toLowerCase(), isNot(contains('racha')));
        expect(texto.toLowerCase(), isNot(contains('rota')));
      }
      expect(mensajeAlOmitir(null), MensajesBici.noSalio);
    });

    test('los mensajes de 4.12 están en el catálogo', () {
      for (final t in [
        'Hoy toca tu salida en bici. ¿Todo listo?',
        'Salida registrada. Gracias por avisar.',
        'Hoy no salió la ruta. Cuando quieras, la retomamos.',
        'Tu revisión semanal puede esperar un rato más si lo necesitas.',
        'Un domingo tranquilo ayuda a recuperar.',
      ]) {
        expect(MensajesBici.todos, contains(t));
      }
    });

    test('de tú: ningún texto usa «usted»', () {
      for (final t in MensajesBici.todos) {
        expect(t.toLowerCase(), isNot(contains('usted')));
      }
    });
  });

  group('mensajes con datos', () {
    test('el aviso de regreso lo arma la persona y dice que nadie vigila', () {
      final m = MensajesBici.avisoRegreso(8 * 60, 12 * 60);
      expect(
        m,
        'Salgo a las 8:00 y regreso hacia las 12:00. No me vigila nadie: si '
        'no sé de ti, llámame.',
      );
      expect(m, isNot(contains('!')));
    });

    test('el intervalo de piernas se dice en horas y minutos', () {
      expect(
        MensajesBici.piernasIntervalo('C del jueves', 2205),
        'La sesión C del jueves queda a 36 h 45 min de la ruta.',
      );
      expect(duracionTexto(60), '1 h');
      expect(duracionTexto(45), '45 min');
      expect(horaTexto(14 * 60 + 5), '14:05');
    });
  });

  group('CA-B-31 (parte de dominio) títulos de respaldo discretos', () {
    test('≤ 40 caracteres, sin dígitos y de tú', () {
      expect(TextoAvisoBici.respaldo, isNotEmpty);
      for (final t in TextoAvisoBici.respaldo.values) {
        expect(t.length, lessThanOrEqualTo(40));
        expect(t, isNot(matches(RegExp(r'\d'))));
        expect(t, isNot(contains('!')));
      }
      expect(TextoAvisoBici.prepara.length, 27);
      expect(TextoAvisoBici.salida.length, 25);
    });
  });
}
