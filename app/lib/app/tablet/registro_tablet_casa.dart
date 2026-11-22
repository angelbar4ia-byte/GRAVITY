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
import '../../nucleo/contratos/rutas.dart';
import '../navegacion.dart';
import '../pantallas/registro_rapido.dart';
import '../pantallas_externas.dart' show rolesQueConversanConGravity;
import '../router.dart' show routerProvider;
import 'dialogo_pin.dart';

/// Lo que se registra en la tablet de la casa eligiendo solo el nombre. Lo
/// conecta cada módulo con [registrarAlgoDeLaCasa].
///
/// **Pendiente (F8-7.1):** ninguna de las dos acciones se puede conectar sin
/// cambiar permisos confirmados. Casa no tiene acceso a Alimentación (matriz y
/// servidor: D23; D28 aún no está en la matriz) ni escribe en Cuidados (solo
/// recordatorios genéricos de lectura, D3), y no hay tabla ni tipo de cola
/// para "agregar a la lista de la casa" ni para "marcar un recordatorio de la
/// casa". Mientras el dueño no decida qué puede hacer la cuenta Casa, la
/// opción lo dice con honestidad en vez de prometer una fase.
class AccionDeLaCasa {
  const AccionDeLaCasa({
    required this.etiqueta,
    required this.icono,
    required this.aviso,
  });

  final String etiqueta;
  final IconData icono;

  /// Lo que se le dice a la persona mientras la acción no está disponible.
  final String aviso;
}

const List<AccionDeLaCasa> accionesDeLaCasa = [
  AccionDeLaCasa(
    etiqueta: 'Lista de compras',
    icono: Icons.shopping_cart_outlined,
    aviso:
        'La lista de compras todavía no se puede usar desde la tablet de la '
        'casa. Por ahora se marca en Alimentación, desde el teléfono.',
  ),
  AccionDeLaCasa(
    etiqueta: 'Recordatorio de la casa',
    icono: Icons.alarm_on_outlined,
    aviso:
        'Los recordatorios de la casa todavía no se pueden marcar desde esta '
        'tablet. Se atienden desde el teléfono de quien está de turno.',
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
        content: Text(
          'Agrega personas a la tablet para registrar a tu nombre.',
        ),
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
  // Consumo y SOS son de la sección reservada de Hábitos (D13, D21): la
  // tablet pública nunca los ofrece ni los abre.
  if (registroReservado(opcion.tipo)) {
    mensajero?.showSnackBar(
      const SnackBar(
        content: Text('Esto no está disponible en la tablet de la casa.'),
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
  if (actual.soloAccion &&
      actual.usuarioActivo?.personaId == persona.personaId) {
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

/// Entra a la tablet como una persona (nombre y PIN, entrada normal: ve sus
/// pantallas y vuelve sola al modo Casa tras el tiempo sin uso, D14) y abre
/// [ruta]. Sirve para lo que no es una hoja de registro sino una pantalla del
/// módulo: *Algo de Cuidados* (su turno) y *Escribir a GRAVITY* (su Hoy, que
/// trae la conversación). [puedeEntrar] filtra a quién se le ofrece.
Future<void> entrarALaTabletYAbrir(
  BuildContext context, {
  required String ruta,
  required bool Function(UsuarioTablet usuario) puedeEntrar,
  required String sinCandidatos,
}) async {
  final contenedor = ProviderScope.containerOf(context, listen: false);
  final mensajero = ScaffoldMessenger.maybeOf(context);
  final navegador = Navigator.of(context, rootNavigator: true);
  final router = contenedor.read(routerProvider);
  final candidatos = [
    for (final u in contenedor.read(controladorTabletProvider).usuarios)
      if (puedeEntrar(u)) u,
  ];
  if (candidatos.isEmpty) {
    mensajero?.showSnackBar(SnackBar(content: Text(sinCandidatos)));
    return;
  }
  final persona = await elegirNombre(
    navegador.context,
    candidatos,
    detalle: 'Después tu PIN.',
  );
  if (persona == null || !navegador.mounted) return;
  await mostrarDialogoPin(navegador.context, persona);
  // Al entrar, el cascarón de la tablet cierra el diálogo por su cuenta (B2) y
  // `mostrarDialogoPin` puede devolver `false` aunque haya entrado: se mira
  // quién está dentro, no lo que devolvió el diálogo.
  final dentro = contenedor.read(controladorTabletProvider).usuarioActivo;
  if (dentro?.personaId != persona.personaId) return;
  router.go(ruta);
}

/// Botón "Escribir a GRAVITY" del modo Casa. La cuenta Casa no conversa con
/// GRAVITY (D5; el servidor responde 403): quien escribe entra primero con su
/// PIN y llega a su pantalla de Hoy, que trae la conversación por texto. La
/// voz todavía no existe.
Future<void> escribirAGravityEnTabletCasa(BuildContext context) {
  final conversan = rolesQueConversanConGravity;
  return entrarALaTabletYAbrir(
    context,
    ruta: Rutas.inicio,
    puedeEntrar: (u) => conversan.contains(u.rol),
    sinCandidatos:
        'Nadie de esta tablet conversa con GRAVITY. Agrega a alguien con su '
        'PIN para escribirle.',
  );
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
        // La sección reservada de Hábitos (consumo y SOS) no se ofrece aquí.
        if (!registroReservado(opcion.tipo) &&
            usuarios.any(
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
              subtitle: const Text('Aún no disponible aquí'),
              onTap: () => cerrarYDespues((origen) async {
                ScaffoldMessenger.maybeOf(origen)
                    ?.showSnackBar(SnackBar(content: Text(accion.aviso)));
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
              key: const ValueKey('casa-personal-cuidados'),
              leading: const Icon(Icons.volunteer_activism_outlined),
              title: const Text('Algo de Cuidados'),
              subtitle: const Text('Entras con tu PIN a tu turno'),
              trailing: const Icon(Icons.pin_outlined),
              minTileHeight: 56,
              onTap: () => cerrarYDespues(
                (origen) => entrarALaTabletYAbrir(
                  origen,
                  ruta: Rutas.cuidados,
                  puedeEntrar: (u) => puedeRegistrarEn(
                    u.rol,
                    Modulo.cuidados,
                    esMaestra: u.esMaestra,
                  ),
                  sinCandidatos:
                      'Nadie de esta tablet puede registrar algo de Cuidados.',
                ),
              ),
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
