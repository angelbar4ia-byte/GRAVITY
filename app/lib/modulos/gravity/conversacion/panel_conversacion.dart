/// Conversación de texto con GRAVITY en la pantalla principal (laptop y
/// teléfono). Un campo de texto y las respuestas en la misma pantalla.
///
/// Solo la ven quienes conversan libremente con GRAVITY (D5): dueño,
/// coadministrador y familiar. La cuidadora y Casa no (usan sus solicitudes y
/// recordatorios). La cuenta maestra (D19) conversa, pero el registro de
/// herramientas le quita todo lo que escribe.
///
/// Lo que el asistente decide ejecutar (abrir una pantalla, mostrar un
/// resumen) se hace aquí, en el dispositivo, con el registro de herramientas
/// y los permisos de quien lo usa; su resultado se muestra en esta pantalla y
/// no vuelve al asistente (D3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/pantallas_externas.dart'
    show consultaLocalFinanzasProvider, consultaLocalHabitosProvider;
import '../../../app/sesion_efectiva.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/herramientas/herramientas.dart';
import 'conversacion.dart';

/// Roles que conversan libremente con GRAVITY (D5, spec de la Fase 6).
const Set<Rol> rolesQueConversan = {
  Rol.dueno,
  Rol.coadministrador,
  Rol.familiar,
};

class PanelConversacion extends ConsumerStatefulWidget {
  const PanelConversacion({super.key, this.compacto = false, this.navegar});

  /// Más bajo, para el teléfono.
  final bool compacto;

  /// Abre una ruta. Por omisión, el router de la app (si hay).
  final void Function(String ruta)? navegar;

  @override
  ConsumerState<PanelConversacion> createState() => _PanelConversacionState();
}

class _PanelConversacionState extends ConsumerState<PanelConversacion> {
  static final RegistroHerramientas _registro = registroDeGravity();

  final TextEditingController _control = TextEditingController();
  final ScrollController _desplazamiento = ScrollController();

  @override
  void dispose() {
    _control.dispose();
    _desplazamiento.dispose();
    super.dispose();
  }

  /// La cuenta maestra (D19) solo lee: el registro le quita lo que escribe.
  /// Sin servicio de sesión (pruebas, demostración) no lo es.
  bool _esMaestra() {
    try {
      return ref.read(esCuentaMaestraProvider);
    } catch (_) {
      return false;
    }
  }

  Future<String?> _ejecutar(String herramienta) async {
    final rol = ref.read(rolEfectivoProvider);
    if (rol == null) return null;
    final resultado = await _registro.ejecutar(
      herramienta,
      const {},
      ContextoHerramienta(
        rol: rol,
        esMaestra: _esMaestra(),
        navegar: (ruta) {
          final propia = widget.navegar;
          if (propia != null) {
            propia(ruta);
          } else {
            GoRouter.maybeOf(context)?.go(ruta);
          }
        },
        consultaLocal: (nombre) => (nombre.startsWith('habitos.')
            ? ref.read(consultaLocalHabitosProvider)
            : ref.read(consultaLocalFinanzasProvider))(nombre),
      ),
    );
    // Una herramienta que pide confirmación no se ejecuta desde aquí.
    if (resultado.requiereConfirmacion) return null;
    return resultado.contenido;
  }

  void _enviar() {
    final texto = _control.text;
    if (texto.trim().isEmpty) return;
    _control.clear();
    ref
        .read(conversacionAsistenteProvider.notifier)
        .enviar(texto, ejecutar: _ejecutar);
  }

  @override
  Widget build(BuildContext context) {
    final rol = ref.watch(rolEfectivoProvider);
    if (rol == null || !rolesQueConversan.contains(rol)) {
      return const SizedBox.shrink();
    }
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final estado = ref.watch(conversacionAsistenteProvider);
    ref.listen(conversacionAsistenteProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_desplazamiento.hasClients) {
          _desplazamiento.jumpTo(_desplazamiento.position.maxScrollExtent);
        }
      });
    });

    return DecoratedBox(
      key: const ValueKey('panel-conversacion'),
      decoration: BoxDecoration(
        color: v.panel,
        border: Border.all(color: v.borde, width: v.grosorBorde),
        borderRadius: BorderRadius.circular(v.radioMediano),
      ),
      child: Padding(
        padding: EdgeInsets.all(e * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (estado.mensajes.isNotEmpty) ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: widget.compacto ? 200 : 260,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: ListView.separated(
                    key: const ValueKey('lista-conversacion'),
                    controller: _desplazamiento,
                    shrinkWrap: true,
                    itemCount: estado.mensajes.length,
                    separatorBuilder: (_, _) => SizedBox(height: e),
                    itemBuilder: (_, i) => _Burbuja(
                      key: ValueKey('mensaje-conversacion-$i'),
                      mensaje: estado.mensajes[i],
                    ),
                  ),
                ),
              ),
              SizedBox(height: e * 1.5),
            ],
            if (estado.pensando)
              Padding(
                padding: EdgeInsets.only(bottom: e),
                child: Text(
                  'GRAVITY está pensando…',
                  key: const ValueKey('conversacion-pensando'),
                  style: v.lectura(tamano: 13, color: v.textoTenue),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('campo-conversacion'),
                    controller: _control,
                    enabled: !estado.pensando,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _enviar(),
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 1000,
                    buildCounter: (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                    decoration: const InputDecoration(
                      hintText: 'Pregúntale a GRAVITY…',
                    ),
                  ),
                ),
                SizedBox(width: e),
                IconButton.filled(
                  key: const ValueKey('boton-enviar-conversacion'),
                  tooltip: 'Enviar',
                  onPressed: estado.pensando ? null : _enviar,
                  icon: const Icon(Icons.arrow_upward),
                ),
              ],
            ),
            SizedBox(height: e),
            Text(
              'No escribas cifras de dinero ni datos de salud: se ocultan antes '
              'de enviarse y se ven solo en tu pantalla.',
              key: const ValueKey('aviso-conversacion'),
              style: v.lectura(tamano: 12, color: v.textoTenue),
            ),
          ],
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({super.key, required this.mensaje});

  final MensajeConversacion mensaje;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final propio = mensaje.autor == AutorMensaje.persona;
    final esError = mensaje.autor == AutorMensaje.error;
    final etiqueta = switch (mensaje.autor) {
      AutorMensaje.persona => 'Tú',
      AutorMensaje.asistente => 'GRAVITY',
      AutorMensaje.local => 'En tu pantalla',
      AutorMensaje.error => 'Aviso',
    };
    return Align(
      alignment: propio ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: propio
                ? Color.alphaBlend(v.acento.withValues(alpha: 0.14), v.panel)
                : Color.lerp(v.fondo, v.panel, 0.5),
            border: Border.all(color: esError ? v.acento : v.borde),
            borderRadius: BorderRadius.circular(v.radioMediano),
          ),
          child: Padding(
            padding: EdgeInsets.all(v.espacio * 1.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: v.etiquetaPanel(tamano: 11)),
                const SizedBox(height: 2),
                SelectableText(
                  mensaje.texto,
                  style: v.lectura(tamano: 15, color: v.textoFuerte),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
