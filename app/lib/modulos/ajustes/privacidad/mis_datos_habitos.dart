/// Ajustes › Privacidad › "Mis datos de Hábitos" (Fase 3, D13): exportar todo
/// lo propio y borrarlo, en el equipo y en la nube. Pide el PIN y, para borrar,
/// escribir la palabra BORRAR. Solo aparece donde Hábitos es de la persona y
/// el equipo puede tener llaves (nunca en la tablet pública de la casa).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/sensibles/sensibles.dart';
import '../../../app/sesion_efectiva.dart';
import '../../../nucleo/permisos/permisos.dart' show puedeUsarHabitos;
import '../../../nucleo/seguridad/montos.dart';
import '../../../nucleo/sensibles/llaves_habitos.dart';
import '../../../nucleo/sensibles/mis_datos.dart';
import '../../../app/avisos/con_avisos.dart' show tipoEquipoAvisosProvider;

/// Guarda el archivo que la persona elige; `false` si cancela. Las pruebas lo
/// sustituyen.
final guardarArchivoProvider =
    Provider<Future<bool> Function(String nombre, Uint8List bytes)>(
      (ref) => (nombre, bytes) async {
        final destino = await FilePicker.saveFile(
          fileName: nombre,
          bytes: bytes,
          mimeType: 'application/json',
          dialogTitle: 'Guardar mis datos de Hábitos',
        );
        return destino != null;
      },
    );

class MisDatosDeHabitos extends ConsumerWidget {
  const MisDatosDeHabitos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionEfectivaProvider);
    final tipo = ref.watch(tipoEquipoAvisosProvider);
    if (sesion == null ||
        !puedeUsarHabitos(sesion.rol, esMaestra: sesion.esMaestra) ||
        !equipoPuedeTenerLlaves(tipo)) {
      return const SizedBox.shrink();
    }
    final tema = Theme.of(context);
    final hayFuente = ref.watch(fuenteDeDatosHabitosProvider) != null;
    return Card(
      key: const ValueKey('privacidad-mis-datos-habitos'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Mis datos de Hábitos', style: tema.textTheme.titleMedium),
            ),
            ListTile(
              key: const ValueKey('mis-datos-exportar'),
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Exportar mis datos'),
              subtitle: Text(
                hayFuente
                    ? 'Un archivo con todo lo tuyo de Hábitos.'
                    : 'Disponible cuando Hábitos esté listo en este equipo.',
              ),
              enabled: hayFuente,
              onTap: hayFuente ? () => _exportar(context, ref) : null,
            ),
            ListTile(
              key: const ValueKey('mis-datos-borrar'),
              leading: Icon(Icons.delete_outline, color: tema.colorScheme.error),
              title: const Text('Borrar mis datos'),
              subtitle: const Text(
                'En este equipo y en la nube. No se puede deshacer.',
              ),
              onTap: () => _borrar(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> _pedirPin(BuildContext context, WidgetRef ref, String motivo) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoTexto(
        titulo: 'Tu PIN',
        mensaje: motivo,
        etiqueta: 'PIN',
        oculto: true,
        boton: 'Continuar',
      ),
    );
    if (pin == null || pin.isEmpty) return false;
    final r = await ref.read(controladorMontosProvider.notifier).verificar(pin);
    if (r == ResultadoRevelar.revelado) return true;
    if (context.mounted) {
      _aviso(
        context,
        switch (r) {
          ResultadoRevelar.bloqueado => 'Demasiados intentos. Espera un momento.',
          ResultadoRevelar.faltaPin =>
            'Primero crea tu PIN en Privacidad › Montos.',
          _ => 'Ese PIN no es el correcto.',
        },
      );
    }
    return false;
  }

  static void _aviso(BuildContext context, String texto) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _exportar(BuildContext context, WidgetRef ref) async {
    final fuente = ref.read(fuenteDeDatosHabitosProvider);
    if (fuente == null) return;
    final sensibles = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Exportar mis datos'),
        content: const Text(
          '¿Incluir también lo reservado (hábitos a eliminar, diario y oración)? '
          'Quien tenga el archivo podría leerlo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Sin lo reservado')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Incluirlo')),
        ],
      ),
    );
    if (sensibles == null || !context.mounted) return;
    if (!await _pedirPin(context, ref, 'Para exportar tus datos, escribe tu PIN.')) return;
    if (!context.mounted) return;
    List<String>? frase;
    if (sensibles) {
      final texto = await showDialog<String>(
        context: context,
        builder: (_) => _DialogoTexto(
          titulo: 'Frase de recuperación',
          mensaje:
              'Para cifrar lo reservado, escribe tus 12 palabras. Déjalo vacío '
              'para guardarlo sin cifrar: $avisoDeArchivoSensible',
          etiqueta: '12 palabras',
          boton: 'Continuar',
        ),
      );
      if (texto == null || !context.mounted) return;
      if (texto.trim().isNotEmpty) {
        frase = FraseDeRecuperacion.normalizar(texto);
        if (!FraseDeRecuperacion.esValida(frase)) {
          _aviso(context, 'Esa frase no es válida. Revisa las 12 palabras.');
          return;
        }
      }
    }
    final contenido = await ExportacionHabitos.generar(
      fuente: fuente,
      ahora: DateTime.now(),
      incluirSensibles: sensibles ? TipoSensible.values.toSet() : const {},
      frase: frase,
    );
    final ok = await ref.read(guardarArchivoProvider)(
      'mis-datos-habitos.json',
      Uint8List.fromList(utf8.encode(contenido)),
    );
    if (context.mounted) {
      _aviso(context, ok ? 'Listo, guardé tus datos.' : 'No se guardó el archivo.');
    }
  }

  Future<void> _borrar(BuildContext context, WidgetRef ref) async {
    final alcance = await showDialog<AlcanceDeBorrado>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('¿Qué quieres borrar?'),
        children: [
          SimpleDialogOption(
            key: const ValueKey('borrar-sensibles'),
            onPressed: () => Navigator.pop(c, AlcanceDeBorrado.sensibles),
            child: const Text('Hábitos a eliminar y consumo'),
          ),
          SimpleDialogOption(
            key: const ValueKey('borrar-diario'),
            onPressed: () => Navigator.pop(c, AlcanceDeBorrado.diario),
            child: const Text('Diario y oración'),
          ),
          SimpleDialogOption(
            key: const ValueKey('borrar-todo'),
            onPressed: () => Navigator.pop(c, AlcanceDeBorrado.todo),
            child: const Text('Todo lo mío de Hábitos'),
          ),
        ],
      ),
    );
    if (alcance == null || !context.mounted) return;
    if (!await _pedirPin(context, ref, 'Para borrar, escribe tu PIN.')) return;
    if (!context.mounted) return;
    final palabra = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoTexto(
        titulo: 'Confirmar borrado',
        mensaje: 'Escribe $palabraDeConfirmacion para borrar. No se puede deshacer.',
        etiqueta: palabraDeConfirmacion,
        boton: 'Borrar',
      ),
    );
    if (palabra == null || !context.mounted) return;
    if (!BorradoDeMisDatos.confirma(palabra)) {
      _aviso(context, 'No escribiste $palabraDeConfirmacion; no se borró nada.');
      return;
    }
    final persona = ref.read(sesionEfectivaProvider)?.persona.id;
    if (persona == null) return;
    try {
      await ref.read(borradoDeMisDatosProvider).borrar(persona, alcance);
      if (context.mounted) _aviso(context, 'Listo, borré tus datos.');
    } catch (_) {
      if (context.mounted) {
        _aviso(
          context,
          'Borré lo de este equipo, pero no pude borrar lo de la nube. '
          'Vuelve a intentarlo con señal.',
        );
      }
    }
  }
}

class _DialogoTexto extends StatefulWidget {
  const _DialogoTexto({
    required this.titulo,
    required this.mensaje,
    required this.etiqueta,
    required this.boton,
    this.oculto = false,
  });

  final String titulo;
  final String mensaje;
  final String etiqueta;
  final String boton;
  final bool oculto;

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.titulo),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.mensaje),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('dialogo-texto'),
          controller: _texto,
          obscureText: widget.oculto,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.etiqueta),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        onPressed: () => Navigator.pop(context, _texto.text),
        child: Text(widget.boton),
      ),
    ],
  );
}
