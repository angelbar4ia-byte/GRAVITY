/// Registrar desde la tablet **pública** de la casa (D14, propuesta del
/// arquitecto del 21/oct/2026):
///
/// - **Leer** lo de la casa no pide identidad (modo Casa).
/// - **Algo de la casa** (tachar o agregar a la lista de compras, marcar un
///   recordatorio genérico): eliges tu nombre, **sin PIN**. La cola guarda tu
///   id con origen "tablet de la casa" y lo sube con la cuenta Casa
///   ([registrarAlgoDeLaCasa]).
/// - **Algo personal** (un gasto, un hábito, algo de Cuidados): nombre y
///   **PIN**; la sesión dura solo esa acción o el tiempo sin uso
///   ([registrarAlgoPersonal]).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/base_local/base_local.dart';
import '../../nucleo/cola/proveedores_cola.dart';
import '../../nucleo/contratos/roles.dart';
import '../../nucleo/permisos/permisos.dart';
import '../../nucleo/tablet/controlador_tablet.dart';
import '../../nucleo/tablet/usuarios_tablet.dart';
import '../navegacion.dart';
import '../pantallas/registro_rapido.dart';
import 'dialogo_pin.dart';

/// Lo que se registra en la tablet de la casa eligiendo solo el nombre. Lo
/// conecta cada módulo en su fase con [registrarAlgoDeLaCasa].
class AccionDeLaCasa {
  const AccionDeLaCasa({
    required this.etiqueta,
    required this.icono,
    required this.fase,
  });

  final String etiqueta;
  final IconData icono;
  final int fase;
}

const List<AccionDeLaCasa> accionesDeLaCasa = [
  AccionDeLaCasa(
    etiqueta: 'Lista de compras',
    icono: Icons.shopping_cart_outlined,
    fase: 7,
  ),
  AccionDeLaCasa(
    etiqueta: 'Recordatorio de la casa',
    icono: Icons.alarm_on_outlined,
    fase: 5,
  ),
];

/// "¿Quién eres?" sin PIN: devuelve la persona elegida o `null`.
Future<UsuarioTablet?> elegirNombre(
  BuildContext context,
  List<UsuarioTablet> usuarios, {
  String titulo = '¿Quién eres?',
  String? detalle,
}) => showDialog<UsuarioTablet>(
  context: context,
  builder: (contexto) => SimpleDialog(
    key: const ValueKey('elegir-nombre'),
    title: Text(titulo),
    children: [
      if (detalle != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(detalle),
        ),
      for (final usuario in usuarios)
        SimpleDialogOption(
          key: ValueKey('nombre-${usuario.personaId}'),
          onPressed: () => Navigator.of(contexto).pop(usuario),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(usuario.nombre.characters.first.toUpperCase()),
            ),
            title: Text(usuario.nombre),
            minTileHeight: 56,
          ),
        ),
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextButton(
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Cancelar'),
          ),
        ),
      ),
    ],
  ),
);

/// Registra algo **de la casa** desde el modo Casa: pide elegir el nombre
/// (sin PIN) y lo encola con [OrigenRegistro.tabletCasa]. Devuelve el id del
/// registro, o `null` si se canceló.
///
/// Si alguien ya está dentro con su PIN (o la tablet es personal), se
/// registra a su nombre, sin preguntar.
Future<String?> registrarAlgoDeLaCasa(
  BuildContext context, {
  required String tipo,
  required Map<String, Object?> carga,
  String? id,
}) async {
  final contenedor = ProviderScope.containerOf(context, listen: false);
  final cola = contenedor.read(colaSinConexionProvider);
  final estado = contenedor.read(controladorTabletProvider);
  if (!estado.muestraModoCasa || estado.soloAccion) {
    return cola.encolar(tipo: tipo, carga: carga, id: id);
  }
  if (estado.usuarios.isEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Agrega personas a la tablet para registrar a tu nombre.'),
      ),
    );
    return null;
  }
  final persona = await elegirNombre(
    context,
    estado.usuarios,
    detalle: 'Queda a tu nombre, desde la tablet de la casa.',
  );
  if (persona == null) return null;
  return cola.encolar(
    tipo: tipo,
    carga: carga,
    id: id,
    personaId: persona.personaId,
    origen: OrigenRegistro.tabletCasa,
  );
}

/// Registra algo **personal** desde el modo Casa: elige el nombre, pide el
/// PIN solo para esta acción, abre su registro y, al cerrarlo, intenta
/// subirlo con su sesión y vuelve al modo Casa. Si nadie la toca, el tiempo
/// sin uso también regresa al modo Casa (y cierra el registro).
Future<void> registrarAlgoPersonal(
  BuildContext context,
  OpcionRegistrar opcion,
) async {
  final contenedor = ProviderScope.containerOf(context, listen: false);
  final mensajero = ScaffoldMessenger.maybeOf(context);
  final navegador = Navigator.of(context, rootNavigator: true);
  if (!registroDisponible(opcion.tipo)) {
    mensajero?.showSnackBar(
      SnackBar(
        content: Text('${opcion.etiqueta}: llega en la Fase ${opcion.fase}.'),
      ),
    );
    return;
  }
  final estado = contenedor.read(controladorTabletProvider);
  final candidatos = [
    for (final usuario in estado.usuarios)
      if (puedeRegistrarEn(
        usuario.rol,
        opcion.modulo,
        esMaestra: usuario.esMaestra,
      ))
        usuario,
  ];
  if (candidatos.isEmpty) {
    mensajero?.showSnackBar(
      SnackBar(
        content: Text(
          'Nadie de esta tablet puede registrar '
          '"${opcion.etiqueta.toLowerCase()}".',
        ),
      ),
    );
    return;
  }
  final persona = await elegirNombre(
    navegador.context,
    candidatos,
    titulo: '¿Quién registra?',
    detalle: 'Después tu PIN, solo para esta acción.',
  );
  if (persona == null || !navegador.mounted) return;
  final entro = await mostrarDialogoPin(
    navegador.context,
    persona,
    paraAccion: true,
  );
  if (!entro || !navegador.mounted) return;

  await abrirRegistro(navegador.context, opcion);

  // Sigue dentro la misma persona (no venció el tiempo): se intenta subir con
  // su sesión antes de volver a la cuenta Casa.
  final actual = contenedor.read(controladorTabletProvider);
  if (actual.soloAccion && actual.usuarioActivo?.personaId == persona.personaId) {
    try {
      await contenedor
          .read(colaSinConexionProvider)
          .procesar()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Sin señal: queda en la bandeja de salida (abajo).
    }
    // Sin señal, lo registrado queda en la bandeja de salida: se sube solo
    // cuando haya señal, sin pedir el PIN otra vez (D14, 23/oct/2026).
    if (await contenedor
        .read(colaSinConexionProvider)
        .hayPendientesDe(persona.personaId)) {
      mensajero?.showSnackBar(
        const SnackBar(
          content: Text(
            'Sin señal: quedó en la bandeja de salida. Se sube solo cuando '
            'haya señal; no hace falta tu PIN otra vez.',
          ),
        ),
      );
    }
    contenedor.read(controladorTabletProvider.notifier).volverAlReposo();
  }
}

/// Hoja "Registrar" del modo Casa.
Future<void> mostrarRegistrarEnTabletCasa(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (contexto) => const HojaRegistrarTabletCasa(),
    );

class HojaRegistrarTabletCasa extends ConsumerWidget {
  const HojaRegistrarTabletCasa({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarios = ref.watch(
      controladorTabletProvider.select((e) => e.usuarios),
    );
    final personales = [
      for (final opcion in opcionesDeRegistro)
        if (usuarios.any(
          (u) => puedeRegistrarEn(
            u.rol,
            opcion.modulo,
            esMaestra: u.esMaestra,
          ),
        ))
          opcion,
    ];
    final tema = Theme.of(context);
    Widget titulo(String texto, String detalle) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto, style: tema.textTheme.titleMedium),
          Text(detalle, style: tema.textTheme.bodySmall),
        ],
      ),
    );
    void cerrarYDespues(Future<void> Function(BuildContext origen) accion) {
      final origen = Navigator.of(context).context;
      Navigator.of(context).pop();
      unawaited(accion(origen));
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text('Registrar', style: tema.textTheme.titleLarge),
          ),
          titulo('De la casa', 'Eliges tu nombre; no pide PIN.'),
          for (final accion in accionesDeLaCasa)
            ListTile(
              leading: Icon(accion.icono),
              title: Text(accion.etiqueta),
              minTileHeight: 56,
              onTap: () => cerrarYDespues((origen) async {
                ScaffoldMessenger.maybeOf(origen)?.showSnackBar(
                  SnackBar(
                    content: Text(
                      '${accion.etiqueta}: llega en la Fase ${accion.fase}.',
                    ),
                  ),
                );
              }),
            ),
          if (personales.isNotEmpty) ...[
            titulo('Personal', 'Tu nombre y tu PIN, solo para esta acción.'),
            for (final opcion in personales)
              ListTile(
                key: ValueKey('casa-personal-${opcion.tipo.name}'),
                leading: Icon(opcion.icono),
                title: Text(opcion.etiqueta),
                trailing: const Icon(Icons.pin_outlined),
                minTileHeight: 56,
                onTap: () => cerrarYDespues(
                  (origen) => registrarAlgoPersonal(origen, opcion),
                ),
              ),
          ],
          if (puedeRegistrarAlgo(usuarios, Modulo.cuidados))
            ListTile(
              leading: const Icon(Icons.volunteer_activism_outlined),
              title: const Text('Algo de Cuidados'),
              trailing: const Icon(Icons.pin_outlined),
              minTileHeight: 56,
              onTap: () => cerrarYDespues((origen) async {
                ScaffoldMessenger.maybeOf(origen)?.showSnackBar(
                  const SnackBar(
                    content: Text('Algo de Cuidados: llega en la Fase 5.'),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

/// `true` si alguien de la tablet puede registrar en [modulo].
bool puedeRegistrarAlgo(List<UsuarioTablet> usuarios, Modulo modulo) =>
    usuarios.any(
      (u) =>
          puedeAbrir(u.rol, modulo) &&
          puedeConSesion(
            u.rol,
            modulo,
            Accion.escribir,
            esMaestra: u.esMaestra,
          ),
    );
