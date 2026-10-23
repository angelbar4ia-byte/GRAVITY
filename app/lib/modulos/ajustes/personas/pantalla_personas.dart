/// Ajustes › Personas y roles (solo Dueño): qué ve cada rol (espejo de la
/// matriz) y, en la tablet, las personas que entran con PIN y el tiempo para
/// regresar al modo Casa.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dispositivo.dart';
import '../../../app/tablet/dialogo_agregar_persona.dart';
import '../../../app/tablet/dialogo_pin.dart' show mensajeDesbloqueo;
import '../../../nucleo/contratos/dispositivo.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/permisos/permisos.dart';
import '../../../nucleo/seguridad/pin.dart';
import '../../../nucleo/tablet/controlador_tablet.dart';
import '../../../nucleo/tablet/usuarios_tablet.dart';
import '../marco_seccion.dart';
import '../secciones_ajustes.dart';

/// Opciones del tiempo sin uso para regresar al modo Casa.
const opcionesRegresoModoCasa = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 30),
];

String textoDuracion(Duration d) => d.inMinutes == 0
    ? '${d.inSeconds} segundos'
    : (d.inMinutes == 1 ? '1 minuto' : '${d.inMinutes} minutos');

class PantallaPersonas extends ConsumerWidget {
  const PantallaPersonas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esTablet = ref.watch(tipoDispositivoProvider) == TipoDispositivo.tablet;
    final tema = Theme.of(context);
    return MarcoSeccion(
      seccion: SeccionAjustes.personas,
      hijos: [
        const NotaAjustes(
          'Invitar y dar de baja personas llega con el esquema del servidor. '
          'Los permisos los aplica el servidor; aquí solo se muestran.',
          icono: Icons.person_add_alt,
        ),
        const SizedBox(height: 8),
        Text('Qué ve cada rol', style: tema.textTheme.titleMedium),
        for (final rol in Rol.values) _TarjetaRol(rol: rol),
        if (esTablet) ...[
          const SizedBox(height: 24),
          Text('Personas de esta tablet', style: tema.textTheme.titleMedium),
          const _PersonasTablet(),
        ],
      ],
    );
  }
}

class _TarjetaRol extends StatelessWidget {
  const _TarjetaRol({required this.rol});

  final Rol rol;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: Text(nombreRol(rol)),
      children: [
        for (final modulo in Modulo.values)
          ListTile(
            dense: true,
            title: Text(nombreModulo(modulo)),
            trailing: Text(permisoDe(rol, modulo).descripcion),
          ),
      ],
    ),
  );
}

class _PersonasTablet extends ConsumerWidget {
  const _PersonasTablet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(controladorTabletProvider);
    final controlador = ref.read(controladorTabletProvider.notifier);
    final regreso = estado.configuracion.regresoModoCasa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final usuario in estado.usuarios)
          Card(
            child: ListTile(
              title: Text(usuario.nombre),
              subtitle: Text('${nombreRol(usuario.rol)} · entra con PIN'),
              trailing: PopupMenuButton<String>(
                tooltip: 'Opciones',
                onSelected: (opcion) async {
                  switch (opcion) {
                    case 'pin':
                      final mensaje = await _cambiarPin(
                        context,
                        controlador,
                        usuario,
                      );
                      if (mensaje != null && context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(mensaje)));
                      }
                    case 'quitar':
                      await controlador.quitarUsuario(usuario.personaId);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'pin', child: Text('Cambiar PIN')),
                  PopupMenuItem(
                    value: 'quitar',
                    child: Text('Quitar de la tablet'),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => mostrarDialogoAgregarPersona(context),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Agregar persona'),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Regresar al modo Casa tras'),
          trailing: DropdownButton<Duration>(
            value: opcionesRegresoModoCasa.contains(regreso) ? regreso : null,
            hint: Text(textoDuracion(regreso)),
            items: [
              for (final opcion in opcionesRegresoModoCasa)
                DropdownMenuItem(
                  value: opcion,
                  child: Text(textoDuracion(opcion)),
                ),
            ],
            onChanged: (opcion) {
              if (opcion != null) controlador.fijarRegresoModoCasa(opcion);
            },
          ),
        ),
      ],
    );
  }

  /// Pide el PIN actual y el nuevo (la persona lo cambia ella misma: con el
  /// actual se vuelve a cifrar su credencial). Devuelve el mensaje a mostrar.
  Future<String?> _cambiarPin(
    BuildContext context,
    ControladorTablet controlador,
    UsuarioTablet usuario,
  ) async {
    final pines = await showDialog<(String, String)>(
      context: context,
      builder: (contexto) => _DialogoPinNuevo(nombre: usuario.nombre),
    );
    if (pines == null) return null;
    final resultado = await controlador.cambiarPin(
      usuario.personaId,
      pinActual: pines.$1,
      pinNuevo: pines.$2,
    );
    return resultado == ResultadoDesbloqueo.abierto
        ? 'PIN cambiado.'
        : mensajeDesbloqueo(
            resultado,
            espera: controlador.esperaRestante(usuario.personaId),
          );
  }
}

class _DialogoPinNuevo extends StatefulWidget {
  const _DialogoPinNuevo({required this.nombre});

  final String nombre;

  @override
  State<_DialogoPinNuevo> createState() => _DialogoPinNuevoState();
}

class _DialogoPinNuevoState extends State<_DialogoPinNuevo> {
  final _actual = TextEditingController();
  final _nuevo = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nuevo.dispose();
    super.dispose();
  }

  Widget _campo(TextEditingController control, String etiqueta, Key llave) =>
      TextField(
        key: llave,
        controller: control,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: etiqueta),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Cambiar el PIN de ${widget.nombre}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _campo(_actual, 'PIN actual', const Key('pin-actual')),
        _campo(_nuevo, 'PIN nuevo (4 a 6 dígitos)', const Key('pin-nuevo')),
        if (_error != null)
          Text(
            _error!,
            key: const Key('pin-nuevo-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const Text(
          'Si olvidaste tu PIN, quítate de la tablet y vuelve a agregarte con '
          'tu correo y contraseña.',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_actual.text.isEmpty) return;
          final error = errorDePinNuevo(_nuevo.text);
          if (error != null) {
            setState(() => _error = error);
            return;
          }
          Navigator.of(context).pop((_actual.text, _nuevo.text));
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
