/// Ajustes › Desarrollador (D16; `docs/DISENO_UX_UI.md`, sección 10).
///
/// Lista las operaciones de `api/openapi.yaml` por grupo: método, ruta, qué
/// hace, roles, si pide confirmación y si nunca pasa por la IA. Los datos salen
/// de `operaciones.g.dart`, generado desde la especificación. El botón "Abrir
/// en Swagger UI" abre la página local para consultar y probar.
///
/// Quién la ve (solo el Dueño y solo en la laptop) lo decide el cascarón de la
/// plataforma. Los colores salen de `Theme.of(context)`.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../nucleo/permisos/permisos.dart';
import 'abrir_swagger.dart';
import 'operacion_api.dart';
import 'operaciones.g.dart';

/// Pantalla de Ajustes › Desarrollador con los datos generados.
class PantallaDesarrollador extends StatelessWidget {
  const PantallaDesarrollador({super.key});

  @override
  Widget build(BuildContext context) => VistaDesarrollador(
    grupos: gruposOperaciones,
    version: versionEspecificacion,
    rutaSwagger: rutaSwaggerConfigurada,
  );
}

/// La pantalla con sus dependencias inyectables (para pruebas).
class VistaDesarrollador extends StatefulWidget {
  const VistaDesarrollador({
    super.key,
    required this.grupos,
    required this.version,
    this.rutaSwagger = '',
    this.abrirUrl = abrirConNavegador,
    this.existeArchivo = existeEnDisco,
    this.directorioActual,
  });

  final List<GrupoOperaciones> grupos;
  final String version;

  /// `RUTA_SWAGGER`, o vacío si no se configuró.
  final String rutaSwagger;
  final AbrirUrl abrirUrl;
  final ExisteArchivo existeArchivo;

  /// Directorio desde donde se buscan `api/swagger/index.html`
  /// (por defecto, el directorio de trabajo de la app).
  final String? directorioActual;

  @override
  State<VistaDesarrollador> createState() => _VistaDesarrolladorState();
}

class _VistaDesarrolladorState extends State<VistaDesarrollador> {
  String? _aviso;
  bool _abriendo = false;

  Future<void> _abrirSwagger() async {
    final ubicacion = ubicarSwagger(
      rutaConfigurada: widget.rutaSwagger,
      directorioActual: widget.directorioActual ?? Directory.current.path,
      existe: widget.existeArchivo,
    );
    switch (ubicacion) {
      case SwaggerNoEncontrado(:final rutaConfigurada):
        setState(() {
          _aviso = rutaConfigurada == null
              ? 'No encontré la página de Swagger UI.\n\n$instruccionesSwagger'
              : 'La ruta configurada (RUTA_SWAGGER) no existe:\n$rutaConfigurada\n\n'
                    '$instruccionesSwagger';
        });
      case SwaggerEncontrado(:final uri):
        setState(() => _abriendo = true);
        var abierta = false;
        try {
          abierta = await widget.abrirUrl(uri);
        } on Exception {
          abierta = false;
        }
        if (!mounted) return;
        setState(() {
          _abriendo = false;
          _aviso = abierta
              ? null
              : 'No se pudo abrir el navegador. Abre esta dirección a mano:\n$uri';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final total = widget.grupos.fold<int>(
      0,
      (n, g) => n + g.operaciones.length,
    );

    return Material(
      color: esquema.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Desarrollador · APIs',
                    style: tema.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'OpenAPI ${widget.version} · $total operaciones en '
                    '${widget.grupos.length} grupos · Solo en esta laptop; '
                    'no se publica en internet.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              FilledButton.tonalIcon(
                onPressed: _abriendo ? null : _abrirSwagger,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir en Swagger UI'),
              ),
            ],
          ),
          if (_aviso != null) ...[
            const SizedBox(height: 16),
            _Aviso(
              texto: _aviso!,
              alCerrar: () => setState(() => _aviso = null),
            ),
          ],
          const SizedBox(height: 12),
          const _Leyenda(),
          for (final grupo in widget.grupos) _SeccionGrupo(grupo: grupo),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.alCerrar});

  final String texto;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: esquema.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: esquema.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: SelectableText(
                texto,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: esquema.onSecondaryContainer,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: alCerrar,
              icon: const Icon(Icons.close),
              color: esquema.onSecondaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Marca(
          icono: Icons.edit_note,
          texto: 'Pide confirmación: escribe datos',
        ),
        _Marca(icono: Icons.lock_outline, texto: 'Nunca pasa por la IA (D3)'),
      ],
    );
  }
}

class _SeccionGrupo extends StatelessWidget {
  const _SeccionGrupo({required this.grupo});

  final GrupoOperaciones grupo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ExpansionTile(
        key: PageStorageKey('grupo-${grupo.nombre}'),
        initiallyExpanded: true,
        maintainState: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Text(
          '${grupo.nombre} (${grupo.operaciones.length})',
          style: tema.textTheme.titleMedium,
        ),
        subtitle: Text(
          grupo.descripcion,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          for (final operacion in grupo.operaciones)
            _FilaOperacion(operacion: operacion),
        ],
      ),
    );
  }
}

/// Colores del método, del tema activo (sin colores fijos).
(Color, Color) coloresMetodo(ColorScheme esquema, MetodoHttp metodo) =>
    switch (metodo) {
      MetodoHttp.get => (esquema.primary, esquema.onPrimary),
      MetodoHttp.post => (esquema.tertiary, esquema.onTertiary),
      MetodoHttp.put ||
      MetodoHttp.patch => (esquema.secondary, esquema.onSecondary),
      MetodoHttp.delete => (esquema.error, esquema.onError),
    };

class _FilaOperacion extends StatelessWidget {
  const _FilaOperacion({required this.operacion});

  final OperacionApi operacion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final (fondo, texto) = coloresMetodo(esquema, operacion.metodo);
    final roles = operacion.roles.map(nombreRol).join(', ');

    return Container(
      key: ValueKey('operacion-${operacion.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: fondo.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
        color: fondo.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 68,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: fondo,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  operacion.metodo.etiqueta,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.labelMedium?.copyWith(
                    color: texto,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              SelectableText(
                operacion.ruta,
                style: tema.textTheme.titleSmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              Text(operacion.resumen, style: tema.textTheme.bodyMedium),
            ],
          ),
          if (operacion.descripcion.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              operacion.descripcion,
              style: tema.textTheme.bodySmall?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Marca(icono: Icons.group_outlined, texto: 'Roles: $roles'),
              if (operacion.escribe == true)
                const _Marca(
                  icono: Icons.edit_note,
                  texto: 'Pide confirmación',
                ),
              if (operacion.escribe == null)
                const _Marca(
                  icono: Icons.edit_note,
                  texto: 'Pide confirmación si la herramienta escribe',
                ),
              if (operacion.soloLocal == true)
                const _Marca(
                  icono: Icons.lock_outline,
                  texto: 'Nunca pasa por la IA',
                ),
              if (operacion.soloLocal == null)
                const _Marca(
                  icono: Icons.lock_outline,
                  texto: 'Pasa por la IA según la herramienta',
                ),
              if (operacion.fase > 0)
                _Marca(icono: Icons.schedule, texto: 'Fase ${operacion.fase}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: esquema.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: esquema.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              texto,
              style: tema.textTheme.labelSmall?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
