import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../formato.dart';
import '../superficies.dart';
import '../tema.dart';
import '../valores_diseno.dart';

/// Lo que se lleva tecleado en el teclado de monto: parte entera, si ya se
/// puso el punto y hasta dos decimales. Es puro (sin Flutter) para probar las
/// secuencias de teclas.
@immutable
class CapturaMonto {
  const CapturaMonto._(this.entero, this.conPunto, this.decimales);

  /// Nada tecleado: $0.00.
  static const vacia = CapturaMonto._('', false, '');

  /// Tope de dígitos de la parte entera: $999,999,999.99.
  static const maxDigitosEnteros = 9;

  /// Parte entera tecleada, sin ceros a la izquierda ('' o '0' es cero).
  final String entero;

  /// Si ya se tecleó el punto decimal.
  final bool conPunto;

  /// Decimales tecleados (0, 1 o 2).
  final String decimales;

  /// Empieza en [centavos] como si se hubiera tecleado: 8500 → "85",
  /// 8550 → "85.5", 8555 → "85.55".
  factory CapturaMonto.desdeCentavos(int centavos) {
    assert(centavos >= 0, 'El monto no puede ser negativo');
    if (centavos <= 0) return vacia;
    final entero = (centavos ~/ 100).toString();
    final resto = centavos % 100;
    if (resto == 0) return CapturaMonto._(entero, false, '');
    final dos = resto.toString().padLeft(2, '0');
    return CapturaMonto._(entero, true, dos.endsWith('0') ? dos[0] : dos);
  }

  /// El monto en centavos: "85.5" → 8550.
  int get centavos {
    final pesos = entero.isEmpty ? 0 : int.parse(entero);
    final cent = decimales.isEmpty ? 0 : int.parse(decimales.padRight(2, '0'));
    return pesos * 100 + cent;
  }

  /// Lo tecleado tal cual ("0", "85.", "85.5").
  String get texto {
    final e = entero.isEmpty ? '0' : entero;
    return conPunto ? '$e.$decimales' : e;
  }

  /// Agrega un dígito. Después del punto admite dos; antes, hasta
  /// [maxDigitosEnteros]. Lo que no cabe se ignora.
  CapturaMonto conDigito(int digito) {
    assert(digito >= 0 && digito <= 9, 'Un dígito de 0 a 9');
    if (conPunto) {
      if (decimales.length >= 2) return this;
      return CapturaMonto._(entero, true, '$decimales$digito');
    }
    if (entero == '0' || entero.isEmpty) {
      return CapturaMonto._('$digito', false, '');
    }
    if (entero.length >= maxDigitosEnteros) return this;
    return CapturaMonto._('$entero$digito', false, '');
  }

  /// Pone el punto decimal (una sola vez). Sin parte entera, queda "0.".
  CapturaMonto conPuntoDecimal() {
    if (conPunto) return this;
    return CapturaMonto._(entero.isEmpty ? '0' : entero, true, '');
  }

  /// Borra lo último que se tecleó: un decimal, el punto o un dígito entero.
  CapturaMonto sinUltimo() {
    if (decimales.isNotEmpty) {
      return CapturaMonto._(
        entero,
        true,
        decimales.substring(0, decimales.length - 1),
      );
    }
    if (conPunto) return CapturaMonto._(entero == '0' ? '' : entero, false, '');
    if (entero.length <= 1) return vacia;
    return CapturaMonto._(entero.substring(0, entero.length - 1), false, '');
  }

  @override
  bool operator ==(Object other) =>
      other is CapturaMonto &&
      other.entero == entero &&
      other.conPunto == conPunto &&
      other.decimales == decimales;

  @override
  int get hashCode => Object.hash(entero, conPunto, decimales);

  @override
  String toString() => 'CapturaMonto($texto = $centavos)';
}

/// Teclado numérico grande del **Registro rápido (+)** (DISENO_UX_UI, sección
/// 19; flujo F1): dígitos, punto decimal y borrar. Reporta el monto en
/// **centavos** con [alCambiar] cada vez que cambia.
///
/// - Teclas de 56 dp o más (nunca menos de 48) con su nombre para el lector de
///   pantalla ("Punto decimal", "Borrar").
/// - Con [compacto], teclas de 48 dp (la zona táctil mínima) y 4 dp entre
///   ellas: 204 dp en total en lugar de ~250. Es para las hojas que deben dejar
///   a la vista, sin desplazar, la categoría, la cuenta y el botón principal en
///   un teléfono de 360 × 800 dp (revisión de la Fase 1, I8). Mismas teclas,
///   mismo orden y mismo comportamiento.
/// - Mantener presionado *Borrar* deja el monto en cero.
/// - En la laptop también acepta el teclado físico (dígitos, punto o coma y
///   retroceso) cuando tiene el foco; con [autofocus] lo toma al abrir.
/// - Si [centavosIniciales] cambia a un valor distinto del que lleva (por
///   ejemplo, a 0 después de guardar), el teclado empieza de nuevo ahí.
///
/// El monto se muestra en la pantalla que lo usa, con `formatearCentavos`.
class TecladoMonto extends StatefulWidget {
  const TecladoMonto({
    super.key,
    required this.alCambiar,
    this.centavosIniciales = 0,
    this.autofocus = false,
    this.compacto = false,
  });

  final ValueChanged<int> alCambiar;
  final int centavosIniciales;
  final bool autofocus;

  /// Variante compacta: teclas de [altoTeclaCompacta] dp y
  /// [separacionCompacta] dp entre ellas.
  final bool compacto;

  /// Alto de una tecla en la variante compacta: la zona táctil mínima.
  static const altoTeclaCompacta = zonaTactilMinima;

  /// Separación entre teclas en la variante compacta.
  static const separacionCompacta = 4.0;

  /// Alto total de la variante compacta (4 filas y 3 separaciones).
  static const altoCompacto = 4 * altoTeclaCompacta + 3 * separacionCompacta;

  @override
  State<TecladoMonto> createState() => _TecladoMontoState();
}

/// Teclas del teclado numérico lateral, en orden del 0 al 9.
final _tecladoLateral = [
  LogicalKeyboardKey.numpad0,
  LogicalKeyboardKey.numpad1,
  LogicalKeyboardKey.numpad2,
  LogicalKeyboardKey.numpad3,
  LogicalKeyboardKey.numpad4,
  LogicalKeyboardKey.numpad5,
  LogicalKeyboardKey.numpad6,
  LogicalKeyboardKey.numpad7,
  LogicalKeyboardKey.numpad8,
  LogicalKeyboardKey.numpad9,
];

class _TecladoMontoState extends State<TecladoMonto> {
  late CapturaMonto _captura = CapturaMonto.desdeCentavos(
    widget.centavosIniciales,
  );
  final FocusNode _foco = FocusNode(debugLabel: 'TecladoMonto');

  @override
  void didUpdateWidget(TecladoMonto anterior) {
    super.didUpdateWidget(anterior);
    if (widget.centavosIniciales != anterior.centavosIniciales &&
        widget.centavosIniciales != _captura.centavos) {
      _captura = CapturaMonto.desdeCentavos(widget.centavosIniciales);
    }
  }

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  void _aplicar(CapturaMonto Function(CapturaMonto) cambio) {
    final nueva = cambio(_captura);
    if (nueva == _captura) return;
    final antes = _captura.centavos;
    setState(() => _captura = nueva);
    if (nueva.centavos != antes) widget.alCambiar(nueva.centavos);
  }

  void _tocar(CapturaMonto Function(CapturaMonto) cambio) {
    HapticFeedback.selectionClick();
    if (!_foco.hasFocus) _foco.requestFocus();
    _aplicar(cambio);
  }

  KeyEventResult _alTeclear(FocusNode nodo, KeyEvent evento) {
    if (evento is! KeyDownEvent && evento is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final tecla = evento.logicalKey;
    if (tecla == LogicalKeyboardKey.backspace) {
      _aplicar((c) => c.sinUltimo());
      return KeyEventResult.handled;
    }
    final lateral = _tecladoLateral.indexOf(tecla);
    if (lateral >= 0) {
      _aplicar((c) => c.conDigito(lateral));
      return KeyEventResult.handled;
    }
    if (tecla == LogicalKeyboardKey.numpadDecimal ||
        tecla == LogicalKeyboardKey.numpadComma) {
      _aplicar((c) => c.conPuntoDecimal());
      return KeyEventResult.handled;
    }
    final caracter = evento.character;
    if (caracter == null || caracter.length != 1) return KeyEventResult.ignored;
    final digito = int.tryParse(caracter);
    if (digito != null) {
      _aplicar((c) => c.conDigito(digito));
      return KeyEventResult.handled;
    }
    if (caracter == '.' || caracter == ',') {
      _aplicar((c) => c.conPuntoDecimal());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final compacto = widget.compacto;
    final alto = compacto
        ? TecladoMonto.altoTeclaCompacta
        : switch (v.densidad) {
            Densidad.compacta => 52.0,
            Densidad.comoda => 56.0,
            Densidad.grande => 64.0,
          };
    final espacio = compacto
        ? TecladoMonto.separacionCompacta
        : (e < 6 ? 6.0 : e);

    Widget digito(int d) => _Tecla(
      alto: alto,
      etiqueta: '$d',
      alTocar: () => _tocar((c) => c.conDigito(d)),
      child: Text('$d', style: _estiloTecla(v)),
    );

    final filas = <List<Widget>>[
      [digito(1), digito(2), digito(3)],
      [digito(4), digito(5), digito(6)],
      [digito(7), digito(8), digito(9)],
      [
        _Tecla(
          alto: alto,
          etiqueta: 'Punto decimal',
          alTocar: () => _tocar((c) => c.conPuntoDecimal()),
          child: Text('.', style: _estiloTecla(v)),
        ),
        digito(0),
        _Tecla(
          alto: alto,
          etiqueta: 'Borrar',
          pista: 'Mantén presionado para borrar todo',
          alTocar: () => _tocar((c) => c.sinUltimo()),
          alMantener: () => _tocar((_) => CapturaMonto.vacia),
          child: Icon(Icons.backspace_outlined, size: 24, color: v.textoFuerte),
        ),
      ],
    ];

    return Focus(
      focusNode: _foco,
      autofocus: widget.autofocus,
      onKeyEvent: _alTeclear,
      child: Semantics(
        container: true,
        label: 'Teclado numérico',
        value: formatearCentavos(_captura.centavos),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < filas.length; i++) ...[
              if (i > 0) SizedBox(height: espacio),
              Row(
                children: [
                  for (var j = 0; j < filas[i].length; j++) ...[
                    if (j > 0) SizedBox(width: espacio),
                    Expanded(child: filas[i][j]),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle _estiloTecla(ValoresDiseno v) =>
      v.numero(tamano: 24, peso: FontWeight.w500, color: v.textoFuerte);
}

class _Tecla extends StatelessWidget {
  const _Tecla({
    required this.alto,
    required this.etiqueta,
    required this.alTocar,
    required this.child,
    this.pista,
    this.alMantener,
  });

  final double alto;
  final String etiqueta;
  final String? pista;
  final VoidCallback alTocar;
  final VoidCallback? alMantener;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(v.radioGrande),
      side: BorderSide(color: v.borde, width: v.grosorBorde),
    );
    return Semantics(
      button: true,
      label: etiqueta,
      hint: pista,
      child: Material(
        color: v.superficieTecla,
        shape: forma,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          onLongPress: alMantener,
          customBorder: forma,
          canRequestFocus: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: alto < zonaTactilMinima ? zonaTactilMinima : alto,
              minWidth: zonaTactilMinima,
            ),
            child: Center(child: ExcludeSemantics(child: child)),
          ),
        ),
      ),
    );
  }
}
