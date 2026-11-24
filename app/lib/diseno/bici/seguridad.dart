/// **Seguridad y contacto** (B8, 4.4): los textos fijos de seguridad, el
/// contacto de confianza y los dos botones de siempre: *Llamar* y *Avisar mi
/// hora de regreso*.
///
/// **Nadie vigila la salida**: la tarjeta lo dice con esas palabras. Los
/// botones abren el marcador o la aplicación de mensajes; la persona toca
/// *Llamar* o *Enviar*. La app nunca llama ni envía sola. El contacto vive
/// solo en el teléfono: en la laptop la tarjeta lo dice y no lo muestra.
/// Sin diagnósticos ni síntomas: «si te sientes mal, detente y pide ayuda».
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../valores_diseno.dart';
import 'piezas_bici.dart';
import 'textos_bici.dart';
import 'tipos_bici.dart';

/// Un consejo fijo de seguridad, ya redactado por el catálogo.
@immutable
class ConsejoSeguridadVista {
  const ConsejoSeguridadVista({
    required this.titulo,
    required this.texto,
    required this.icono,
  });

  /// «En calle», «En terreno», «Si te sientes mal».
  final String titulo;
  final String texto;
  final IconData icono;
}

/// La tarjeta de seguridad.
class TarjetaSeguridad extends StatelessWidget {
  const TarjetaSeguridad({
    super.key,
    required this.consejos,
    this.contactoTexto,
    this.contactoEnEsteEquipo = true,
    this.mensajeRegresoTexto,
    this.alLlamar,
    this.alAvisarRegreso,
    this.alAgregarContacto,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      vacio: 'Todavía no hay textos de seguridad.',
      cargando: 'Cargando la guía de seguridad…',
      sinConexion: 'Sin conexión. La guía viene con la app.',
      error: 'No se pudo cargar la guía de seguridad.',
    ),
    this.alReintentar,
  });

  final List<ConsejoSeguridadVista> consejos;

  /// «Ana (ejemplo)»; `null` si todavía no hay contacto.
  final String? contactoTexto;

  /// `false` en la laptop: el contacto y las rutas viven solo en el teléfono.
  final bool contactoEnEsteEquipo;

  /// El mensaje que se armaría: «Salgo a las 8:00 y regreso hacia las
  /// 12:00…». Solo se muestra; la persona toca *Enviar* en su aplicación.
  final String? mensajeRegresoTexto;

  /// *Llamar a mi contacto*: 1 toque; abre el marcador.
  final VoidCallback? alLlamar;

  /// *Avisar mi hora de regreso*: abre mensajes con el texto armado.
  final VoidCallback? alAvisarRegreso;
  final VoidCallback? alAgregarContacto;
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaBici.listo) {
      return TarjetaModulo(
        titulo: TextosBici.seguridadTitulo,
        icono: Icons.health_and_safety_outlined,
        child: CuerpoEstadoBici(
          estado: estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
        ),
      );
    }
    return TarjetaModulo(
      titulo: TextosBici.seguridadTitulo,
      icono: Icons.health_and_safety_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in consejos) ...[
            Semantics(
              container: true,
              label: '${c.titulo}. ${c.texto}',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(c.icono, size: 22, color: v.acento),
                  SizedBox(width: e * 1.25),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.titulo,
                          style: v.lectura(
                            tamano: 15,
                            peso: FontWeight.w700,
                            color: v.textoFuerte,
                          ),
                        ),
                        Text(
                          c.texto,
                          style: v.lectura(tamano: 14, color: v.texto),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: e * 1.5),
          ],
          Semantics(
            container: true,
            label: TextosBici.nadieVigila,
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  v.alerta.withValues(alpha: 0.08),
                  v.panel,
                ),
                border: Border.all(color: v.alerta, width: v.grosorBorde),
                borderRadius: BorderRadius.circular(v.radioMediano),
              ),
              child: Padding(
                padding: EdgeInsets.all(e * 1.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 20,
                      color: v.alerta,
                    ),
                    SizedBox(width: e),
                    Expanded(
                      child: Text(
                        TextosBici.nadieVigila,
                        style: v.lectura(
                          tamano: 14,
                          peso: FontWeight.w600,
                          color: v.textoFuerte,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: e * 1.5),
          if (!contactoEnEsteEquipo)
            _Aviso(
              icono: Icons.phone_android,
              texto: TextosBici.rutasSoloEnTelefono,
            )
          else if (contactoTexto == null) ...[
            Text(
              'Todavía no tienes un contacto de confianza.',
              style: v.lectura(tamano: 14.5, color: v.texto),
            ),
            if (alAgregarContacto != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: alAgregarContacto,
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text(TextosBici.agregarContacto),
                ),
              ),
          ] else ...[
            Semantics(
              container: true,
              label:
                  'Tu contacto: $contactoTexto. '
                  '${TextosBici.soloEnEsteEquipo}.',
              excludeSemantics: true,
              child: Wrap(
                spacing: e * 1.5,
                runSpacing: e * 0.5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('CONTACTO', style: v.etiquetaPanel()),
                  Text(
                    contactoTexto!,
                    style: v.lectura(
                      tamano: 16,
                      peso: FontWeight.w700,
                      color: v.textoFuerte,
                    ),
                  ),
                  const MarcaBici(
                    texto: TextosBici.soloEnEsteEquipo,
                    icono: Icons.phone_android,
                  ),
                ],
              ),
            ),
            if (mensajeRegresoTexto != null) ...[
              SizedBox(height: e),
              Text(
                '«$mensajeRegresoTexto»',
                style: v.lectura(tamano: 14, color: v.textoTenue),
              ),
            ],
            SizedBox(height: e * 1.5),
            Wrap(
              spacing: e,
              runSpacing: e,
              children: [
                FilledButton.icon(
                  key: const ValueKey('seguridad-llamar'),
                  onPressed: alLlamar,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(zonaTactilBici, altoAccionBici),
                  ),
                  icon: const Icon(Icons.call, size: 22),
                  label: const Text(TextosBici.llamarAMiContacto),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('seguridad-avisar'),
                  onPressed: alAvisarRegreso,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(zonaTactilBici, altoAccionBici),
                  ),
                  icon: const Icon(Icons.sms_outlined, size: 22),
                  label: const Text(TextosBici.avisarMiHoraDeRegreso),
                ),
              ],
            ),
            SizedBox(height: e),
            Text(
              TextosBici.nadaSeEnviaSolo,
              style: v.lectura(tamano: 13.5, color: v.textoTenue),
            ),
          ],
          SizedBox(height: e * 1.5),
          Text(
            TextosBici.guiaNoSustituye,
            style: v.lectura(tamano: 13.5, color: v.textoTenue),
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Semantics(
      container: true,
      label: texto,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: v.textoTenue),
          SizedBox(width: v.espacio),
          Expanded(
            child: Text(texto, style: v.lectura(tamano: 14, color: v.texto)),
          ),
        ],
      ),
    );
  }
}
