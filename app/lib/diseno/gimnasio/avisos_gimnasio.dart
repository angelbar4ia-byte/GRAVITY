/// Avisos de «Mi gimnasio»: «Contenido en revisión» (PG-25) y las molestias
/// (5.10 y 4.3).
///
/// **Sin diagnosticar.** Estos componentes nunca dicen qué es una molestia, ni
/// cómo se llama, ni cómo tratarla: solo ajustan el ejercicio y mandan a un
/// profesional, un médico o un entrenador (CA-G-03). Las molestias están solo
/// en el dispositivo y la pantalla lo dice.
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../tema.dart';
import '../valores_diseno.dart';
import 'piezas_gimnasio.dart';
import 'textos_gimnasio.dart';
import 'tipos_gimnasio.dart';

/// La tarjeta **«Contenido en revisión»**: mientras haya ejercicios, variantes
/// o plantillas en `borrador`, la sesión lo dice (PG-25, CA-G-05). Compacta es
/// una sola línea; completa agrega la frase de «guía general».
class TarjetaContenidoEnRevision extends StatelessWidget {
  const TarjetaContenidoEnRevision({
    super.key,
    this.compacta = false,
    this.texto = TextosGimnasio.contenidoEnRevision,
    this.detalle = TextosGimnasio.contenidoEnRevisionDetalle,
    this.alAbrir,
    this.estado = EstadoVistaGimnasio.listo,
    this.mensajes = const MensajesEstadoGimnasio(
      vacio: 'Todo el contenido está revisado.',
      cargando: 'Revisando el estado del contenido…',
      sinConexion: 'Sin conexión. El contenido viene con la app.',
      error: 'No se pudo leer el estado de la revisión del contenido.',
    ),
    this.alReintentar,
  });

  final bool compacta;
  final String texto;

  /// La frase de «guía general que no sustituye a un profesional».
  final String detalle;

  /// Abre *Sobre esta guía*; con él la tarjeta se toca (48 dp o más).
  final VoidCallback? alAbrir;

  /// `listo`: hay contenido en revisión. `vacio`: todo revisado (no se dibuja
  /// nada visible más que el mensaje). Los demás, sus mensajes.
  final EstadoVistaGimnasio estado;
  final MensajesEstadoGimnasio mensajes;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaGimnasio.listo) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: v.borde, width: v.grosorBorde),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: e * 1.5),
          child: CuerpoEstadoGimnasio(
            estado: estado,
            mensajes: mensajes,
            alReintentar: alReintentar,
          ),
        ),
      );
    }
    final cuerpo = Padding(
      padding: EdgeInsets.symmetric(horizontal: e * 1.5, vertical: e * 1.25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.rule_folder_outlined, size: 22, color: v.alerta),
          SizedBox(width: e * 1.25),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texto,
                  style: v.lectura(
                    tamano: 15,
                    peso: FontWeight.w700,
                    color: v.textoFuerte,
                  ),
                ),
                if (!compacta) ...[
                  SizedBox(height: e * 0.5),
                  Text(detalle, style: v.lectura(tamano: 14, color: v.texto)),
                ],
              ],
            ),
          ),
          if (alAbrir != null) ...[
            SizedBox(width: e),
            Padding(
              padding: EdgeInsets.only(top: e * 0.25),
              child: Icon(Icons.chevron_right, size: 22, color: v.textoTenue),
            ),
          ],
        ],
      ),
    );
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(v.radioMediano),
      side: BorderSide(color: v.alerta, width: v.grosorBorde),
    );
    return Semantics(
      container: true,
      button: alAbrir != null,
      onTap: alAbrir,
      label: compacta ? texto : '$texto. $detalle',
      hint: alAbrir == null ? null : TextosGimnasio.sobreEstaGuia,
      excludeSemantics: true,
      child: Material(
        color: Color.alphaBlend(v.alerta.withValues(alpha: 0.08), v.panel),
        shape: forma,
        clipBehavior: Clip.antiAlias,
        child: alAbrir == null
            ? ConstrainedBox(
                constraints: const BoxConstraints(minHeight: zonaTactilMinima),
                child: cuerpo,
              )
            : InkWell(
                onTap: alAbrir,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: zonaTactilMinima,
                  ),
                  child: cuerpo,
                ),
              ),
      ),
    );
  }
}

/// El aviso de una **molestia** registrada, sin diagnosticar.
///
/// El texto cambia según la intensidad (5.10): leve, moderada o fuerte; en
/// los tres lleva la frase de que no sustituye a un profesional y, en la
/// fuerte, manda a un médico o a un entrenador. Muestra la zona que la persona
/// eligió (del catálogo) y que **solo se guarda en este equipo**.
class AvisoMolestia extends StatelessWidget {
  const AvisoMolestia({
    super.key,
    required this.zonaTexto,
    required this.nivel,
    this.mensajeCatalogo,
    this.alSigue,
    this.alYaNo,
    this.alProponerRegenerativa,
    this.estado = EstadoVistaGimnasio.listo,
    this.mensajes = const MensajesEstadoGimnasio(
      vacio: 'No hay molestias registradas en este equipo.',
      vacioDetalle: 'Si algo te molesta, avísanos y ajustamos el ejercicio.',
      textoAccionVacia: 'Agregar una molestia',
      cargando: 'Leyendo lo guardado en este equipo…',
      sinConexion: 'Sin conexión. Las molestias nunca salen de este equipo.',
      error: 'No se pudieron leer las molestias de este equipo.',
    ),
    this.alReintentar,
    this.alAccionVacia,
  });

  /// La zona del catálogo («Hombro»).
  final String zonaTexto;
  final NivelMolestia nivel;

  /// Un mensaje más del catálogo de mensajes del dominio; se muestra **antes**
  /// de la frase fija. Quien lo arma cuida que mencione a un profesional.
  final String? mensajeCatalogo;

  /// «Sigue» (cada 14 días se pregunta). Con alSigue y alYaNo aparece la
  /// pregunta con sus dos botones de 48 dp.
  final VoidCallback? alSigue;
  final VoidCallback? alYaNo;

  /// Con intensidad fuerte, propone la regenerativa.
  final VoidCallback? alProponerRegenerativa;
  final EstadoVistaGimnasio estado;
  final MensajesEstadoGimnasio mensajes;
  final VoidCallback? alReintentar;
  final VoidCallback? alAccionVacia;

  /// El texto fijo que corresponde a la intensidad.
  String get textoNivel => switch (nivel) {
    NivelMolestia.leve => TextosGimnasio.molestiaLeve,
    NivelMolestia.moderada => TextosGimnasio.molestiaModerada,
    NivelMolestia.fuerte => TextosGimnasio.molestiaFuerte,
  };

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaGimnasio.listo) {
      return TarjetaModulo(
        titulo: 'Molestias',
        icono: Icons.healing_outlined,
        child: CuerpoEstadoGimnasio(
          estado: estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
          alAccionVacia: alAccionVacia,
        ),
      );
    }
    final fuerte = nivel == NivelMolestia.fuerte;
    final color = fuerte ? v.alerta : v.acento;
    final pregunta = alSigue != null && alYaNo != null;
    return TarjetaModulo(
      titulo: 'Molestia · $zonaTexto',
      icono: Icons.healing_outlined,
      accion: MarcaGimnasio(
        texto: nivel.texto,
        icono: nivel.icono,
        color: color,
        enfasis: fuerte,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mensajeCatalogo != null) ...[
            Text(
              mensajeCatalogo!,
              style: v.lectura(
                tamano: 15,
                peso: FontWeight.w600,
                color: v.textoFuerte,
              ),
            ),
            SizedBox(height: e),
          ],
          Semantics(
            liveRegion: fuerte,
            child: Text(
              textoNivel,
              style: v.lectura(
                tamano: 15,
                peso: fuerte ? FontWeight.w600 : FontWeight.w400,
                color: fuerte ? v.textoFuerte : v.texto,
              ),
            ),
          ),
          if (fuerte) ...[
            SizedBox(height: e),
            Text(
              TextosGimnasio.molestiaProponerRegenerativa,
              style: v.lectura(tamano: 15, color: v.texto),
            ),
            if (alProponerRegenerativa != null) ...[
              SizedBox(height: e * 1.5),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: alProponerRegenerativa,
                  icon: const Icon(Icons.self_improvement, size: 18),
                  label: const Text('Ver la sesión regenerativa'),
                ),
              ),
            ],
          ],
          SizedBox(height: e * 1.5),
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.lock_outline, size: 16, color: v.textoTenue),
              ),
              SizedBox(width: e * 0.75),
              Expanded(
                child: Text(
                  TextosGimnasio.molestiaSoloEnEsteEquipo,
                  style: v.lectura(tamano: 13, color: v.textoTenue),
                ),
              ),
            ],
          ),
          if (pregunta) ...[
            SizedBox(height: e * 1.5),
            Text(
              TextosGimnasio.molestiaPreguntaSigue,
              style: v.lectura(
                tamano: 15,
                peso: FontWeight.w600,
                color: v.textoFuerte,
              ),
            ),
            SizedBox(height: e),
            Wrap(
              spacing: e,
              runSpacing: e,
              children: [
                OutlinedButton(
                  onPressed: alSigue,
                  child: const Text(TextosGimnasio.molestiaSigue),
                ),
                OutlinedButton(
                  onPressed: alYaNo,
                  child: const Text(TextosGimnasio.molestiaYaNo),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Una molestia en la lista de E9. Dice la zona y la intensidad con icono y
/// palabra, y desde cuándo; la nota es solo local y no se muestra aquí.
class FilaMolestia extends StatelessWidget {
  const FilaMolestia({
    super.key,
    required this.zonaTexto,
    required this.nivel,
    this.desdeTexto,
    this.activa = true,
    this.alTocar,
  });

  final String zonaTexto;
  final NivelMolestia nivel;

  /// «desde el 2 nov».
  final String? desdeTexto;
  final bool activa;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final contenido = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: e * 1.5, vertical: e),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zonaTexto,
                    style: v.lectura(
                      tamano: 15,
                      peso: FontWeight.w700,
                      color: v.textoFuerte,
                    ),
                  ),
                  Text(
                    [
                      if (activa) 'Activa' else 'Ya no',
                      ?desdeTexto,
                    ].join(' · '),
                    style: v.lectura(tamano: 13.5, color: v.textoTenue),
                  ),
                ],
              ),
            ),
            SizedBox(width: e),
            MarcaGimnasio(texto: nivel.texto, icono: nivel.icono),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      button: alTocar != null,
      onTap: alTocar,
      label:
          '$zonaTexto, ${nivel.texto.toLowerCase()}, '
          '${activa ? 'activa' : 'ya no'}${desdeTexto == null ? '' : ', $desdeTexto'}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: v.panel,
          border: Border.all(color: v.borde, width: v.grosorBorde),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: alTocar == null
            ? contenido
            : InkWell(
                onTap: alTocar,
                borderRadius: BorderRadius.circular(v.radioMediano),
                child: contenido,
              ),
      ),
    );
  }
}
