/// Pantalla principal de GRAVITY en la laptop (DISENO_UX_UI, sección 7):
/// encabezado, paneles HOY / CUIDADOS / FINANZAS / AVISOS, núcleo central con
/// saludo, barra de órdenes y barra de módulos. Si la ventana es angosta, los
/// paneles se apilan (sección 8).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import 'resumen_gravity.dart';
import 'saludo.dart';

/// Ancho mínimo para las tres columnas; debajo, los paneles se apilan.
const double anchoTresColumnas = 1000;

class PantallaPrincipalGravity extends ConsumerWidget {
  const PantallaPrincipalGravity({super.key, this.barraOrdenes});

  /// Barra de órdenes del agente asistente. Si es `null`, se muestra una barra
  /// de muestra deshabilitada.
  final Widget? barraOrdenes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final barra = barraOrdenes ?? const _BarraOrdenesMuestra();
    return Scaffold(
      backgroundColor: v.fondo,
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(
              LogicalKeyboardKey.keyO,
              control: true,
              shift: true,
            ): () =>
                ref.read(modoPrivadoProvider.notifier).alternar(),
          },
          child: Focus(
            autofocus: true,
            child: LayoutBuilder(
              builder: (context, limites) =>
                  limites.maxWidth >= anchoTresColumnas
                  ? _DisenoAmplio(barraOrdenes: barra)
                  : _DisenoApilado(
                      barraOrdenes: barra,
                      ancho: limites.maxWidth,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Distribuciones ------------------------------------------------------------

class _DisenoAmplio extends StatelessWidget {
  const _DisenoAmplio({required this.barraOrdenes});

  final Widget barraOrdenes;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final hueco = v.espacio * 5;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: hueco * 1.6,
        vertical: hueco * 1.4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Encabezado(),
          SizedBox(height: hueco),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ColumnaPaneles(
                    key: const ValueKey('columna-izquierda'),
                    paneles: const [_PanelHoy(), _PanelCuidados()],
                  ),
                ),
                SizedBox(width: hueco),
                const Expanded(flex: 2, child: _PanelNucleo()),
                SizedBox(width: hueco),
                Expanded(
                  child: _ColumnaPaneles(
                    key: const ValueKey('columna-derecha'),
                    paneles: const [_PanelFinanzas(), _PanelAvisos()],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: hueco),
          barraOrdenes,
          SizedBox(height: v.espacio * 3),
          const _BarraModulos(),
        ],
      ),
    );
  }
}

class _DisenoApilado extends StatelessWidget {
  const _DisenoApilado({required this.barraOrdenes, required this.ancho});

  final Widget barraOrdenes;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final hueco = v.espacio * 3;
    final margen = ancho < 600 ? 16.0 : hueco * 1.5;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: margen, vertical: hueco),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Encabezado(),
          SizedBox(height: hueco),
          const _PanelNucleo(compacto: true),
          SizedBox(height: hueco),
          barraOrdenes,
          SizedBox(height: hueco),
          _ColumnaPaneles(
            desplazable: false,
            paneles: const [
              _PanelHoy(),
              _PanelCuidados(),
              _PanelFinanzas(),
              _PanelAvisos(),
            ],
          ),
          SizedBox(height: hueco),
          const _BarraModulos(),
        ],
      ),
    );
  }
}

/// Columna de paneles; se omite el que no tiene datos para el rol.
class _ColumnaPaneles extends ConsumerWidget {
  const _ColumnaPaneles({
    super.key,
    required this.paneles,
    this.desplazable = true,
  });

  final List<_Panel> paneles;
  final bool desplazable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final resumen = ref.watch(resumenGravityProvider);
    final visibles = paneles.where((p) => p.visible(resumen)).toList();
    final columna = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visibles.length; i++) ...[
          if (i > 0) SizedBox(height: v.espacio * 2),
          visibles[i],
        ],
      ],
    );
    return desplazable ? SingleChildScrollView(child: columna) : columna;
  }
}

/// Un panel de resumen que puede no aplicar para el rol.
abstract class _Panel extends Widget {
  const _Panel();

  bool visible(ResumenGravity resumen);
}

// --- Encabezado --------------------------------------------------------------

class _Encabezado extends ConsumerWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final ahora = ref.watch(horaActualProvider);
    final enLinea = ref.watch(resumenGravityProvider.select((r) => r.enLinea));
    final privado = ref.watch(modoPrivadoProvider);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: v.espacio * 3,
      runSpacing: v.espacio * 1.5,
      children: [
        Semantics(
          header: true,
          label: 'GRAVITY',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size.square(28),
                painter: _PintorLogo(v.acento),
              ),
              SizedBox(width: v.espacio * 1.5),
              Text(
                'GRAVITY',
                // 24 px: texto grande (3:1 basta para el acento sobre el fondo).
                style: v.titulo(
                  tamano: 24,
                  color: v.acento,
                  espaciadoLetras: 24 * 0.3,
                ),
              ),
            ],
          ),
        ),
        Text(
          fechaYHora(ahora).toUpperCase(),
          key: const ValueKey('fecha-hora'),
          style: v
              .numero(tamano: 14, color: v.textoTenue)
              .copyWith(letterSpacing: 14 * 0.12),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: v.espacio * 1.5,
          runSpacing: v.espacio,
          children: [
            _IndicadorConexion(enLinea: enLinea),
            _BotonModoPrivado(activo: privado),
          ],
        ),
      ],
    );
  }
}

class _IndicadorConexion extends StatelessWidget {
  const _IndicadorConexion({required this.enLinea});

  final bool enLinea;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final texto = enLinea ? 'En línea' : 'Sin conexión';
    return Semantics(
      label: 'Estado: $texto',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enLinea ? v.exito : v.alerta,
            ),
          ),
          SizedBox(width: v.espacio),
          Text(texto, style: v.lectura(tamano: 13, color: v.textoTenue)),
        ],
      ),
    );
  }
}

class _BotonModoPrivado extends ConsumerWidget {
  const _BotonModoPrivado({required this.activo});

  final bool activo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    return Tooltip(
      message: 'Modo privado (Ctrl + Shift + O)',
      child: Semantics(
        toggled: activo,
        child: OutlinedButton.icon(
          key: const ValueKey('boton-modo-privado'),
          onPressed: () => ref.read(modoPrivadoProvider.notifier).alternar(),
          style: OutlinedButton.styleFrom(
            backgroundColor: activo
                ? Color.alphaBlend(v.acento.withValues(alpha: 0.16), v.fondo)
                : Colors.transparent,
            side: BorderSide(color: activo ? v.acento : v.borde),
          ),
          icon: Icon(
            activo ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
          ),
          label: Text(activo ? 'Privado: activo' : 'Modo privado'),
        ),
      ),
    );
  }
}

class _PintorLogo extends CustomPainter {
  const _PintorLogo(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas
      ..drawCircle(
        c,
        r * 12 / 14,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      )
      ..drawCircle(c, r * 5 / 14, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PintorLogo oldDelegate) => oldDelegate.color != color;
}

// --- Paneles -----------------------------------------------------------------

class _PanelHoy extends ConsumerWidget implements _Panel {
  const _PanelHoy();

  @override
  bool visible(ResumenGravity resumen) =>
      resumen.agenda.isNotEmpty || resumen.habitos.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final r = ref.watch(resumenGravityProvider);
    final e = v.espacio;
    return TarjetaModulo(
      key: const ValueKey('panel-hoy'),
      titulo: 'Hoy · agenda',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final evento in r.agenda)
            Padding(
              padding: EdgeInsets.only(bottom: e * 1.5),
              child: _FilaHora(hora: evento.hora, texto: evento.titulo),
            ),
          if (r.habitos.isNotEmpty) ...[
            Divider(height: e * 2),
            SizedBox(height: e),
            const EtiquetaPanel('Hábitos'),
            SizedBox(height: e),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${r.habitosHechos}/${r.habitosTotal}',
                  style: v.titulo(tamano: 34, peso: FontWeight.w500),
                ),
                SizedBox(width: e * 1.25),
                Flexible(
                  child: Text(
                    'cumplidos hoy',
                    style: v.lectura(color: v.textoTenue),
                  ),
                ),
              ],
            ),
            SizedBox(height: e * 1.5),
            BarraProgreso(
              valor: r.habitosTotal == 0 ? 0 : r.habitosHechos / r.habitosTotal,
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelCuidados extends ConsumerWidget implements _Panel {
  const _PanelCuidados();

  @override
  bool visible(ResumenGravity resumen) => resumen.cuidados != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final c = ref.watch(resumenGravityProvider).cuidados!;
    final privado = ref.watch(modoPrivadoProvider);
    final e = v.espacio;
    return TarjetaModulo(
      key: const ValueKey('panel-cuidados'),
      titulo: 'Cuidados · turno',
      child: privado
          ? const _TextoOcultoPorPrivacidad('Datos de cuidados ocultos')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c.turno,
                  style: v.lectura(tamano: 17, color: v.textoFuerte),
                ),
                for (final p in c.pendientes) ...[
                  SizedBox(height: e * 1.5),
                  _FilaEstado(
                    texto: p.texto,
                    estado: p.estado,
                    atencion: p.atencion,
                  ),
                ],
              ],
            ),
    );
  }
}

class _PanelFinanzas extends ConsumerWidget implements _Panel {
  const _PanelFinanzas();

  @override
  bool visible(ResumenGravity resumen) => resumen.finanzas != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final f = ref.watch(resumenGravityProvider).finanzas!;
    final ahora = ref.watch(horaActualProvider);
    final privado = ref.watch(modoPrivadoProvider);
    final ocultos = ref.watch(montosOcultosProvider);
    final e = v.espacio;
    return TarjetaModulo(
      key: const ValueKey('panel-finanzas'),
      titulo: 'Finanzas · semana ${semanaIso(ahora)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semaforo(estado: f.estado),
          ),
          SizedBox(height: e * 1.5),
          Text('Quedan', style: v.lectura(tamano: 14, color: v.textoTenue)),
          Row(
            children: [
              Expanded(
                child: MontoOcultable(
                  key: const ValueKey('monto-quedan'),
                  centavos: f.quedanCentavos,
                  oculto: ocultos,
                  estilo: v.numero(
                    tamano: 28,
                    peso: FontWeight.w500,
                    color: v.textoFuerte,
                  ),
                ),
              ),
              if (!privado) ...[
                SizedBox(width: e),
                OutlinedButton(
                  key: const ValueKey('boton-mostrar-montos'),
                  onPressed: () =>
                      ref.read(montosVisiblesProvider.notifier).alternar(),
                  child: Text(ocultos ? 'Mostrar' : 'Ocultar'),
                ),
              ],
            ],
          ),
          SizedBox(height: e * 1.5),
          BarraProgreso(
            etiqueta: 'Presupuesto usado',
            valor: f.usado,
            color: f.estado.color(v),
          ),
        ],
      ),
    );
  }
}

class _PanelAvisos extends ConsumerWidget implements _Panel {
  const _PanelAvisos();

  @override
  bool visible(ResumenGravity resumen) => resumen.avisos.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final avisos = ref.watch(resumenGravityProvider).avisos;
    final e = v.espacio;
    return TarjetaModulo(
      key: const ValueKey('panel-avisos'),
      titulo: 'Avisos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < avisos.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : e * 1.5),
              child: _FilaHora(
                hora: avisos[i].cuando,
                texto: avisos[i].texto,
                color: switch (avisos[i].tipo) {
                  TipoAviso.informacion => v.acento,
                  TipoAviso.atencion => v.alerta,
                  TipoAviso.hecho => v.exito,
                },
                anchoHora: 84,
              ),
            ),
        ],
      ),
    );
  }
}

class _PanelNucleo extends ConsumerWidget {
  const _PanelNucleo({this.compacto = false});

  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final ahora = ref.watch(horaActualProvider);
    final resumen = ref.watch(resumenGravityProvider);
    final privado = ref.watch(modoPrivadoProvider);
    final estado = ref.watch(estadoNucleoProvider);
    final e = v.espacio;
    final mensaje = mensajeDelNucleo(ahora, resumen, privado: privado);
    final superficie = Color.lerp(v.fondo, v.panel, 0.4)!;

    Widget contenido(double tamanoNucleo) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        NucleoGravity(tamano: tamanoNucleo, estado: estado),
        SizedBox(height: e * 2.25),
        Text(
          estado.etiqueta.toUpperCase(),
          key: const ValueKey('estado-nucleo'),
          // Texto de 13 px sobre la superficie del núcleo: el acento se
          // ajusta para llegar a 4.5:1 (de día, el acento puro da 4.37:1).
          style: v
              .etiquetaPanel(
                tamano: 13,
                color: v.acentoParaTextoSobre(superficie),
              )
              .copyWith(letterSpacing: 13 * 0.3),
        ),
        SizedBox(height: e * 2.25),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Semantics(
            liveRegion: true,
            child: Text(
              mensaje,
              key: const ValueKey('mensaje-nucleo'),
              textAlign: TextAlign.center,
              style: v.lectura(
                tamano: compacto ? 18 : 22,
                color: v.textoFuerte,
              ),
            ),
          ),
        ),
      ],
    );

    return DecoratedBox(
      key: const ValueKey('panel-nucleo'),
      decoration: BoxDecoration(
        color: superficie,
        border: Border.all(color: v.borde),
        borderRadius: BorderRadius.circular(v.radioMediano),
      ),
      child: Padding(
        padding: EdgeInsets.all(e * 3),
        child: compacto
            ? contenido(200)
            : LayoutBuilder(
                builder: (context, limites) {
                  final tamano = (limites.maxHeight - 220)
                      .clamp(120.0, 300.0)
                      .clamp(0.0, limites.maxWidth)
                      .toDouble();
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: limites.maxHeight,
                        minWidth: limites.maxWidth,
                      ),
                      child: contenido(tamano),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// --- Piezas ------------------------------------------------------------------

/// "20:00   Inglés · lección del día"
class _FilaHora extends StatelessWidget {
  const _FilaHora({
    required this.hora,
    required this.texto,
    this.color,
    this.anchoHora = 52,
  });

  final String hora;
  final String texto;
  final Color? color;
  final double anchoHora;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: anchoHora),
          child: Text(
            hora,
            style: v.numero(tamano: 14, color: color ?? v.acento),
          ),
        ),
        SizedBox(width: v.espacio * 1.75),
        Expanded(child: Text(texto, style: v.lectura())),
      ],
    );
  }
}

/// "Medicamento 20:00          PENDIENTE"
class _FilaEstado extends StatelessWidget {
  const _FilaEstado({
    required this.texto,
    required this.estado,
    this.atencion = false,
  });

  final String texto;
  final String estado;
  final bool atencion;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Row(
      children: [
        Expanded(child: Text(texto, style: v.lectura())),
        SizedBox(width: v.espacio * 1.5),
        Text(
          estado.toUpperCase(),
          style: v.numero(
            tamano: 13,
            color: atencion ? v.alerta : v.textoTenue,
          ),
        ),
      ],
    );
  }
}

class _TextoOcultoPorPrivacidad extends StatelessWidget {
  const _TextoOcultoPorPrivacidad(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Row(
      children: [
        Icon(Icons.visibility_off_outlined, size: 18, color: v.textoTenue),
        SizedBox(width: v.espacio),
        Expanded(
          child: Text(
            '$texto (modo privado)',
            style: v.lectura(tamano: 14, color: v.textoTenue),
          ),
        ),
      ],
    );
  }
}

// --- Barras ------------------------------------------------------------------

/// Barra de órdenes de muestra (deshabilitada) mientras el asistente entrega la suya.
class _BarraOrdenesMuestra extends ConsumerWidget {
  const _BarraOrdenesMuestra();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final superficie = Color.lerp(v.fondo, v.panel, 0.6)!;
    final ejemplo = _ejemploDeOrden(ref.watch(modulosBarraProvider));
    return Semantics(
      key: const ValueKey('barra-ordenes-muestra'),
      label: 'Barra de órdenes (muestra, no disponible)',
      enabled: false,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, limites) {
          final conAtajo = limites.maxWidth >= 560;
          return Container(
            padding: EdgeInsets.fromLTRB(e * 2.25, e, e, e),
            decoration: BoxDecoration(
              color: superficie,
              border: Border.all(color: v.acento),
              borderRadius: BorderRadius.circular(v.radioMediano),
            ),
            child: Row(
              children: [
                Text(
                  '>',
                  style: v.numero(
                    tamano: 18,
                    color: v.acentoParaTextoSobre(superficie),
                  ),
                ),
                SizedBox(width: e * 1.5),
                Expanded(
                  child: Text(
                    'Escribe o habla a GRAVITY…$ejemplo',
                    style: v.lectura(tamano: 16, color: v.textoTenue),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (conAtajo) ...[
                  SizedBox(width: e * 1.5),
                  Text(
                    'Ctrl + Espacio',
                    style: v.numero(tamano: 12, color: v.textoTenue),
                  ),
                ],
                SizedBox(width: e * 1.5),
                Container(
                  width: zonaTactilMinima,
                  height: zonaTactilMinima,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(v.panel, v.acento, 0.12),
                    border: Border.all(color: v.acento),
                  ),
                  child: Icon(Icons.mic_none, size: 20, color: v.acento),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Ejemplo de orden con un destino que el rol sí ve (nunca "presupuesto" a
/// quien no abre Finanzas).
String _ejemploDeOrden(List<Modulo> modulos) {
  if (modulos.contains(Modulo.finanzas)) return '   ej.: abre presupuesto';
  final destino = modulos.where((m) => m != Modulo.ajustes).firstOrNull;
  return destino == null
      ? ''
      : '   ej.: abre ${nombreModulo(destino).toLowerCase()}';
}

class _BarraModulos extends ConsumerWidget {
  const _BarraModulos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final modulos = ref.watch(modulosBarraProvider);
    return Semantics(
      container: true,
      label: 'Módulos',
      child: Wrap(
        spacing: v.espacio,
        runSpacing: v.espacio,
        children: [
          for (final m in modulos)
            OutlinedButton(
              key: ValueKey('modulo-${m.name}'),
              onPressed: () => GoRouter.maybeOf(context)?.go(rutaModulo(m)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: v.espacio * 2.25),
                textStyle: v.etiquetaPanel(tamano: 13),
              ),
              child: Text(
                nombreModulo(m).toUpperCase(),
                style: v.etiquetaPanel(tamano: 13, color: v.texto),
              ),
            ),
        ],
      ),
    );
  }
}
