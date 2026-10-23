/// Qué pantallas se protegen contra capturas (I11) y el widget que lo pide.
///
/// Se protege lo que muestra **dinero** (Finanzas) o **datos clínicos**
/// (Cuidados, cuando existan): las pantallas de esos módulos, "Hoy" para quien
/// los ve resumidos, y las hojas de registro (gasto, ingreso). El resto de la
/// app se puede capturar. La protección en sí está en
/// `nucleo/seguridad/pantalla_segura.dart`.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nucleo/contratos/roles.dart';
import '../nucleo/contratos/rutas.dart';
import '../nucleo/permisos/permisos.dart';
import '../nucleo/seguridad/pantalla_segura.dart';
import 'navegacion.dart';
import 'sesion_efectiva.dart';

bool _bajoRuta(String ubicacion, String base) =>
    ubicacion == base || ubicacion.startsWith('$base/');

/// `true` si [rol] ve datos clínicos de verdad en Cuidados (no solo los
/// recordatorios genéricos de la cuenta Casa, D3, ni nada sin consentimiento).
bool veDatosClinicos(Rol rol) =>
    puedeAbrir(rol, Modulo.cuidados) &&
    !soloRecordatoriosGenericos(rol, Modulo.cuidados) &&
    !dependeDelConsentimiento(rol, Modulo.cuidados);

/// `true` si [rol] ve dinero (Finanzas).
bool veDinero(Rol rol) => puedeAbrir(rol, Modulo.finanzas);

/// `true` si la pantalla en [ubicacion] muestra dinero o datos clínicos a
/// quien la ve con el [rol] dado (`null`: nadie ha entrado).
bool esPantallaSensible(String ubicacion, Rol? rol) {
  if (rol == null) return false;
  if (_bajoRuta(ubicacion, Rutas.finanzas)) return veDinero(rol);
  if (_bajoRuta(ubicacion, Rutas.cuidados)) return veDatosClinicos(rol);
  // "Hoy" resume Finanzas y Cuidados para quien los ve.
  if (ubicacion == Rutas.inicio) return veDinero(rol) || veDatosClinicos(rol);
  // Bandeja de solicitudes de la cuidadora (medicamentos, citas…).
  if (_bajoRuta(ubicacion, RutasApp.solicitudes)) return veDatosClinicos(rol);
  // Registros que el servidor no aceptó: pueden ser gastos.
  if (_bajoRuta(ubicacion, RutasApp.pendientes)) {
    return veDinero(rol) || veDatosClinicos(rol);
  }
  return false;
}

/// Pide la protección de la pantalla mientras [activa] sea `true` y el widget
/// esté en el árbol. Se puede anidar (hojas encima de una pantalla).
class PantallaSegura extends StatefulWidget {
  const PantallaSegura({super.key, required this.activa, required this.child});

  final bool activa;
  final Widget child;

  @override
  State<PantallaSegura> createState() => _PantallaSeguraState();
}

class _PantallaSeguraState extends State<PantallaSegura> {
  VoidCallback? _soltar;
  ControladorPantallaSegura? _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(controladorPantallaSeguraProvider);
    if (widget.activa) _soltar = _controlador!.pedir();
  }

  @override
  void didUpdateWidget(PantallaSegura anterior) {
    super.didUpdateWidget(anterior);
    if (widget.activa == (_soltar != null)) return;
    if (widget.activa) {
      _soltar = _controlador!.pedir();
    } else {
      _soltar?.call();
      _soltar = null;
    }
  }

  @override
  void dispose() {
    _soltar?.call();
    _soltar = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Protege las pantallas del cascarón que lo necesitan, según la ruta y el
/// rol con el que se arma la interfaz (en la tablet, la persona que entró con
/// su PIN o, si nadie, la cuenta Casa).
class GuardiaDePantallaSegura extends ConsumerWidget {
  const GuardiaDePantallaSegura({
    super.key,
    required this.ubicacion,
    required this.child,
  });

  final String ubicacion;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PantallaSegura(
    activa: esPantallaSensible(ubicacion, ref.watch(rolEfectivoProvider)),
    child: child,
  );
}
