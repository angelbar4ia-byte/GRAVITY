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

  /// Adulto con Finanzas del hogar que **lee** un libro compartido **público**
  /// sin ser miembro: solo lee (D19, respuestas del 23/oct).
  lector,
}

/// Quién más ve un libro compartido (D19, respuestas del dueño del 23/oct).
enum VisibilidadLibro {
  /// Por omisión: la ven y escriben sus miembros; la lee también la cuenta
  /// maestra.
  privada('Privada', Icons.lock_person_outlined),

  /// Además la **leen** (no escriben) los adultos con Finanzas del hogar.
  publica('Pública', Icons.public);

  const VisibilidadLibro(this.etiqueta, this.icono);

  /// Texto de la marca: la visibilidad nunca depende solo del icono.
  final String etiqueta;
  final IconData icono;

  /// Lo que explica el tooltip de la marca.
  String get explicacion => switch (this) {
    VisibilidadLibro.privada =>
      'Privada: la ven y escriben sus miembros; la lee también la cuenta '
          'maestra',
    VisibilidadLibro.publica =>
      'Pública: además la leen, sin escribir, los adultos con Finanzas del '
          'hogar',
  };
}

/// Una marca corta de un libro en el selector: texto (siempre), icono y el
/// texto del tooltip.
@immutable
class MarcaDeOpcion {
  const MarcaDeOpcion(this.texto, this.icono, {String? explicacion})
    : explicacion = explicacion ?? texto;

  final String texto;
  final IconData icono;
  final String explicacion;

  @override
  bool operator ==(Object other) =>
      other is MarcaDeOpcion &&
      other.texto == texto &&
      other.icono == icono &&
      other.explicacion == explicacion;

  @override
  int get hashCode => Object.hash(texto, icono, explicacion);
}

/// Un libro que se puede elegir en [SelectorLibro].
@immutable
class OpcionLibro {
  const OpcionLibro({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.acceso = AccesoLibro.titular,
    this.visibilidad = VisibilidadLibro.privada,
    this.archivado = false,
  });

  /// `fin_libros.id` (UUID).
  final String id;

  /// "Gastos de la casa", "Papá (ejemplo)", "Libro de Ana".
  final String nombre;

  final TipoLibro tipo;
  final AccesoLibro acceso;

  /// Solo cuenta en los libros compartidos (`fin_libros.visibilidad`): en los
  /// demás no se muestra.
  final VisibilidadLibro visibilidad;

  /// Libro archivado (por ejemplo, al salirse un miembro y quedar menos de 2):
  /// **solo lectura para todos**.
  final bool archivado;

  /// Lo que se ve: "Mi libro" en el personal propio; si no, [nombre].
  String get etiqueta =>
      tipo == TipoLibro.personal && acceso == AccesoLibro.titular
      ? 'Mi libro'
      : nombre;

  /// La persona solo lee este libro por su acceso: la cuenta maestra en uno
  /// ajeno o un adulto del hogar en uno compartido público.
  bool get soloLectura =>
      acceso == AccesoLibro.soloLectura || acceso == AccesoLibro.lector;

  /// Nadie puede registrar en este libro: la persona solo lee ([soloLectura])
  /// o el libro está [archivado].
  bool get sinEscritura => soloLectura || archivado;

  /// Se registra en nombre de su titular (albacea de un representado).
  bool get enNombreDe =>
      tipo == TipoLibro.representado && acceso == AccesoLibro.albacea;

  /// Marca corta de **estado** que acompaña a la etiqueta en el selector;
  /// `null` si no hay: "Archivado" (solo lectura para todos), "Solo lectura"
  /// (solo lee por su acceso) o "Albacea".
  String? get marca => archivado
      ? 'Archivado'
      : soloLectura
      ? 'Solo lectura'
      : enNombreDe
      ? 'Albacea'
      : null;

  /// Marca de **visibilidad** ("Pública" o "Privada"): solo los libros
  /// compartidos; `null` en los demás.
  String? get marcaVisibilidad =>
      tipo == TipoLibro.compartido ? visibilidad.etiqueta : null;

  /// Las marcas del selector, en orden: visibilidad y luego estado.
  List<MarcaDeOpcion> get marcas => [
    if (tipo == TipoLibro.compartido)
      MarcaDeOpcion(
        visibilidad.etiqueta,
        visibilidad.icono,
        explicacion: visibilidad.explicacion,
      ),
    if (archivado)
      const MarcaDeOpcion(
        'Archivado',
        Icons.archive_outlined,
        explicacion: 'Archivado: solo lectura, ya no se registra en este libro',
      )
    else if (soloLectura)
      const MarcaDeOpcion('Solo lectura', Icons.lock_outline)
    else if (enNombreDe)
      const MarcaDeOpcion('Albacea', Icons.draw_outlined),
  ];

  /// Lo que dice el lector de pantalla del libro.
  String get descripcion {
    final partes = <String>[
      'Libro: $etiqueta',
      if (tipo == TipoLibro.compartido) 'compartido',
      if (tipo == TipoLibro.compartido)
        visibilidad == VisibilidadLibro.publica ? 'público' : 'privado',
      if (enNombreDe) 'en nombre de $nombre',
      if (archivado) 'archivado',
      if (sinEscritura) 'solo lectura',
    ];
    return partes.join(', ');
  }

  @override
  bool operator ==(Object other) =>
      other is OpcionLibro &&
      other.id == id &&
      other.nombre == nombre &&
      other.tipo == tipo &&
      other.acceso == acceso &&
      other.visibilidad == visibilidad &&
      other.archivado == archivado;

  @override
  int get hashCode =>
      Object.hash(id, nombre, tipo, acceso, visibilidad, archivado);

  @override
  String toString() => 'OpcionLibro($id, $etiqueta)';
}

/// Elige el libro de Finanzas con el que se trabaja (D19): "Mi libro", los
/// compartidos, el de la persona representada (albacea) y, para la cuenta
/// maestra, los ajenos en solo lectura.
///
/// Con [comoMenu] en `null` decide solo: **chips** si son 4 o menos y caben
/// (360 dp o más), **menú** si no. Cada opción lleva el icono de su tipo y sus
/// marcas, siempre con texto además del icono: "Pública" o "Privada" en los
/// compartidos y, según el caso, "Archivado", "Solo lectura" o "Albacea"; la
/// elegida lleva además una palomita. [alCambiar] recibe el id solo cuando el
/// libro cambia.
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

/// Etiqueta + marcas cortas.
///
/// Van en una línea si caben. Si no, **las marcas bajan a la línea siguiente**
/// (un `Wrap`) en lugar de comprimirse: con un nombre largo, letra grande o una
/// fuente ancha nada desborda ni se corta, y solo un nombre o una marca más
/// ancho que todo el espacio se recorta con puntos suspensivos. El texto
/// completo de cada marca está en su tooltip y en la semántica del libro
/// ([OpcionLibro.descripcion]).
class _TextoLibro extends StatelessWidget {
  const _TextoLibro({required this.libro, this.fuerte = false});

  final OpcionLibro libro;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: v.espacio,
      runSpacing: 2,
      children: [
        Text(
          libro.etiqueta,
          style: v.lectura(
            tamano: 14,
            peso: fuerte ? FontWeight.w600 : FontWeight.w500,
            color: v.textoFuerte,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        for (final marca in libro.marcas) _Marquita(marca: marca),
      ],
    );
  }
}

/// Una marca corta del chip: icono + texto, con borde.
///
/// Se recorta con puntos suspensivos si no cabe ni en una línea propia; su
/// tooltip trae la explicación completa (no repite la semántica: el texto ya la
/// lleva).
class _Marquita extends StatelessWidget {
  const _Marquita({required this.marca});

  final MarcaDeOpcion marca;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Tooltip(
      message: marca.explicacion,
      excludeFromSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: v.borde, width: v.grosorBorde),
          borderRadius: BorderRadius.circular(v.radioChico),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: v.espacio * 0.75,
            vertical: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(marca.icono, size: 13, color: v.textoTenue),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  marca.texto,
                  style: v.lectura(
                    tamano: 12,
                    peso: FontWeight.w500,
                    color: v.textoTenue,
                  ),
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
      side: BorderSide(color: v.borde, width: v.grosorBorde),
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
/// - Libro archivado: **"Archivado** · solo lectura: ya no se puede registrar
///   en este libro".
/// - Adulto del hogar en un compartido público: **"Solo lectura** · libro
///   público: puedes ver, no registrar".
///
/// En el libro propio o en uno compartido (como miembro) no dibuja nada.
class MarcaLibro extends StatelessWidget {
  const MarcaLibro({super.key, required this.libro});

  final OpcionLibro libro;

  /// Título de la marca; `null` si el libro no lleva.
  String? get titulo => libro.archivado
      ? 'Archivado'
      : libro.soloLectura
      ? 'Solo lectura'
      : libro.enNombreDe
      ? 'En nombre de ${libro.nombre}'
      : null;

  /// Detalle de la marca; `null` si el libro no lleva.
  String? get detalle => libro.archivado
      ? 'solo lectura: ya no se puede registrar en este libro'
      : libro.acceso == AccesoLibro.lector
      ? 'libro público: puedes ver, no registrar'
      : libro.soloLectura
      ? 'cuenta maestra: puedes ver, no registrar'
      : libro.enNombreDe
      ? 'cada movimiento pide motivo y queda en la bitácora'
      : null;

  /// Icono de la marca: candado si solo se lee, archivo si está archivado.
  IconData get _icono => libro.archivado
      ? Icons.archive_outlined
      : libro.soloLectura
      ? Icons.lock_outline
      : Icons.draw_outlined;

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
              Icon(_icono, size: 18, color: v.acentoParaTextoSobre(fondo)),
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
