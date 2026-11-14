/// Formulario y pantalla de confirmación de las acciones de Google dentro del
/// panel de conversación (enviar correo, crear evento). Nada se envía ni se
/// crea hasta pulsar el botón de la tarjeta (D8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import 'acciones_google.dart';

class TarjetaGoogle extends ConsumerStatefulWidget {
  const TarjetaGoogle({super.key, required this.accion});

  final AccionGoogle accion;

  @override
  ConsumerState<TarjetaGoogle> createState() => _TarjetaGoogleState();
}

class _TarjetaGoogleState extends ConsumerState<TarjetaGoogle> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _c = TextEditingController();
  final _d = TextEditingController();
  String? _errorLocal;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    _d.dispose();
    super.dispose();
  }

  bool get _esCorreo => widget.accion.herramienta == 'gmail.redactar';

  void _enviarFormulario() {
    final n = ref.read(accionesGoogleProvider.notifier);
    if (_esCorreo) {
      if (_a.text.trim().isEmpty ||
          _b.text.trim().isEmpty ||
          _c.text.trim().isEmpty) {
        setState(
          () =>
              _errorLocal = 'Escribe el destinatario, el asunto y el mensaje.',
        );
        return;
      }
      setState(() => _errorLocal = null);
      n.enviarFormulario({
        'para': _a.text.trim(),
        'asunto': _b.text.trim(),
        'cuerpo': _c.text,
      });
      return;
    }
    // Evento: "2026-11-12 19:00" en la hora local de la persona.
    final inicio = DateTime.tryParse(_b.text.trim());
    final fin = DateTime.tryParse(_c.text.trim());
    if (_a.text.trim().isEmpty ||
        inicio == null ||
        fin == null ||
        !fin.isAfter(inicio)) {
      setState(
        () => _errorLocal = 'Escribe el título y las horas como 2026-11-12 19:00; el evento debe terminar después de empezar.',
      );
      return;
    }
    setState(() => _errorLocal = null);
    n.enviarFormulario({
      'titulo': _a.text.trim(),
      'inicio': isoConZona(inicio),
      'fin': isoConZona(fin),
      if (_d.text.trim().isNotEmpty) 'lugar': _d.text.trim(),
    });
  }

  Widget _campo(
    String clave,
    TextEditingController c,
    String etiqueta, {
    int lineas = 1,
    bool habilitado = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      key: ValueKey(clave),
      controller: c,
      enabled: habilitado,
      minLines: lineas,
      maxLines: lineas == 1 ? 1 : 6,
      decoration: InputDecoration(labelText: etiqueta),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final a = widget.accion;
    final n = ref.read(accionesGoogleProvider.notifier);
    final error = a.error ?? _errorLocal;
    final c = a.confirmacion;
    final enConfirmacion = a.fase == FaseGoogle.confirmacion && c != null;

    return DecoratedBox(
      key: const ValueKey('tarjeta-google'),
      decoration: BoxDecoration(
        color: Color.alphaBlend(v.acento.withValues(alpha: 0.08), v.panel),
        border: Border.all(color: v.acento, width: v.grosorBorde),
        borderRadius: BorderRadius.circular(v.radioMediano),
      ),
      child: Padding(
        padding: EdgeInsets.all(v.espacio * 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              enConfirmacion
                  ? c.titulo
                  : (_esCorreo ? 'Redactar un correo' : 'Crear un evento'),
              key: const ValueKey('titulo-google'),
              style: v.etiquetaPanel(tamano: 12),
            ),
            const SizedBox(height: 8),
            if (enConfirmacion) ...[
              for (final l in c.lineas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    l,
                    style: v.lectura(tamano: 14, color: v.textoFuerte),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'No se hace nada hasta que lo confirmes.',
                style: v.lectura(tamano: 12, color: v.textoTenue),
              ),
            ] else if (_esCorreo) ...[
              _campo('google-para', _a, 'Para', habilitado: !a.ocupada),
              _campo('google-asunto', _b, 'Asunto', habilitado: !a.ocupada),
              _campo(
                'google-cuerpo',
                _c,
                'Mensaje',
                lineas: 3,
                habilitado: !a.ocupada,
              ),
              Text(
                'Se guarda como borrador en tu Gmail; se envía solo si lo confirmas.',
                style: v.lectura(tamano: 12, color: v.textoTenue),
              ),
            ] else ...[
              _campo('google-titulo', _a, 'Título', habilitado: !a.ocupada),
              _campo(
                'google-inicio',
                _b,
                'Empieza (AAAA-MM-DD HH:MM)',
                habilitado: !a.ocupada,
              ),
              _campo(
                'google-fin',
                _c,
                'Termina (AAAA-MM-DD HH:MM)',
                habilitado: !a.ocupada,
              ),
              _campo(
                'google-lugar',
                _d,
                'Lugar (opcional)',
                habilitado: !a.ocupada,
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  key: const ValueKey('error-google'),
                  style: v.lectura(tamano: 13, color: v.acento),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('cancelar-google'),
                  onPressed: a.ocupada ? null : n.cancelar,
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: ValueKey(
                    enConfirmacion ? 'confirmar-google' : 'continuar-google',
                  ),
                  onPressed: a.ocupada
                      ? null
                      : (enConfirmacion ? n.confirmar : _enviarFormulario),
                  child: Text(enConfirmacion ? c.boton : 'Revisar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
