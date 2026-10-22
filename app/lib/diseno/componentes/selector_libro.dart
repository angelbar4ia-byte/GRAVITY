import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../superficies.dart';
import '../tema.dart';
import '../valores_diseno.dart';

/// Tipo de libro de Finanzas (D19; `fin_libros.tipo` en la especificación de
/// la Fase 1, sección 4.5). Mismo orden y nombres que el del dominio.
enum TipoLibro {
  /// El de una persona adulta con Finanzas.
  personal,

  /// "Gastos de la casa": dos o más miembros adultos.
  compartido,

  /// El de una persona bajo cuidado (sin cuenta), que llevan sus albaceas.
  representado;

  /// Icono de línea del tipo: el tipo nunca depende solo del color.
  IconData get icono => switch (this) {
    TipoLibro.personal => Icons.person_outline,
    TipoLibro.compartido => Icons.group_outlined,
    TipoLibro.representado => Icons.volunteer_activism_outlined,
  };
}

/// Cómo ve la persona actual un libro.
enum AccesoLibro {
  /// Su libro personal: se muestra como "Mi libro".
  titular,

  /// Miembro de un libro compartido.
  miembro,

  /// Albacea o suplente de un libro representado: registra **en nombre de**
  /// su titular, con motivo y bitácora.
  albacea,

  /// Cuenta maestra en un libro ajeno: **solo lee**.
  soloLectura,
}

/// Un libro que se puede elegir en [SelectorLibro].
@immutable
class OpcionLibro {
  const OpcionLibro({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.acceso = AccesoLibro.titular,
  });

  /// `fin_libros.id` (UUID).
  final String id;

  /// "Gastos de la casa", "Papá (ejemplo)", "Libro de Ana".
  final String nombre;

  final TipoLibro tipo;
  final AccesoLibro acceso;

  /// Lo que se ve: "Mi libro" en el personal propio; si no, [nombre].
  String get etiqueta =>
      tipo == TipoLibro.personal && acceso == AccesoLibro.titular
      ? 'Mi libro'
      : nombre;

  /// La cuenta maestra solo lee este libro.
  bool get soloLectura => acceso == AccesoLibro.soloLectura;

  /// Se registra en nombre de su titular (albacea de un representado).
  bool get enNombreDe =>
      tipo == TipoLibro.representado && acceso == AccesoLibro.albacea;

  /// Marca corta que acompaña a la etiqueta en el selector; `null` si no hay.
  String? get marca => soloLectura
      ? 'Solo lectura'
      : enNombreDe
      ? 'Albacea'
      : null;

  /// Lo que dice el lector de pantalla del libro.
  String get descripcion {
    final partes = <String>[
      'Libro: $etiqueta',
      if (tipo == TipoLibro.compartido) 'compartido',
      if (enNombreDe) 'en nombre de $nombre',
      if (soloLectura) 'solo lectura',
    ];
    return partes.join(', ');
  }

  @override
  bool operator ==(Object other) =>
      other is OpcionLibro &&
      other.id == id &&
      other.nombre == nombre &&
      other.tipo == tipo &&
      other.acceso == acceso;

  @override
  int get hashCode => Object.hash(id, nombre, tipo, acceso);

  @override
  String toString() => 'OpcionLibro($id, $etiqueta)';
}

/// Elige el libro de Finanzas con el que se trabaja (D19): "Mi libro", los
/// compartidos, el de la persona representada (albacea) y, para la cuenta
/// maestra, los ajenos en solo lectura.
///
/// Con [comoMenu] en `null` decide solo: **chips** si son 4 o menos y caben
/// (360 dp o más), **menú** si no. Cada opción lleva el icono de su tipo y su
/// marca ("Solo lectura", "Albacea"); la elegida lleva además una palomita.
/// [alCambiar] recibe el id solo cuando el libro cambia.
///
/// La marca grande del libro activo va aparte, en [MarcaLibro].
class SelectorLibro extends StatelessWidget {
  const SelectorLibro({
    super.key,
    required this.libros,
    required this.libroActualId,
    required this.alCambiar,
    this.comoMenu,
  });

  final List<OpcionLibro> libros;
  final String libroActualId;
  final ValueChanged<String> alCambiar;
  final bool? comoMenu;

  /// Máximo de libros que se muestran como chips en modo automático.
  static const maxChips = 4;

  /// Ancho mínimo para los chips en modo automático.
  static const anchoMinimoChips = 360.0;

  OpcionLibro? get _actual {
    for (final libro in libros) {
      if (libro.id == libroActualId) return libro;
    }
    return null;
  }

  void _elegir(String id) {
    if (id != libroActualId) alCambiar(id);
  }

  @override
  Widget build(BuildContext context) {
    if (libros.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: 'Libro de Finanzas',
      child: LayoutBuilder(
        builder: (context, limites) {
          final menu =
              comoMenu ??
              (libros.length > maxChips || limites.maxWidth < anchoMinimoChips);
          return menu ? _comoMenu(context) : _comoChips(context);
        },
      ),
    );
  }

  Widget _comoChips(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Wrap(
      spacing: v.espacio,
      runSpacing: v.espacio,
      children: [
        for (final libro in libros)
          _ChipLibro(
            libro: libro,
            seleccionado: libro.id == libroActualId,
            alTocar: () => _elegir(libro.id),
          ),
      ],
    );
  }

  Widget _comoMenu(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final actual = _actual;
    return MenuAnchor(
      menuChildren: [
        for (final libro in libros)
          Semantics(
            selected: libro.id == libroActualId,
            inMutuallyExclusiveGroup: true,
            child: MenuItemButton(
              onPressed: () => _elegir(libro.id),
              leadingIcon: Icon(libro.tipo.icono, size: 20),
              trailingIcon: libro.id == libroActualId
                  ? Icon(Icons.check, size: 18, color: v.textoFuerte)
                  : null,
              style: MenuItemButton.styleFrom(
                minimumSize: const Size(0, zonaTactilMinima),
              ),
              child: _TextoLibro(libro: libro),
            ),
          ),
      ],
      builder: (context, controlador, _) => _BotonMenu(
        libro: actual,
        alTocar: () =>
            controlador.isOpen ? controlador.close() : controlador.open(),
      ),
    );
  }
}

/// Etiqueta + marca corta, en una línea.
///
/// Las dos partes son flexibles y se recortan con puntos suspensivos: con un
/// nombre largo, letra grande o una fuente ancha nada desborda. El espacio se
/// reparte **en proporción al ancho natural de cada parte** (y no por mitades),
/// de modo que, si el nombre y la marca caben juntos, ninguno se recorta de
/// más; el nombre pesa como mucho [_veces] veces la marca, para que ésta
/// conserve siempre un tramo legible. El texto completo de la marca está en su
/// tooltip y en la semántica del libro ([OpcionLibro.descripcion]).
class _TextoLibro extends StatelessWidget {
  const _TextoLibro({required this.libro, this.fuerte = false});

  final OpcionLibro libro;
  final bool fuerte;

  /// Lo más que puede pesar el nombre frente a la marca en el reparto.
  static const _veces = 3;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final marca = libro.marca;
    final estilo = v.lectura(
      tamano: 14,
      peso: fuerte ? FontWeight.w600 : FontWeight.w500,
      color: v.textoFuerte,
    );
    var pesoEtiqueta = 1;
    var pesoMarca = 1;
    if (marca != null) {
      final anchoMarca = _Marquita.anchoNatural(context, marca);
      final anchoEtiqueta = _anchoTexto(context, libro.etiqueta, estilo);
      pesoMarca = math.max(1, anchoMarca.ceil());
      pesoEtiqueta = math.max(
        1,
        math.min(anchoEtiqueta, anchoMarca * _veces).ceil(),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          flex: pesoEtiqueta,
          child: Text(
            libro.etiqueta,
            style: estilo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (marca != null) ...[
          SizedBox(width: v.espacio),
          Flexible(
            flex: pesoMarca,
            child: _Marquita(texto: marca, soloLectura: libro.soloLectura),
          ),
        ],
      ],
    );
  }
}

/// Ancho que ocupa [texto] en una línea, con la escala de letra de [context].
double _anchoTexto(BuildContext context, String texto, TextStyle estilo) {
  final medidor = TextPainter(
    text: TextSpan(text: texto, style: estilo),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final ancho = medidor.width;
  medidor.dispose();
  return ancho;
}

/// La marca corta del chip: icono + texto, con borde.
///
/// Se recorta con puntos suspensivos si no cabe; su tooltip trae el texto
/// completo (no repite la semántica: el texto ya la lleva completa).
class _Marquita extends StatelessWidget {
  const _Marquita({required this.texto, required this.soloLectura});

  final String texto;
  final bool soloLectura;

  static const _tamanoIcono = 13.0;
  static const _separacion = 3.0;
  static const _grosorBorde = 1.0;

  static TextStyle _estilo(ValoresDiseno v) =>
      v.lectura(tamano: 12, peso: FontWeight.w500, color: v.textoTenue);

  static double _relleno(ValoresDiseno v) => v.espacio * 0.75;

  /// Ancho de la marca con todo su texto: icono, separación, relleno y borde.
  static double anchoNatural(BuildContext context, String texto) {
    final v = ValoresDiseno.de(context);
    return _anchoTexto(context, texto, _estilo(v)) +
        _tamanoIcono +
        _separacion +
        2 * _relleno(v) +
        2 * _grosorBorde;
  }

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Tooltip(
      message: texto,
      excludeFromSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: v.borde, width: _grosorBorde),
          borderRadius: BorderRadius.circular(v.radioChico),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _relleno(v), vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                soloLectura ? Icons.lock_outline : Icons.draw_outlined,
                size: _tamanoIcono,
                color: v.textoTenue,
              ),
              const SizedBox(width: _separacion),
              Flexible(
                child: Text(
                  texto,
                  style: _estilo(v),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipLibro extends StatelessWidget {
  const _ChipLibro({
    required this.libro,
    required this.seleccionado,
    required this.alTocar,
  });

  final OpcionLibro libro;
  final bool seleccionado;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(v.radioGrande * 2),
      side: BorderSide(
        color: seleccionado ? v.acento : v.borde,
        width: seleccionado ? 1.5 : 1,
      ),
    );
    return Semantics(
      container: true,
      button: true,
      selected: seleccionado,
      inMutuallyExclusiveGroup: true,
      label: libro.descripcion,
      excludeSemantics: true,
      onTap: alTocar,
      child: Material(
        color: seleccionado ? v.chipSeleccionado : v.panel,
        shape: forma,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          customBorder: forma,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: zonaTactilMinima,
              minWidth: zonaTactilMinima,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: e * 1.75),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    seleccionado ? Icons.check : libro.tipo.icono,
                    size: 18,
                    color: v.textoFuerte,
                  ),
                  SizedBox(width: e),
                  Flexible(
                    child: _TextoLibro(libro: libro, fuerte: seleccionado),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonMenu extends StatelessWidget {
  const _BotonMenu({required this.libro, required this.alTocar});

  final OpcionLibro? libro;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final libro = this.libro;
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(v.radioChico),
      side: BorderSide(color: v.borde),
    );
    return Semantics(
      container: true,
      button: true,
      label: libro?.descripcion ?? 'Elegir libro',
      hint: 'Toca para cambiar de libro',
      excludeSemantics: true,
      onTap: alTocar,
      child: Material(
        color: v.panel,
        shape: forma,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          customBorder: forma,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: zonaTactilMinima),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: e * 1.5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (libro != null) ...[
                    Icon(libro.tipo.icono, size: 18, color: v.textoFuerte),
                    SizedBox(width: e),
                    Flexible(child: _TextoLibro(libro: libro, fuerte: true)),
                  ] else
                    Text(
                      'Elegir libro',
                      style: v.lectura(tamano: 14, color: v.textoFuerte),
                    ),
                  SizedBox(width: e * 0.5),
                  Icon(Icons.arrow_drop_down, color: v.textoFuerte),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marca visible del libro activo, para el encabezado de la pantalla junto a
/// la acción principal (D19):
///
/// - Cuenta maestra: **"Solo lectura** · cuenta maestra: puedes ver, no
///   registrar".
/// - Albacea: **"En nombre de Papá** · cada movimiento pide motivo y queda en
///   la bitácora".
///
/// En el libro propio o en uno compartido no dibuja nada.
class MarcaLibro extends StatelessWidget {
  const MarcaLibro({super.key, required this.libro});

  final OpcionLibro libro;

  /// Título de la marca; `null` si el libro no lleva.
  String? get titulo => libro.soloLectura
      ? 'Solo lectura'
      : libro.enNombreDe
      ? 'En nombre de ${libro.nombre}'
      : null;

  /// Detalle de la marca; `null` si el libro no lleva.
  String? get detalle => libro.soloLectura
      ? 'cuenta maestra: puedes ver, no registrar'
      : libro.enNombreDe
      ? 'cada movimiento pide motivo y queda en la bitácora'
      : null;

  @override
  Widget build(BuildContext context) {
    final titulo = this.titulo;
    if (titulo == null) return const SizedBox.shrink();
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final fondo = v.chipSeleccionado;
    return Semantics(
      container: true,
      label: '$titulo, $detalle',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fondo,
          border: Border.all(color: v.acento),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: e * 1.5, vertical: e),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                libro.soloLectura ? Icons.lock_outline : Icons.draw_outlined,
                size: 18,
                color: v.acentoParaTextoSobre(fondo),
              ),
              SizedBox(width: e),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: titulo,
                    style: v.lectura(
                      tamano: 14,
                      peso: FontWeight.w600,
                      color: v.textoFuerte,
                    ),
                    children: [
                      TextSpan(
                        text: ' · $detalle',
                        style: v.lectura(tamano: 13, color: v.texto),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
