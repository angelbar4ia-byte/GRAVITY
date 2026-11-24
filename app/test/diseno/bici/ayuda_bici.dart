// Ayudas de las pruebas de los componentes de «Bicicleta» (B4). No es una
// prueba (no termina en _test.dart).

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../ayuda_estilos.dart';
import '../ayuda_pruebas.dart';

/// Todos los estilos del sistema (los que se ofrecen y los que están en pausa).
List<Estilo> get todosLosEstilos => [...estilosIncluidos, ...estilosEnPausa];

/// Reloj que la prueba adelanta a mano. [avanzar] mueve el reloj y el tiempo
/// falso de las pruebas a la vez.
class RelojBici {
  RelojBici([DateTime? inicio])
    : momento = inicio ?? DateTime(2026, 11, 28, 9, 42, 10);

  DateTime momento;

  DateTime ahora() => momento;

  Future<void> avanzar(WidgetTester tester, Duration d) async {
    momento = momento.add(d);
    await tester.pump(d);
  }
}

/// Monta [hijo] con la personalidad de Hábitos (o la de la bici, Sport, con
/// [sport]) y el estilo pedido. [reducirMovimiento] simula la opción del
/// sistema.
Future<void> montarBici(
  WidgetTester tester,
  Widget hijo, {
  Estilo? estilo,
  Brightness brillo = Brightness.dark,
  bool sport = false,
  bool reducirMovimiento = false,
  double ancho = 360,
  Size? ventana,
  double? letra,
}) async {
  fijarVentana(tester, ventana ?? Size(ancho, 2200));
  if (letra != null) fijarEscalaDeLetra(tester, letra);
  final home = Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: reducirMovimiento),
        child: TemaModulo(
          modulo: Modulo.habitos,
          submodulo: sport ? Submodulo.bici : null,
          child: Builder(
            builder: (context) => ColoredBox(
              color: ValoresDiseno.de(context).fondo,
              child: SingleChildScrollView(
                child: Padding(padding: const EdgeInsets.all(16), child: hijo),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await montarConEstilo(
    tester,
    home,
    estilo: estilo ?? estiloPorDefecto,
    brillo: brillo,
  );
}

/// Quita el árbol para que no queden avisos pendientes al terminar la prueba.
Future<void> desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

/// Todos los textos que se dibujan.
List<String> textosVisibles(WidgetTester tester) {
  final textos = <String>[];
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final s = t.data ?? t.textSpan?.toPlainText();
    if (s != null) textos.add(s);
  }
  return textos;
}

/// Las etiquetas de accesibilidad del árbol de semántica.
List<String> etiquetasAccesibles(WidgetTester tester) {
  final etiquetas = <String>[];
  void recorrer(SemanticsNode n) {
    final l = n.label;
    if (l.isNotEmpty) etiquetas.add(l);
    n.visitChildren((h) {
      recorrer(h);
      return true;
    });
  }

  recorrer(tester.getSemantics(find.byType(Scaffold).first));
  return etiquetas;
}

/// Palabras que culpan o prohíben (CA-B-08): ninguna debe aparecer.
const palabrasProhibidas = [
  'fallaste',
  'fracaso',
  'perdiste',
  'culpa',
  'castigo',
  'vergüenza',
];

/// Palabras de contenido médico y de cifras de comida o líquidos (CA-B-01):
/// ningún texto de la interfaz las usa.
final patronMedico = RegExp(
  r'diagn[oó]stic|tratamiento|medicament|dosis|lesi[oó]n|tendin|esguince|'
  r'desgarro|hernia|artritis|fractura|inflamaci|infarto|litros?\b|gramos?\b|'
  r'calor[ií]as?\b|\d\s?ml\b',
  caseSensitive: false,
);

/// Síntomas que el texto «si te sientes mal» no debe nombrar (PB-19).
final patronSintomas = RegExp(
  r'mareo|dolor|pecho|confusi|desmay|n[aá]usea|palpita|infarto',
  caseSensitive: false,
);

/// Los cuatro estados que no son «listo».
const estadosSinContenido = [
  EstadoVistaBici.vacio,
  EstadoVistaBici.cargando,
  EstadoVistaBici.sinConexion,
  EstadoVistaBici.error,
];
