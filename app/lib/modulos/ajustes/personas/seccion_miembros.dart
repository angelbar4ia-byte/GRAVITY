/// Ajustes › Personas › Personas del hogar (solo el dueño; E3 de la Fase 4):
/// invitar a una persona con un rol, cambiar su rol y darla de baja, con el
/// esquema del servidor (`membresias`, `crear_invitacion`).
///
/// El servidor manda: aquí solo se ofrecen las acciones que el dueño sí puede
/// hacer (no a sí mismo, no al dueño, nunca asignar "dueño"). Tras una baja o
/// un cambio de rol se vuelve a pedir lo de Finanzas ([refrescarFinanzas]): el
/// administrador de un libro compartido y el albacea pueden haber cambiado.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/invitaciones/invitaciones.dart';
import '../../../nucleo/permisos/permisos.dart' show nombreRol;
import '../../../nucleo/personas/personas_hogar.dart';
import '../../../nucleo/sesion/proveedores_sesion.dart';
import '../../finanzas/finanzas.dart' show refrescarFinanzas;
import 'seccion_cuenta_maestra.dart' show DialogoCodigoInvitacion;

final _correoValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String _fecha(DateTime fecha) {
  final f = fecha.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}/${dos(f.month)}/${f.year}';
}

/// Lo que explica cada rol al elegirlo.
String descripcionDelRol(Rol rol) => switch (rol) {
  Rol.dueno => 'Administra todo el hogar.',
  Rol.coadministrador => 'Pareja: ve y registra con casi todo el hogar.',
  Rol.familiar => 'Ve lo suyo y lo que se comparte con él.',
  Rol.cuidador => 'Solo Cuidados: su turno, medicamentos y comidas.',
  Rol.casa => 'Cuenta de la tablet de la casa.',
};

class SeccionMiembros extends ConsumerStatefulWidget {
  const SeccionMiembros({super.key});

  @override
  ConsumerState<SeccionMiembros> createState() => _SeccionMiembrosState();
}

class _SeccionMiembrosState extends ConsumerState<SeccionMiembros> {
  late Future<(List<MiembroDelHogar>, List<InvitacionPendiente>)> _carga;

  String? get _hogarId => ref.read(sesionActualProvider)?.hogarId;
  String? get _yo => ref.read(sesionActualProvider)?.persona.id;

  @override
  void initState() {
    super.initState();
    _carga = _cargar();
  }

  Future<(List<MiembroDelHogar>, List<InvitacionPendiente>)> _cargar() async {
    final hogar = _hogarId;
    if (hogar == null) return (<MiembroDelHogar>[], <InvitacionPendiente>[]);
    final miembros = await ref
        .read(repositorioPersonasHogarProvider)
        .miembros(hogar);
    final pendientes = await ref
        .read(repositorioInvitacionesProvider)
        .pendientes(hogar);
    return (miembros, pendientes);
  }

  void _recargar() {
    final carga = _cargar();
    setState(() => _carga = carga);
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Finanzas puede haber cambiado de manos: se vuelve a pedir.
  void _refrescarFinanzas() {
    if (!mounted) return;
    refrescarFinanzas(ProviderScope.containerOf(context, listen: false));
  }

  Future<void> _invitar() async {
    final hogar = _hogarId;
    if (hogar == null) return;
    final datos = await showDialog<(String, Rol)>(
      context: context,
      builder: (contexto) => const _DialogoInvitar(),
    );
    if (datos == null || !mounted) return;
    try {
      final creada = await ref
          .read(repositorioInvitacionesProvider)
          .invitar(hogarId: hogar, correo: datos.$1, rol: datos.$2.name);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (contexto) =>
            DialogoCodigoInvitacion(correo: datos.$1, creada: creada),
      );
    } on ErrorInvitacion catch (error) {
      _aviso(error.mensaje);
    }
    if (mounted) _recargar();
  }

  Future<void> _revocar(InvitacionPendiente invitacion) async {
    try {
      await ref.read(repositorioInvitacionesProvider).revocar(invitacion.id);
    } on ErrorInvitacion catch (error) {
      _aviso(error.mensaje);
    }
    if (mounted) _recargar();
  }

  Future<void> _cambiarRol(MiembroDelHogar miembro) async {
    final nuevo = await showDialog<Rol>(
      context: context,
      builder: (contexto) => _DialogoRol(miembro: miembro),
    );
    if (nuevo == null || nuevo == miembro.rol || !mounted) return;
    try {
      await ref
          .read(repositorioPersonasHogarProvider)
          .cambiarRol(miembro.membresiaId, nuevo);
      _aviso('${miembro.nombre} ahora es ${nombreRol(nuevo)}.');
    } on ErrorPersonas catch (error) {
      _aviso(error.mensaje);
    }
    _refrescarFinanzas();
    if (mounted) _recargar();
  }

  Future<void> _darDeBaja(MiembroDelHogar miembro) async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('Dar de baja a ${miembro.nombre}'),
        content: const Text(
          'Pierde el acceso de inmediato, en todos sus equipos. Lo que '
          'registró se conserva. Si vuelve, hay que invitarla otra vez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('confirmar-baja'),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
    if (confirma != true || !mounted) return;
    try {
      await ref
          .read(repositorioPersonasHogarProvider)
          .darDeBaja(miembro.membresiaId);
      _aviso('${miembro.nombre} ya no tiene acceso.');
    } on ErrorPersonas catch (error) {
      _aviso(error.mensaje);
    }
    _refrescarFinanzas();
    if (mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final yo = _yo;
    return Card(
      key: const ValueKey('personas-del-hogar'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Personas del hogar', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Invita a tu pareja o a tu familia, cambia lo que ve cada una o '
              'quítale el acceso. Los permisos los aplica el servidor.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FutureBuilder(
              future: _carga,
              builder: (context, instantanea) {
                if (instantanea.hasError) {
                  final error = instantanea.error;
                  return Text(
                    error is ErrorPersonas
                        ? error.mensaje
                        : (error is ErrorInvitacion
                              ? error.mensaje
                              : 'No se pudo consultar a las personas.'),
                    key: const ValueKey('personas-error'),
                  );
                }
                if (!instantanea.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  );
                }
                final (miembros, pendientes) = instantanea.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (miembros.isEmpty)
                      const Text('Aún no hay personas en este hogar.'),
                    for (final m in miembros)
                      ListTile(
                        key: ValueKey('miembro-${m.personaId}'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(m.nombre + (m.personaId == yo ? ' (tú)' : '')),
                        subtitle: Text(
                          m.esMaestra
                              ? '${nombreRol(m.rol)} · cuenta maestra'
                              : nombreRol(m.rol),
                        ),
                        trailing: (m.personaId == yo || m.rol == Rol.dueno)
                            ? null
                            : PopupMenuButton<String>(
                                key: ValueKey('opciones-${m.personaId}'),
                                tooltip: 'Opciones de ${m.nombre}',
                                onSelected: (opcion) => switch (opcion) {
                                  'rol' => _cambiarRol(m),
                                  _ => _darDeBaja(m),
                                },
                                itemBuilder: (context) => [
                                  if (!m.esMaestra)
                                    const PopupMenuItem(
                                      value: 'rol',
                                      child: Text('Cambiar rol'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'baja',
                                    child: Text('Dar de baja'),
                                  ),
                                ],
                              ),
                      ),
                    for (final i in pendientes.where((i) => !i.esMaestra))
                      ListTile(
                        key: ValueKey('invitacion-${i.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.mark_email_unread_outlined),
                        title: Text(i.correo),
                        subtitle: Text(
                          'Invitada como ${nombreRol(_rolDe(i.rol))} · vence el '
                          '${_fecha(i.expira)}',
                        ),
                        trailing: TextButton(
                          onPressed: () => _revocar(i),
                          child: const Text('Revocar'),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('invitar-persona'),
                onPressed: _invitar,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Invitar a una persona'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Rol _rolDe(String nombre) =>
      Rol.values.where((r) => r.name == nombre).firstOrNull ?? Rol.familiar;
}

class _DialogoInvitar extends StatefulWidget {
  const _DialogoInvitar();

  @override
  State<_DialogoInvitar> createState() => _DialogoInvitarState();
}

class _DialogoInvitarState extends State<_DialogoInvitar> {
  final _correo = TextEditingController();
  final _formulario = GlobalKey<FormState>();
  Rol _rol = Rol.familiar;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Invitar a una persona'),
    content: SizedBox(
      width: 400,
      child: Form(
        key: _formulario,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const ValueKey('correo-invitado'),
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Correo'),
                validator: (v) => _correoValido.hasMatch((v ?? '').trim())
                    ? null
                    : 'Escribe un correo válido.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Rol>(
                key: const ValueKey('rol-invitado'),
                initialValue: _rol,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: [
                  for (final rol in rolesAsignables)
                    DropdownMenuItem(value: rol, child: Text(nombreRol(rol))),
                ],
                onChanged: (rol) => setState(() => _rol = rol ?? _rol),
              ),
              const SizedBox(height: 8),
              Text(
                descripcionDelRol(_rol),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'La cuenta maestra se crea aparte, más abajo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('enviar-invitacion'),
        onPressed: () {
          if (_formulario.currentState?.validate() ?? false) {
            Navigator.of(context).pop((_correo.text.trim(), _rol));
          }
        },
        child: const Text('Invitar'),
      ),
    ],
  );
}

class _DialogoRol extends StatefulWidget {
  const _DialogoRol({required this.miembro});

  final MiembroDelHogar miembro;

  @override
  State<_DialogoRol> createState() => _DialogoRolState();
}

class _DialogoRolState extends State<_DialogoRol> {
  late Rol _rol = widget.miembro.rol;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Cambiar el rol de ${widget.miembro.nombre}'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: RadioGroup<Rol>(
          groupValue: _rol,
          onChanged: (rol) => setState(() => _rol = rol ?? _rol),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final rol in rolesAsignables)
                RadioListTile<Rol>(
                  key: ValueKey('rol-${rol.name}'),
                  value: rol,
                  title: Text(nombreRol(rol)),
                  subtitle: Text(descripcionDelRol(rol)),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('guardar-rol'),
        onPressed: () => Navigator.of(context).pop(_rol),
        child: const Text('Guardar'),
      ),
    ],
  );
}
