/// Ajustes › Personas › Cuenta maestra (solo el dueño; D19, 23/oct/2026).
///
/// La cuenta maestra es **otra persona con su propio login**, de solo lectura
/// total: lee todo (con consulta registrada), no registra nada y no tiene (+).
/// El dueño la crea invitando un correo; el servidor no manda correo: aquí se
/// muestra el código **una sola vez** para que lo entregue en persona.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../nucleo/invitaciones/invitaciones.dart';
import '../../../nucleo/seguridad/portapapeles_temporal.dart';
import '../../../nucleo/sesion/proveedores_sesion.dart';

final _correoValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String _fecha(DateTime fecha) {
  final f = fecha.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}/${dos(f.month)}/${f.year}';
}

class SeccionCuentaMaestra extends ConsumerStatefulWidget {
  const SeccionCuentaMaestra({super.key});

  @override
  ConsumerState<SeccionCuentaMaestra> createState() =>
      _SeccionCuentaMaestraState();
}

class _SeccionCuentaMaestraState extends ConsumerState<SeccionCuentaMaestra> {
  late Future<(CuentaMaestraActual?, List<InvitacionPendiente>)> _carga;

  String? get _hogarId => ref.read(sesionActualProvider)?.hogarId;

  @override
  void initState() {
    super.initState();
    _carga = _cargar();
  }

  Future<(CuentaMaestraActual?, List<InvitacionPendiente>)> _cargar() async {
    final hogar = _hogarId;
    if (hogar == null) return (null, <InvitacionPendiente>[]);
    final repo = ref.read(repositorioInvitacionesProvider);
    final maestra = await repo.maestraActual(hogar);
    final pendientes = await repo.pendientes(hogar);
    return (maestra, pendientes);
  }

  void _recargar() {
    final carga = _cargar();
    setState(() {
      _carga = carga;
    });
  }

  Future<void> _crear() async {
    final hogar = _hogarId;
    if (hogar == null) return;
    final correo = await showDialog<String>(
      context: context,
      builder: (contexto) => const _DialogoCorreoMaestra(),
    );
    if (correo == null || !mounted) return;
    try {
      final creada = await ref
          .read(repositorioInvitacionesProvider)
          .crearCuentaMaestra(hogarId: hogar, correo: correo);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (contexto) =>
            DialogoCodigoInvitacion(correo: correo, creada: creada),
      );
    } on ErrorInvitacion catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.mensaje)));
    }
    if (mounted) _recargar();
  }

  Future<void> _revocar(InvitacionPendiente invitacion) async {
    try {
      await ref.read(repositorioInvitacionesProvider).revocar(invitacion.id);
    } on ErrorInvitacion catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.mensaje)));
    }
    if (mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      key: const ValueKey('seccion-cuenta-maestra'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cuenta maestra', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Otra persona, con su propio correo y contraseña, que solo lee '
              'todo: no registra nada. Cada consulta a lo de otra persona '
              'queda en la bitácora y todos ven en Privacidad que existe. '
              'Lo tuyo lo sigues registrando con tu cuenta normal.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FutureBuilder(
              future: _carga,
              builder: (context, instantanea) {
                if (instantanea.hasError) {
                  final error = instantanea.error;
                  return Text(
                    error is ErrorInvitacion
                        ? error.mensaje
                        : 'No se pudo consultar la cuenta maestra.',
                    key: const ValueKey('maestra-error'),
                  );
                }
                if (!instantanea.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  );
                }
                final (maestra, pendientes) = instantanea.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      key: const ValueKey('maestra-actual'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.visibility_outlined),
                      title: Text(
                        maestra == null
                            ? 'Aún no hay cuenta maestra'
                            : maestra.nombre,
                      ),
                      subtitle: maestra == null
                          ? null
                          : const Text('Es la cuenta maestra de hoy'),
                    ),
                    for (final invitacion in pendientes.where(
                      (i) => i.esMaestra,
                    ))
                      ListTile(
                        key: ValueKey('invitacion-${invitacion.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.mark_email_unread_outlined),
                        title: Text(invitacion.correo),
                        subtitle: Text(
                          'Invitación pendiente · vence el '
                          '${_fecha(invitacion.expira)}',
                        ),
                        trailing: TextButton(
                          onPressed: () => _revocar(invitacion),
                          child: const Text('Revocar'),
                        ),
                      ),
                  ],
                );
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('crear-cuenta-maestra'),
                onPressed: _crear,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Crear cuenta maestra'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoCorreoMaestra extends StatefulWidget {
  const _DialogoCorreoMaestra();

  @override
  State<_DialogoCorreoMaestra> createState() => _DialogoCorreoMaestraState();
}

class _DialogoCorreoMaestraState extends State<_DialogoCorreoMaestra> {
  final _correo = TextEditingController();
  final _formulario = GlobalKey<FormState>();

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Crear cuenta maestra'),
    content: SizedBox(
      width: 400,
      child: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Escribe el correo de la persona que será la cuenta maestra. '
              'Tiene que ser otra persona (no tú ni alguien que ya está en el '
              'hogar): se registra con ese correo y entra con su propia '
              'contraseña.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('correo-maestra'),
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Correo'),
              validator: (v) => _correoValido.hasMatch((v ?? '').trim())
                  ? null
                  : 'Escribe un correo válido.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_formulario.currentState?.validate() ?? false) {
            Navigator.of(context).pop(_correo.text.trim());
          }
        },
        child: const Text('Invitar'),
      ),
    ],
  );
}

/// Muestra una sola vez el código de una invitación (cuenta maestra o persona
/// del hogar).
class DialogoCodigoInvitacion extends ConsumerWidget {
  const DialogoCodigoInvitacion({
    super.key,
    required this.correo,
    required this.creada,
  });

  final String correo;
  final InvitacionCreada creada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portapapeles = ref.read(portapapelesTemporalProvider);
    return AlertDialog(
      title: const Text('Invitación creada'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entrégale este código a $correo en persona. Se muestra una sola '
              'vez y no se manda por correo. Vence el ${_fecha(creada.expira)}.',
            ),
            const SizedBox(height: 12),
            SelectableText(
              creada.token,
              key: const ValueKey('codigo-invitacion'),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Esa persona se registra con ese mismo correo, lo confirma y '
              'escribe el código al entrar.',
            ),
            const SizedBox(height: 12),
            Text(
              'Si lo copias, se borra del portapapeles a los '
              '${portapapeles.duracion.inSeconds} segundos.',
              key: const ValueKey('aviso-portapapeles'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          key: const ValueKey('copiar-codigo'),
          onPressed: () async {
            await portapapeles.copiar(creada.token);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Código copiado. Se borra en '
                    '${portapapeles.duracion.inSeconds} segundos.',
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copiar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}
