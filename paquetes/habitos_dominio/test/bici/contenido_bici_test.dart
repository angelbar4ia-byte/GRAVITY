import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

void main() {
  group('CA-B-01 sin contenido médico', () {
    test('ningún texto del módulo tiene diagnóstico, tratamiento, '
        'medicamento, dosis, litros, gramos, calorías ni enfermedad', () {
      final textos = textosDeBici();
      expect(textos.length, greaterThan(50));
      expect(validarContenidoBici(textos), isEmpty);
      // También pasa la lista médica del gimnasio.
      expect(validarContenidoMedico(textos), isEmpty);
    });

    test('CASO MALO: agregar «infarto» o «500 ml» a un texto falla', () {
      final conInfarto = validarContenidoBici([
        ...textosDeBici(),
        'Podría ser un infarto.',
      ]);
      expect(conInfarto, hasLength(1));
      expect(conInfarto.single, contains('infarto'));
      final conMl = validarContenidoBici([...textosDeBici(), 'Toma 500 ml']);
      expect(conMl, isNotEmpty);
      expect(conMl.join(), contains('ml'));
      // Pegado a la cifra también se detecta.
      expect(palabrasProhibidasEn('Lleva 500ml de agua'), isNotEmpty);
      expect(palabrasProhibidasEn('30 g de azúcar'), isNotEmpty);
    });

    test('CASO MALO: detecta litros, gramos, calorías y las del gimnasio', () {
      for (final mala in [
        'Bebe dos litros',
        'Come 40 gramos',
        'Suma 300 calorías',
        'Es una tendinitis',
        'Toma ibuprofeno',
        'El tratamiento indicado',
        'Puede ser un mareo',
        'Tienes deshidratación',
        'una dosis',
      ]) {
        expect(palabrasProhibidasEn(mala), isNotEmpty, reason: mala);
      }
    });

    test('las frases fijas de 4.4 no dan falsos positivos', () {
      for (final ok in [
        MensajesBici.lineaFija,
        MensajesBici.aguaYComida,
        'Salgo a las 8:00 y regreso hacia las 12:00.',
        'Una salida de 4 h con 15 min de margen',
      ]) {
        expect(palabrasProhibidasEn(ok), isEmpty, reason: ok);
      }
    });

    test('todo texto de seguridad lleva su marca según 4.4', () {
      expect(MensajesBici.lineaFija, contains('no sustituye'));
      expect(MensajesBici.siTeSientesMal, contains('médico'));
      expect(MensajesBici.siTeSientesMal, contains('emergencias'));
      expect(MensajesBici.emergencia, contains('emergencias'));
      expect(MensajesBici.horaDeRegreso, contains('no vigila'));
      expect(MensajesBici.horaDeRegreso, contains('nadie recibe'));
      expect(MensajesBici.seguridadCalle, contains('casco'));
      expect(MensajesBici.seguridadTerreno, contains('llantas'));
    });

    test('«si te sientes mal» NO nombra síntomas ni enfermedades', () {
      expect(palabrasProhibidasEn(MensajesBici.siTeSientesMal), isEmpty);
      final s = MensajesBici.siTeSientesMal.toLowerCase();
      for (final sintoma in [
        'mareo',
        'pecho',
        'confusión',
        'desmayo',
        'dolor',
        'infarto',
      ]) {
        expect(s.contains(sintoma), isFalse, reason: sintoma);
      }
    });

    test('el texto de agua y comida no trae cifras', () {
      expect(MensajesBici.aguaYComida, isNot(matches(RegExp(r'\d'))));
    });
  });

  group('contenido `borrador` (PG-25 / R-B-7)', () {
    test('el catálogo de preparación y de mantenimiento nace borrador', () {
      expect(
        catalogoPreparacion.every(
          (p) => p.revision == RevisionContenido.borrador,
        ),
        isTrue,
      );
      expect(
        catalogoMantenimiento.every(
          (m) => m.revision == RevisionContenido.borrador,
        ),
        isTrue,
      );
      expect(contenidoBiciEnRevision(), isTrue);
      expect(MensajesBici.contenidoEnRevision, 'Contenido en revisión');
    });

    test('los intervalos iniciales son «Propuesta sin fuente»', () {
      for (final m in catalogoMantenimiento) {
        expect(m.origen, 'Propuesta sin fuente');
      }
      expect(MensajesBici.confirmaIntervalos, contains('taller'));
    });
  });
}
