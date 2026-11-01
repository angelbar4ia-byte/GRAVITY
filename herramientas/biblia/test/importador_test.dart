import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:importar_biblia/importador.dart' as imp;
import 'package:test/test.dart';

// Fragmento FICTICIO: versículos de relleno, solo para validar la estructura.
List<Object?> falso({int quitar = -1}) => [
      for (var i = 0; i < 66; i++)
        {
          'abbrev': 'l$i',
          'chapters': [
            for (var c = 0; c < canon[i].capitulos - (i == quitar ? 1 : 0); c++)
              ['  versículo   ficticio  uno', 'versículo ficticio dos']
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
}
