import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:importar_biblia/importador.dart' as imp;
import 'package:test/test.dart';

// Fragmento FICTICIO: versículos de relleno, solo para validar la estructura.
List<Object?> falso({int quitar = -1}) => <Object?>[
      for (var i = 0; i < 66; i++)
        <String, Object?>{
          'abbrev': 'l$i',
          'chapters': <Object?>[
            for (var c = 0; c < canon[i].capitulos - (i == quitar ? 1 : 0); c++)
              <Object?>['  versículo   ficticio  uno', 'versículo ficticio dos']
          ]
        }
    ];

void main() {
  test('convierte y valida el canon', () {
    final m = imp.convertir(entrada: falso(), version: 'prueba', nombre: 'P',
        licencia: 'ficticia', origen: 'ficticio');
    final libros = m['libros']! as List;
    expect(libros.length, 66);
    expect(((libros[42] as List).length), 21);
    expect((((libros[0] as List)[0]) as List)[0], 'versículo ficticio uno');
    expect(m['licencia'], 'ficticia');
  });
  test('rechaza un canon incompleto', () {
    expect(() => imp.convertir(entrada: falso(quitar: 42), version: 'x',
        nombre: 'x', licencia: 'x', origen: 'x'), throwsFormatException);
    expect(() => imp.convertir(entrada: [], version: 'x', nombre: 'x',
        licencia: 'x', origen: 'x'), throwsFormatException);
  });

  group('entrada hostil (F3-14)', () {
    Map<String, Object?> ok() => {
          'version': 'prueba',
          'nombre': 'P',
          'licencia': 'ficticia',
          'origen': 'ficticio',
        };
    void rechaza(List<Object?> entrada, {Map<String, Object?>? meta}) {
      final m = {...ok(), ...?meta};
      expect(
          () => imp.convertir(
              entrada: entrada,
              version: m['version']! as String,
              nombre: m['nombre']! as String,
              licencia: m['licencia']! as String,
              origen: m['origen']! as String),
          throwsFormatException);
    }

    List<Object?> con(int libro, int cap, Object? versos) {
      final e = falso();
      ((e[libro] as Map)['chapters'] as List)[cap] = versos;
      return e;
    }

    test('elementos nulos o que no son objeto dan FormatException, no TypeError', () {
      final e = falso()..[3] = null;
      rechaza(e);
      rechaza(falso()..[5] = 'texto');
      rechaza(falso()..[5] = {'abbrev': 'x'});
      rechaza(falso()..[5] = {'chapters': 'no'});
      rechaza(con(0, 0, null));
      rechaza(con(0, 0, 'no es lista'));
      rechaza(con(0, 0, [1, 2]));
      rechaza(con(0, 0, [null]));
    });

    test('capítulos sin versículos y versículos vacíos', () {
      rechaza(con(0, 0, []));
      rechaza(con(0, 0, ['']));
      rechaza(con(0, 0, ['   \n\t ']));
    });

    test('caracteres de control y de inversión de texto', () {
      rechaza(con(0, 0, ['hola\u0000mundo']));
      rechaza(con(0, 0, ['hola\u0007']));
      rechaza(con(0, 0, ['\u202Eoloh']));
      rechaza(con(0, 0, ['hola\u2066x']));
      rechaza(con(0, 0, ['hola\u0085x']));
    });

    test('un versículo de más de 5000 caracteres (no un archivo de 5 MB)', () {
      rechaza(con(0, 0, ['a' * (imp.maximoCaracteresVersiculo + 1)]));
      final m = imp.convertir(
          entrada: con(0, 0, ['a' * imp.maximoCaracteresVersiculo]),
          version: 'p', nombre: 'P', licencia: 'l', origen: 'o');
      expect(m['formato'], 'gravity-biblia-v1');
    });

    test('version, nombre, licencia y origen vacíos o raros', () {
      rechaza(falso(), meta: {'version': ''});
      rechaza(falso(), meta: {'version': '   '});
      rechaza(falso(), meta: {'version': 'RVR 1909!'});
      rechaza(falso(), meta: {'version': 'a' * 21});
      rechaza(falso(), meta: {'licencia': ''});
      rechaza(falso(), meta: {'origen': '  '});
      rechaza(falso(), meta: {'nombre': ''});
      rechaza(falso(), meta: {'licencia': 'x' * 201});
      rechaza(falso(), meta: {'origen': 'a\u0000b'});
    });
  });
}
