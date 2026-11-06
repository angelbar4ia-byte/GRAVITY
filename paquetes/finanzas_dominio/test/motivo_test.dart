// El motivo necesita al menos 3 caracteres visibles (endurecimiento de la Fase
// 1b, N2; `fin_motivo_valido` en el servidor): sin espacios, tabuladores,
// saltos de línea, espacios Unicode ni invisibles. Datos de ejemplo inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

import 'libro_test.dart' show ahora, dia, libroBase, mov, yo;

void main() {
  group('Motivo: al menos 3 caracteres visibles', () {
    test('cuenta los caracteres visibles', () {
      expect(caracteresVisibles(null), 0);
      expect(caracteresVisibles(''), 0);
      expect(caracteresVisibles('   '), 0);
      expect(caracteresVisibles(' a b  c '), 3);
      expect(caracteresVisibles('ñandú'), 5);
      expect(caracteresVisibles('😀😀😀'), 3, reason: 'un emoji es un solo carácter');
    });

    test('vale con 3 o más; no con 0, 1 o 2', () {
      expect(motivoValido('abc'), isTrue);
      expect(motivoValido('  Luz  '), isTrue);
      expect(motivoValido('Se capturó mal'), isTrue);
      for (final corto in [null, '', ' ', 'a', 'ab', ' a  b ', '\t\n x \n']) {
        expect(motivoValido(corto), isFalse, reason: '"$corto"');
      }
    });

    test('los espacios y los invisibles de Unicode no cuentan', () {
      const invisibles = [
        ' ', // espacio de no separación
        '­', // guion blando
        '​', // espacio de ancho cero
        '‌',
        '‍',
        '‎',
        '‏',
        ' ', // separador de línea
        ' ', // separador de párrafo
        ' ',
        ' ',
        '⁠',
        '⁢',
        '⠀', // braille en blanco
        '　', // espacio ideográfico
        'ㅤ', // relleno hangul
        '﻿', // marca de orden de bytes
        'ﾠ',
        '\u0085',
        '\u0000',
        '\u007F',
      ];
      for (final i in invisibles) {
        // Dos letras con invisibles en medio: no llegan a 3.
        expect(motivoValido('a$i$i b'), isFalse, reason: 'U+${i.codeUnitAt(0).toRadixString(16)}');
        // Con una tercera letra sí.
        expect(motivoValido('a${i}b${i}c'), isTrue, reason: 'U+${i.codeUnitAt(0).toRadixString(16)}');
        // Puros invisibles: nada.
        expect(motivoValido(i * 10), isFalse, reason: 'U+${i.codeUnitAt(0).toRadixString(16)}');
      }
    });

    test('la ayuda y el mensaje dicen la regla', () {
      expect(ayudaDelMotivo, contains('3'));
      expect(mensajeMotivoCorto, contains('3'));
      expect(minimoCaracteresDeMotivo, 3);
    });
  });

  group('Motivo válido (Fase 4): 2 letras o dígitos y no todos iguales', () {
    test('subrayados, puntos, guiones y signos solos no valen', () {
      for (final malo in ['___', '...', '---', '***', '!!!', '_-_', 'a--', '1__', '😀😀😀', '¿?¡']) {
        expect(motivoValido(malo), isFalse, reason: '"$malo"');
      }
    });

    test('un solo carácter repetido no vale', () {
      for (final malo in ['aaa', 'AAA', '111', '0000', '  eee  ', 'x x x']) {
        expect(motivoValido(malo), isFalse, reason: '"$malo"');
      }
    });

    test('con 2 letras o dígitos y variedad sí vale', () {
      for (final bueno in ['ab-', 'a_b', '1.5', 'luz', 'ñu.', 'aab', 'abab', '12a', 'Se pasó']) {
        expect(motivoValido(bueno), isTrue, reason: '"$bueno"');
      }
    });

    test('cuenta letras con acento y dígitos Unicode', () {
      expect(letrasODigitos('ñé-'), 2);
      expect(letrasODigitos('___'), 0);
      expect(letrasODigitos(null), 0);
      expect(motivoValido('ñé-'), isTrue);
    });

    test('el mensaje dice la regla completa', () {
      expect(mensajeMotivoCorto, contains('2 letras'));
      expect(ayudaDelMotivo, contains('2 letras'));
      expect(minimoLetrasODigitosDeMotivo, 2);
    });
  });

  group('El libro aplica la regla', () {
    test('una anulación con motivo corto o en blanco se rechaza', () {
      final libro = libroBase();
      final g = libro.agregar(mov(TipoMovimiento.gasto, 'efectivo', 'alimentacion', 4500));
      for (final malo in ['', '  ', 'a', 'ab', ' a b ​']) {
        expect(
          () => libro.anular(g.id, nuevoId: 'an', motivo: malo, registradoPor: yo, registradoEn: ahora),
          throwsA(isA<ErrorLibro>().having((e) => e.mensaje, 'mensaje', contains('3 caracteres'))),
          reason: '"$malo"',
        );
      }
      libro.anular(g.id, nuevoId: 'an', motivo: 'Dup', registradoPor: yo, registradoEn: ahora);
      expect(libro.estaAnulado(g.id), isTrue);
    });

    test('un ajuste con motivo corto se rechaza', () {
      final libro = libroBase()
        ..agregar(mov(TipoMovimiento.apertura, 'apertura', 'efectivo', 80000));
      Movimiento ajuste(String motivo) => Movimiento(
        id: 'aj-${motivo.length}',
        tipo: TipoMovimiento.ajuste,
        fecha: dia,
        registradoEn: ahora,
        cuentaOrigenId: 'ajustes',
        cuentaDestinoId: 'efectivo',
        monto: 100,
        realizadoPor: yo,
        motivo: motivo,
      );
      expect(() => libro.agregar(ajuste('ok')), throwsA(isA<ErrorLibro>()));
      expect(() => libro.agregar(ajuste('   ')), throwsA(isA<ErrorLibro>()));
      expect(() => libro.agregar(ajuste('Faltó')), returnsNormally);
    });

    test('una conciliación con diferencia exige un motivo de 3 caracteres', () {
      final libro = libroBase()
        ..agregar(mov(TipoMovimiento.apertura, 'apertura', 'efectivo', 80000));
      expect(
        () => libro.conciliar(
          cuentaId: 'efectivo',
          fecha: dia,
          saldoDeclarado: 79000,
          cuentaAjustesId: 'ajustes',
          idAjuste: 'aj1',
          persona: yo,
          registradoEn: ahora,
          motivo: 'no',
        ),
        throwsA(isA<ErrorLibro>()),
      );
      final c = libro.conciliar(
        cuentaId: 'efectivo',
        fecha: dia,
        saldoDeclarado: 79000,
        cuentaAjustesId: 'ajustes',
        idAjuste: 'aj1',
        persona: yo,
        registradoEn: ahora,
        motivo: 'Cambio',
      );
      expect(c.ajuste, isNotNull);
    });

    test('un movimiento en nombre de otra persona exige el motivo', () {
      final libro = libroBase();
      Movimiento enNombre(String motivo) => Movimiento(
        id: 'n-${motivo.length}',
        tipo: TipoMovimiento.gasto,
        fecha: dia,
        registradoEn: ahora,
        cuentaOrigenId: 'efectivo',
        cuentaDestinoId: 'alimentacion',
        monto: 100,
        realizadoPor: 'papa',
        registradoPor: yo,
        enNombreDe: 'papa',
        motivo: motivo,
      );
      expect(() => libro.agregar(enNombre('a')), throwsA(isA<ErrorLibro>()));
      expect(() => libro.agregar(enNombre('​​​')), throwsA(isA<ErrorLibro>()));
      expect(() => libro.agregar(enNombre('Súper')), returnsNormally);
    });

    test('un libro restaurado no rechaza motivos viejos de dos caracteres', () {
      final viejo = Movimiento(
        id: 'viejo',
        tipo: TipoMovimiento.ajuste,
        fecha: dia,
        registradoEn: ahora,
        cuentaOrigenId: 'ajustes',
        cuentaDestinoId: 'efectivo',
        monto: 100,
        realizadoPor: yo,
        motivo: 'ok',
      );
      final libro = LibroMovimientos.restaurar(
        cuentas: libroBase().cuentas,
        movimientos: [viejo],
        validar: false,
      );
      expect(libro.movimientos, [viejo], reason: 'lo ya guardado nunca se rechaza');
    });
  });
}
