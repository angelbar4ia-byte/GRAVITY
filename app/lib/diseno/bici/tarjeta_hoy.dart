/// La tarjeta **«Bicicleta»** de la pantalla Hoy (B1, 6.1): el viernes en la
/// noche invita a preparar la salida; el sábado muestra a qué hora sales,
/// cuándo regresas y si te alcanza el tiempo para la revisión de las 14:30.
///
/// *Salí* es **1 toque** y no obliga a registrar nada más (F-B1). Una salida
/// que no salió (por clima o seguridad) se dice sin culpa y sin mensaje de
/// ruptura. Va con la personalidad Sport (alto contraste, números grandes).
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../valores_diseno.dart';
import 'piezas_bici.dart';
import 'textos_bici.dart';
import 'tipos_bici.dart';

/// La tarjeta de la bici en Hoy.
class TarjetaBiciHoy extends StatelessWidget {
  const TarjetaBiciHoy({
    super.key,
    required this.momento,
    required this.salidaTexto,
    this.detalleTexto,
    this.regresoTexto,
    this.revisionTexto,
    this.encaje,
    this.encajeTexto,
    this.preparacionTexto,
    this.avisoPiernasTexto,
    this.notaTexto,
    this.modoFoco = false,
    this.alSali,
    this.alEmpezar,
    this.alPreparar,
    this.alRegistrar,
    this.alTerminar,
    this.alPosponerRevision,
    this.alDeshacer,
    this.alAbrir,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      vacio: 'Hoy no toca salir en bici.',
      vacioDetalle: 'Cuando quieras, ponla en tu agenda.',
      cargando: 'Buscando tu salida…',
      sinConexion: 'Sin conexión. Tu salida sigue disponible aquí.',
      error: 'No se pudo cargar tu salida.',
    ),
    this.alReintentar,
  });

  final MomentoSalida momento;

  /// «Sábado · 8:00» o «Mañana · 8:00».
  final String salidaTexto;

  /// «Unas 4 h · ruta mixta».
  final String? detalleTexto;

  /// «12:00».
  final String? regresoTexto;

  /// «14:30».
  final String? revisionTexto;

  /// Si la salida cabe antes de la revisión semanal (4.7).
  final EncajeRevision? encaje;

  /// «Sobran 60 min» o «Faltan 30 min».
  final String? encajeTexto;

  /// «8 de 10».
  final String? preparacionTexto;

  /// Un aviso de piernas ya redactado (4.6).
  final String? avisoPiernasTexto;

  /// Un mensaje del catálogo («Hoy toca tu salida en bici. ¿Todo listo?»).
  final String? notaTexto;

  /// Con el modo foco la tarjeta dice «Hoy puedes salir o dejarlo» (4.10); la
  /// preparación y la seguridad **no se ocultan**.
  final bool modoFoco;

  /// *Salí*: 1 toque, sin registrar nada más.
  final VoidCallback? alSali;

  /// *Empezar*: arranca el cronómetro.
  final VoidCallback? alEmpezar;

  /// *Preparar* (la víspera).
  final VoidCallback? alPreparar;

  /// *Registrar lo que hice*.
  final VoidCallback? alRegistrar;

  /// *Terminar* con la salida en curso.
  final VoidCallback? alTerminar;

  /// *Pasar mi revisión a más tarde* (solo si no cabe).
  final VoidCallback? alPosponerRevision;

  /// *Deshacer* tras marcar la salida.
  final VoidCallback? alDeshacer;

  /// Abre la pantalla de planear.
  final VoidCallback? alAbrir;
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;

  static const _titulo = 'Bicicleta';

  Color _colorEncaje(ValoresDiseno v, EncajeRevision e) => switch (e) {
    EncajeRevision.cabe => v.exito,
    EncajeRevision.cabeJusto => v.alerta,
    EncajeRevision.noCabe => v.alerta,
  };

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaBici.listo) {
      return TarjetaModulo(
        titulo: _titulo,
        icono: Icons.directions_bike,
        child: CuerpoEstadoBici(
          estado: estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
        ),
      );
    }
    final marca = switch (momento) {
      MomentoSalida.hecha => MarcaBici(
        texto: 'Hecha',
        icono: Icons.check_circle_outline,
        color: v.exito,
      ),
      MomentoSalida.omitida => const MarcaBici(
        texto: 'No salió hoy',
        icono: Icons.remove_circle_outline,
      ),
      MomentoSalida.enCurso => MarcaBici(
        texto: TextosBici.enCurso,
        icono: Icons.directions_bike,
        color: v.acento,
        enfasis: true,
      ),
      _ => null,
    };
    final esVispera = momento == MomentoSalida.vispera;
    final titulo = esVispera ? TextosBici.prepararSalida : salidaTexto;
    final subtitulo = esVispera ? salidaTexto : detalleTexto;
    final conRevision = revisionTexto != null;
    final anuncio = [
      titulo,
      ?subtitulo,
      if (regresoTexto != null) 'Regreso estimado $regresoTexto',
      if (conRevision) 'Revisión semanal $revisionTexto',
      if (encaje != null) anuncioEncaje(encaje!, encajeTexto),
      if (preparacionTexto != null) 'Preparación $preparacionTexto',
    ].join('. ');

    final enSalida = momento == MomentoSalida.diaDeSalida;
    return TarjetaModulo(
      titulo: _titulo,
      icono: Icons.directions_bike,
      alTocar: alAbrir,
      accion: marca,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            label: anuncio,
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  key: const ValueKey('bici-hoy-titulo'),
                  style: v.titulo(tamano: esVispera ? 26 : 34),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo,
                    style: v.numero(tamano: 15, color: v.textoTenue),
                  ),
                if (regresoTexto != null || conRevision) ...[
                  SizedBox(height: e * 1.5),
                  Wrap(
                    spacing: e * 3,
                    runSpacing: e,
                    children: [
                      if (regresoTexto != null)
                        _Dato(etiqueta: 'REGRESO', valor: regresoTexto!),
                      if (conRevision)
                        _Dato(etiqueta: 'REVISIÓN', valor: revisionTexto!),
                    ],
                  ),
                ],
                if (encaje != null) ...[
                  SizedBox(height: e * 1.25),
                  MarcaBici(
                    texto: textoEncaje(encaje!, encajeTexto),
                    icono: encaje!.icono,
                    color: _colorEncaje(v, encaje!),
                  ),
                ],
                if (preparacionTexto != null) ...[
                  SizedBox(height: e * 1.25),
                  Text(
                    'Preparación: $preparacionTexto',
                    style: v.lectura(
                      tamano: 14.5,
                      peso: FontWeight.w600,
                      color: v.textoFuerte,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (avisoPiernasTexto != null) ...[
            SizedBox(height: e * 1.5),
            AvisoBici(texto: avisoPiernasTexto!),
          ],
          if (modoFoco) ...[
            SizedBox(height: e * 1.5),
            Text(
              'Hoy puedes salir o dejarlo: ambos están bien.',
              style: v.lectura(tamano: 14, color: v.texto),
            ),
          ] else if (notaTexto != null) ...[
            SizedBox(height: e * 1.5),
            Text(notaTexto!, style: v.lectura(tamano: 14, color: v.texto)),
          ],
          SizedBox(height: e * 2),
          _Acciones(
            momento: momento,
            enSalida: enSalida,
            alSali: alSali,
            alEmpezar: alEmpezar,
            alPreparar: alPreparar,
            alRegistrar: alRegistrar,
            alTerminar: alTerminar,
            alDeshacer: alDeshacer,
            alPosponerRevision: encaje == EncajeRevision.noCabe
                ? alPosponerRevision
                : null,
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta, style: v.etiquetaPanel()),
        Text(
          valor,
          style: v.numero(
            tamano: 26,
            peso: FontWeight.w700,
            color: v.textoFuerte,
          ),
        ),
      ],
    );
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({
    required this.momento,
    required this.enSalida,
    required this.alSali,
    required this.alEmpezar,
    required this.alPreparar,
    required this.alRegistrar,
    required this.alTerminar,
    required this.alDeshacer,
    required this.alPosponerRevision,
  });

  final MomentoSalida momento;
  final bool enSalida;
  final VoidCallback? alSali;
  final VoidCallback? alEmpezar;
  final VoidCallback? alPreparar;
  final VoidCallback? alRegistrar;
  final VoidCallback? alTerminar;
  final VoidCallback? alDeshacer;
  final VoidCallback? alPosponerRevision;

  @override
  Widget build(BuildContext context) {
    final e = ValoresDiseno.de(context).espacio;
    final grande = FilledButton.styleFrom(
      minimumSize: const Size(zonaTactilBici, altoAccionBici),
    );
    switch (momento) {
      case MomentoSalida.vispera:
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            key: const ValueKey('bici-preparar'),
            onPressed: alPreparar,
            style: grande,
            icon: const Icon(Icons.checklist, size: 22),
            label: const Text(TextosBici.preparar),
          ),
        );
      case MomentoSalida.diaDeSalida:
        return Wrap(
          spacing: e,
          runSpacing: e,
          children: [
            FilledButton.icon(
              key: const ValueKey('bici-sali'),
              onPressed: alSali,
              style: grande,
              icon: const Icon(Icons.check, size: 22),
              label: const Text(TextosBici.sali),
            ),
            OutlinedButton.icon(
              key: const ValueKey('bici-empezar'),
              onPressed: alEmpezar,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(zonaTactilBici, altoAccionBici),
              ),
              icon: const Icon(Icons.play_arrow, size: 22),
              label: const Text(TextosBici.empezar),
            ),
            if (alRegistrar != null)
              TextButton(
                key: const ValueKey('bici-registrar'),
                onPressed: alRegistrar,
                child: const Text(TextosBici.registrarLoQueHice),
              ),
            if (alPosponerRevision != null)
              OutlinedButton(
                key: const ValueKey('bici-posponer-revision'),
                onPressed: alPosponerRevision,
                child: const Text(TextosBici.posponerRevision),
              ),
          ],
        );
      case MomentoSalida.enCurso:
        return Wrap(
          spacing: e,
          runSpacing: e,
          children: [
            FilledButton.icon(
              key: const ValueKey('bici-terminar'),
              onPressed: alTerminar,
              style: grande,
              icon: const Icon(Icons.stop, size: 22),
              label: const Text(TextosBici.terminar),
            ),
            if (alPosponerRevision != null)
              OutlinedButton(
                key: const ValueKey('bici-posponer-revision'),
                onPressed: alPosponerRevision,
                child: const Text(TextosBici.posponerRevision),
              ),
          ],
        );
      case MomentoSalida.hecha:
      case MomentoSalida.omitida:
        return Wrap(
          spacing: e,
          runSpacing: e,
          children: [
            if (alRegistrar != null && momento == MomentoSalida.hecha)
              OutlinedButton(
                key: const ValueKey('bici-registrar'),
                onPressed: alRegistrar,
                child: const Text(TextosBici.registrarLoQueHice),
              ),
            if (alDeshacer != null)
              TextButton.icon(
                key: const ValueKey('bici-deshacer'),
                onPressed: alDeshacer,
                icon: const Icon(Icons.undo, size: 18),
                label: const Text(TextosBici.deshacer),
              ),
          ],
        );
    }
  }
}
