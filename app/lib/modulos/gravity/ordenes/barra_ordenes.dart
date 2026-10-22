/// Barra de órdenes de GRAVITY: navegación sin IA
/// (`docs/DISENO_UX_UI.md`, secciones 7, 14 [F4] y 15).
///
/// - Sugerencias mientras se escribe; ↑ ↓ para elegir, Enter para abrir,
///   Esc para cerrar.
/// - Si no entiende, muestra "¿Quisiste decir…?" con opciones parecidas.
/// - Solo ofrece lo que el rol ve, y abre cada destino con su herramienta de
///   navegación (D1): GRAVITY actúa solo por herramientas declaradas. A la
///   cuidadora solo le ofrece su bandeja de solicitudes (D18); a la cuenta
///   maestra, nada que escriba o administre lo ajeno (D19).
/// - "Registrar gasto" abre la hoja de registro: la orden nunca guarda dinero
///   sola, la persona captura y confirma en la hoja.
/// - Ctrl+K la enfoca desde cualquier parte de la pantalla (sección 15).
///
/// Los colores y la letra salen de `Theme.of(context)` (los define el agente
/// diseno); aquí no hay colores fijos.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navegacion.dart' show TipoRegistro, opcionesDeRegistro;
import '../../../app/pantallas/registro_rapido.dart';
import '../../../app/sesion_efectiva.dart';
import '../../../nucleo/contratos/dispositivo.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../../../nucleo/herramientas/herramientas.dart';
import 'interprete_ordenes.dart';

/// Barra de órdenes de navegación. Va dentro de un `ProviderScope`.
class BarraOrdenes extends ConsumerStatefulWidget {
  const BarraOrdenes({
    super.key,
    required this.rol,
    required this.onNavegar,
    this.dispositivo,
    this.esMaestra,
    this.onAbrirHoja,
  });

  /// Rol de la sesión: decide qué destinos se ofrecen.
  final Rol rol;

  /// Dispositivo de la sesión (lo pasa la plataforma). Desarrollador solo se
  /// ofrece en la laptop (D16); sin dispositivo, no se ofrece.
  final TipoDispositivo? dispositivo;

  /// Abre una ruta de `Rutas` (la conecta el router de la plataforma).
  final void Function(String ruta) onNavegar;

  /// `true` si la sesión es la cuenta maestra (D19). `null`: se lee de la
  /// sesión (`esCuentaMaestraProvider` de la plataforma).
  final bool? esMaestra;

  /// Abre una hoja de registro. `null`: la abre la barra con el registro
  /// rápido de la plataforma (diálogo en la laptop, hoja inferior en el
  /// teléfono y la tablet), igual que Ctrl + N y el botón (+).
  final void Function(HojaDeRegistro hoja)? onAbrirHoja;

  @override
  ConsumerState<BarraOrdenes> createState() => _BarraOrdenesState();
}

/// Tipo de registro de la plataforma para cada hoja.
TipoRegistro tipoDeRegistro(HojaDeRegistro hoja) => switch (hoja) {
  HojaDeRegistro.gasto => TipoRegistro.gasto,
  HojaDeRegistro.ingresoExtra => TipoRegistro.ingresoExtra,
};

/// Ícono de cada destino de navegación.
IconData iconoDestino(HerramientaNavegacion destino) {
  if (destino.ruta == Rutas.desarrollador) return Icons.code;
  if (destino.hoja == HojaDeRegistro.gasto) return Icons.payments_outlined;
  if (destino.hoja == HojaDeRegistro.ingresoExtra) {
    return Icons.savings_outlined;
  }
  if (destino.ambito == AmbitoHerramienta.solicitudes) {
    return Icons.inbox_outlined;
  }
  if (destino.ruta == RutasDeHerramientas.semanaFinanzas) {
    return Icons.calendar_view_week_outlined;
  }
  return switch (destino.modulo) {
    Modulo.gravity => Icons.blur_circular,
    Modulo.finanzas => Icons.account_balance_wallet_outlined,
    Modulo.habitos => Icons.track_changes,
    Modulo.cuidados => Icons.favorite_border,
    Modulo.alimentacion => Icons.restaurant_menu,
    Modulo.casa => Icons.home_outlined,
    Modulo.ajustes => Icons.settings_outlined,
  };
}

/// Una fila del panel.
typedef _Fila = ({HerramientaNavegacion destino, String? palabra});

class _BarraOrdenesState extends ConsumerState<BarraOrdenes> {
  static final RegistroHerramientas _registro = RegistroHerramientas(
    herramientasNavegacion,
  );

  final TextEditingController _control = TextEditingController();
  final OverlayPortalController _panel = OverlayPortalController(
    debugLabel: 'Panel de la barra de órdenes',
  );
  late final FocusNode _foco = FocusNode(
    debugLabel: 'Barra de órdenes',
    onKeyEvent: _teclaEnCampo,
  );

  late InterpreteOrdenes _interprete;
  List<SugerenciaOrden> _sugerencias = const [];

  /// Si la sesión es la cuenta maestra (D19), como se armó [_interprete].
  late bool _esMaestra;

  /// "¿Quisiste decir…?" o "No entendí": se muestra en lugar de sugerencias.
  ResultadoOrden? _aviso;
  int _resaltada = -1;

  @override
  void initState() {
    super.initState();
    _esMaestra = widget.esMaestra ?? ref.read(esCuentaMaestraProvider);
    _interprete = _nuevoInterprete();
    _foco.addListener(_alCambiarFoco);
    HardwareKeyboard.instance.addHandler(_atajoGlobal);
  }

  InterpreteOrdenes _nuevoInterprete() => InterpreteOrdenes(
    rol: widget.rol,
    dispositivo: widget.dispositivo,
    esMaestra: _esMaestra,
  );

  /// Vuelve a armar los destinos (cambió el rol, el dispositivo o la marca
  /// de cuenta maestra) sin perder lo escrito.
  void _rearmar() {
    _interprete = _nuevoInterprete();
    _aviso = null;
    _resaltada = -1;
    _sugerencias = _foco.hasFocus
        ? _interprete.sugerir(_control.text)
        : const [];
    WidgetsBinding.instance.addPostFrameCallback((_) => _sincronizarPanel());
  }

  @override
  void didUpdateWidget(BarraOrdenes anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.rol != widget.rol ||
        anterior.dispositivo != widget.dispositivo ||
        anterior.esMaestra != widget.esMaestra) {
      _esMaestra = widget.esMaestra ?? ref.read(esCuentaMaestraProvider);
      _rearmar();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_atajoGlobal);
    _foco.removeListener(_alCambiarFoco);
    _foco.dispose();
    _control.dispose();
    super.dispose();
  }

  List<_Fila> get _filas => switch (_aviso) {
    OrdenParecida(:final opciones) => [
      for (final d in opciones) (destino: d, palabra: null),
    ],
    OrdenNoEntendida(:final disponibles) => [
      for (final d in disponibles) (destino: d, palabra: null),
    ],
    _ => [
      for (final s in _sugerencias) (destino: s.destino, palabra: s.palabra),
    ],
  };

  bool get _hayPanel =>
      _foco.hasFocus && (_aviso != null || _sugerencias.isNotEmpty);

  void _sincronizarPanel() {
    if (!mounted) return;
    if (_hayPanel) {
      if (!_panel.isShowing) _panel.show();
    } else if (_panel.isShowing) {
      _panel.hide();
    }
  }

  void _actualizar(VoidCallback cambio) {
    setState(cambio);
    _sincronizarPanel();
  }

  void _alCambiarFoco() {
    if (_foco.hasFocus) {
      _sugerencias = _interprete.sugerir(_control.text);
    } else {
      _aviso = null;
      _resaltada = -1;
    }
    _actualizar(() {});
  }

  bool _atajoGlobal(KeyEvent evento) {
    if (evento is! KeyDownEvent ||
        evento.logicalKey != LogicalKeyboardKey.keyK ||
        !HardwareKeyboard.instance.isControlPressed ||
        !mounted ||
        !(ModalRoute.isCurrentOf(context) ?? true)) {
      return false;
    }
    _foco.requestFocus();
    _control.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _control.text.length,
    );
    return true;
  }

  KeyEventResult _teclaEnCampo(FocusNode nodo, KeyEvent evento) {
    if (evento is! KeyDownEvent && evento is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final filas = _filas;
    final tecla = evento.logicalKey;
    if (tecla == LogicalKeyboardKey.arrowDown && filas.isNotEmpty) {
      _actualizar(() => _resaltada = (_resaltada + 1) % filas.length);
      return KeyEventResult.handled;
    }
    if (tecla == LogicalKeyboardKey.arrowUp && filas.isNotEmpty) {
      _actualizar(
        () => _resaltada = _resaltada <= 0 ? filas.length - 1 : _resaltada - 1,
      );
      return KeyEventResult.handled;
    }
    if (tecla == LogicalKeyboardKey.escape &&
        (_control.text.isNotEmpty || _aviso != null)) {
      _limpiar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _alEscribir(String texto) {
    _actualizar(() {
      _aviso = null;
      _resaltada = -1;
      _sugerencias = _interprete.sugerir(texto);
    });
  }

  void _alEnviar(String texto) {
    final filas = _filas;
    if (_resaltada >= 0 && _resaltada < filas.length) {
      _abrir(filas[_resaltada].destino);
      return;
    }
    switch (_interprete.interpretar(texto)) {
      case OrdenVacia():
        return;
      case OrdenEntendida(:final destino):
        _abrir(destino);
      case final aviso:
        _actualizar(() {
          _aviso = aviso;
          _resaltada = -1;
        });
    }
  }

  void _limpiar() {
    _control.clear();
    _actualizar(() {
      _aviso = null;
      _resaltada = -1;
      _sugerencias = const [];
    });
  }

  /// Abre la hoja de registro: la que conecte la plataforma o, si no, el
  /// registro rápido (diálogo en la laptop, hoja inferior en lo demás).
  void _abrirHoja(HojaDeRegistro hoja) {
    final conectada = widget.onAbrirHoja;
    if (conectada != null) {
      conectada(hoja);
      return;
    }
    final tipo = tipoDeRegistro(hoja);
    if (widget.dispositivo == TipoDispositivo.laptop) {
      abrirRegistroEnDialogo(context, tipo: tipo);
      return;
    }
    final opcion = opcionesDeRegistro.firstWhere((o) => o.tipo == tipo);
    abrirRegistro(context, opcion);
  }

  Future<void> _abrir(HerramientaNavegacion destino) async {
    try {
      await _registro.ejecutar(
        destino.nombre,
        const {},
        ContextoHerramienta(
          rol: widget.rol,
          esMaestra: _esMaestra,
          navegar: widget.onNavegar,
          abrirHoja: _abrirHoja,
        ),
      );
    } on HerramientaNoDisponible {
      if (!mounted) return;
      _actualizar(() {
        _aviso = OrdenNoEntendida(_control.text, _interprete.destinos);
        _resaltada = -1;
      });
      return;
    }
    if (mounted) _limpiar();
  }

  bool get _esEscritorio => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    if (widget.esMaestra == null) {
      final esMaestra = ref.watch(esCuentaMaestraProvider);
      if (esMaestra != _esMaestra) {
        _esMaestra = esMaestra;
        _rearmar();
      }
    }
    final tema = Theme.of(context);
    final ejemplo = _interprete.ejemplo;
    final campo = TextField(
      controller: _control,
      focusNode: _foco,
      onChanged: _alEscribir,
      onSubmitted: _alEnviar,
      // Sin esto, Enter quita el foco y se pierde el "¿Quisiste decir…?".
      onEditingComplete: () {},
      textInputAction: TextInputAction.go,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        // El ejemplo nombra un destino que el rol sí ve.
        hintText: ejemplo == null
            ? 'Escribe una orden…'
            : 'Escribe una orden… (p. ej., «$ejemplo»)',
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
          child: Text(
            '>',
            style: tema.textTheme.titleMedium?.copyWith(
              color: tema.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixText: _esEscritorio ? 'Ctrl+K' : null,
      ),
    );

    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _panel,
      overlayChildBuilder: _construirPanel,
      child: TextFieldTapRegion(
        child: Semantics(
          label: 'Barra de órdenes de GRAVITY',
          container: true,
          child: campo,
        ),
      ),
    );
  }

  /// Coloca el panel arriba de la barra si hay más espacio arriba (la barra
  /// suele ir abajo, como en la pantalla principal de la laptop) o abajo si no.
  Widget _construirPanel(BuildContext context, OverlayChildLayoutInfo info) {
    if (info.childPaintTransform.determinant() == 0.0) {
      return const SizedBox.shrink();
    }
    final tamanoCampo = info.childSize;
    final inversa = info.childPaintTransform.clone()..invert();
    final areaVisible = MediaQuery.paddingOf(context).deflateRect(
      MediaQuery.viewInsetsOf(context)
          .deflateRect(Offset.zero & info.overlaySize),
    );
    final areaEnCampo = MatrixUtils.transformRect(inversa, areaVisible);
    final espacioArriba = -areaEnCampo.top;
    final espacioAbajo = areaEnCampo.bottom - tamanoCampo.height;
    final abreArriba = espacioArriba > espacioAbajo;
    final alto = (abreArriba ? espacioArriba : espacioAbajo).clamp(
      kMinInteractiveDimension,
      double.infinity,
    );
    final origenY = abreArriba ? -alto : tamanoCampo.height;
    final transformacion = info.childPaintTransform.clone()
      ..translateByDouble(0, origenY, 0, 1);

    return Transform(
      transform: transformacion,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints.tight(Size(tamanoCampo.width, alto)),
          child: Align(
            alignment: abreArriba
                ? AlignmentDirectional.bottomStart
                : AlignmentDirectional.topStart,
            child: TextFieldTapRegion(
              child: ExcludeFocus(child: _contenidoPanel(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenidoPanel(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final filas = _filas;
    final encabezado = switch (_aviso) {
      OrdenParecida() => '¿Quisiste decir…?',
      OrdenNoEntendida(:final texto, :final disponibles) =>
        disponibles.isEmpty
            ? 'No entendí «${texto.trim()}». No hay destinos disponibles para tu rol.'
            : 'No entendí «${texto.trim()}». Puedes abrir:',
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: esquema.surfaceContainerHigh,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: esquema.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              if (encabezado != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    encabezado,
                    style: tema.textTheme.labelLarge?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final (i, fila) in filas.indexed)
                _FilaDestino(
                  destino: fila.destino,
                  palabra: fila.palabra,
                  resaltada: i == _resaltada,
                  alTocar: () => _abrir(fila.destino),
                ),
              if (_esEscritorio && filas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: Text(
                    '↑ ↓ para elegir · Enter para abrir · Esc para cerrar',
                    style: tema.textTheme.labelSmall?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaDestino extends StatelessWidget {
  const _FilaDestino({
    required this.destino,
    required this.palabra,
    required this.resaltada,
    required this.alTocar,
  });

  final HerramientaNavegacion destino;
  final String? palabra;
  final bool resaltada;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        key: ValueKey('destino-${destino.nombre}'),
        dense: true,
        selected: resaltada,
        selectedTileColor: esquema.primary.withValues(alpha: 0.12),
        leading: Icon(iconoDestino(destino)),
        title: Text(destino.titulo),
        subtitle: palabra == null
            ? null
            : Text('«$palabra» → ${destino.etiqueta}'),
        trailing: Text(
          destino.ruta,
          style: tema.textTheme.labelSmall?.copyWith(
            color: esquema.onSurfaceVariant,
            fontFamily: 'monospace',
          ),
        ),
        onTap: alTocar,
      ),
    );
  }
}
