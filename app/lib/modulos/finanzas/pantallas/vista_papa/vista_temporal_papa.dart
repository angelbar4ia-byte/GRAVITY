/// Vista temporal de solo lectura de Finanzas de Papá (D24).
///
/// - Contador regresivo de 30 minutos; al llegar a cero (o si el dueño la
///   cancela) la pantalla padre deja de montar este widget y las cifras se
///   sueltan de la memoria.
/// - Captura de pantalla bloqueada mientras está a la vista ([PantallaSegura]).
/// - Sin copiar, sin seleccionar (`Text`, nunca `SelectableText`; la selección
///   queda apagada con `SelectionContainer.disabled`), sin exportar y sin
///   compartir: aquí no hay ninguna de esas acciones.
/// - Las cifras (en centavos) se dibujan con [MontoOcultable]; no salen a IA,
///   bocinas ni tablet pública (D3, D14).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    show ClaseCuenta, DatosFinanzas, Libro, Movimiento, TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/pantalla_segura.dart' show PantallaSegura;
import '../../../../diseno/diseno.dart' show MontoOcultable, ValoresDiseno;
import '../../../../nucleo/seguridad/vista_papa_activa.dart'
    show vistaPapaActivaProvider;
import '../../datos/vista_papa.dart';
import '../../estado/proveedores_vista_papa.dart';
import '../comunes.dart' show conceptoDe;

/// Cuántos movimientos recientes se muestran.
const movimientosEnVistaPapa = 15;

/// "mm:ss" de lo que falta.
String formatoContador(Duration restante) {
  final seg = restante.inSeconds.clamp(0, 1 << 30);
  final m = (seg ~/ 60).toString().padLeft(2, '0');
  final s = (seg % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class VistaTemporalPapa extends ConsumerStatefulWidget {
  const VistaTemporalPapa({
    super.key,
    required this.solicitud,
    required this.ahora,
  });

  final SolicitudVista solicitud;

  /// La hora que marca el reloj de la app (la actualiza la pantalla padre cada
  /// segundo).
  final DateTime ahora;

  @override
  ConsumerState<VistaTemporalPapa> createState() => _EstadoVista();
}

class _EstadoVista extends ConsumerState<VistaTemporalPapa> {
  DatosFinanzas? _datos;
  Object? _error;
  bool _cargando = true;

  late final _activa = ref.read(vistaPapaActivaProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Avisa al cascarón (su guardia también bloquea capturas). Fuera del
    // montaje para no tocar un proveedor mientras se construye el árbol.
    Future.microtask(_activa.abrir);
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final d = await ref.read(repositorioVistaPapaProvider).leerVista();
      if (mounted) setState(() => _datos = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    // Las cifras no se quedan: al cerrarse la vista se sueltan.
    _datos = null;
    Future.microtask(_activa.cerrar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final restante = widget.solicitud.restanteEn(widget.ahora);
    return PantallaSegura(
      activa: true,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Finanzas de Papá'),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: v.espacio * 2),
              child: Center(
                child: Text(
                  formatoContador(restante),
                  key: const ValueKey('vista-papa-contador'),
                  style: v.numero(tamano: 18),
                ),
              ),
            ),
          ],
        ),
        body: SelectionContainer.disabled(child: _cuerpo(context, v)),
      ),
    );
  }

  Widget _cuerpo(BuildContext context, ValoresDiseno v) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final datos = _datos;
    if (_error != null || datos == null) {
      return Padding(
        padding: EdgeInsets.all(v.espacio * 2),
        child: Text(
          'No se pudo abrir la vista. Si el tiempo ya acabó, pide otra.',
          key: const ValueKey('vista-papa-sin-datos'),
          style: v.lectura(tamano: 16),
        ),
      );
    }
    final Libro? libro = datos.libros
        .where((l) => l.tipo == TipoLibro.representado)
        .firstOrNull;
    if (libro == null) {
      return Padding(
        padding: EdgeInsets.all(v.espacio * 2),
        child: Text(
          'Sin datos todavía.',
          key: const ValueKey('vista-papa-sin-datos'),
          style: v.lectura(tamano: 16),
        ),
      );
    }
    final vista = datos.vista(libro.id);
    final cuentas = datos.cuentas
        .where((c) => c.libroId == libro.id && c.clase == ClaseCuenta.activo)
        .toList();
    final movs = <Movimiento>[...vista.movimientos]
      ..sort((a, b) => b.registradoEn.compareTo(a.registradoEn));

    return ListView(
      padding: EdgeInsets.all(v.espacio * 2),
      children: [
        Text(
          'Solo lectura · ${libro.nombre}',
          key: const ValueKey('vista-papa-titulo'),
          style: v.lectura(tamano: 14, color: v.textoTenue),
        ),
        SizedBox(height: v.espacio * 2),
        Text('Cuentas', style: v.lectura(tamano: 16)),
        for (final c in cuentas)
          ListTile(
            key: ValueKey('vista-papa-cuenta-${c.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(c.nombre),
            trailing: MontoOcultable(
              centavos: vista.saldo(c.id, incluirPendientes: true),
            ),
          ),
        SizedBox(height: v.espacio * 2),
        Text('Movimientos recientes', style: v.lectura(tamano: 16)),
        for (final m in movs.take(movimientosEnVistaPapa))
          ListTile(
            key: ValueKey('vista-papa-mov-${m.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(conceptoDe(m, datos, vista)),
            subtitle: Text(m.fecha.toString()),
            trailing: MontoOcultable(centavos: m.monto),
          ),
      ],
    );
  }
}
