/// Módulo Casa (laptop y tablet): estado del puente con Home Assistant y las
/// frases fijas de las bocinas (D6, D9). Solo lectura.
///
/// Reglas que esta pantalla respeta:
/// - **D6:** por las bocinas solo hay frases fijas; nunca dinero ni datos
///   clínicos. La pantalla solo *lista* las frases aprobadas
///   ([frasesFijas]); no deja escribir una frase libre ni mandar texto.
/// - **D9:** el token de Home Assistant vive en el equipo del puente, nunca en
///   la app, y no se abre ningún puerto del router. Por eso la pantalla no
///   pide ni muestra tokens ni direcciones: solo explica cómo se configura.
/// - **D5:** las bocinas llegan como la cuenta Casa; la cuidadora no tiene este
///   canal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/herramientas/alimentacion_voz.dart';
import '../../../nucleo/permisos/permisos.dart';
import '../estado/estado_puente.dart';
import '../puente/frases.dart';
import '../puente/mensaje_bocina.dart';

/// Pasos para dejar el puente funcionando (resumen de
/// `docs/modulos/casa-puente.md`, sección 4). Sin precios ni direcciones.
const List<String> pasosParaConfigurarPuente = [
  'Conecta el equipo de Home Assistant al router, enciéndelo y crea la cuenta '
      'de administrador.',
  'Activa Home Assistant Cloud para Google Assistant. No abras puertos en el '
      'router, ni "por si acaso".',
  'Pon las bocinas Xiaomi en el mismo Wi-Fi y agrégalas a Home Assistant '
      '(Google Cast): deben aparecer como reproductores de medios.',
  'Usa la cuenta de Google de la casa en Google Home y la cuenta Casa en '
      'GRAVITY.',
  'En Google Home crea una rutina por frase, cada una activando su escena en '
      'Home Assistant.',
  'Crea un token de acceso para un usuario dedicado y guárdalo solo como '
      'secreto del equipo del puente. Nunca en la app ni en el repositorio.',
];

class PantallaCasa extends ConsumerWidget {
  const PantallaCasa({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TemaModulo(
    modulo: Modulo.casa,
    child: MarcoPantalla(
      titulo: 'Casa',
      cuerpo: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            key: const ValueKey('pantalla-casa'),
            padding: const EdgeInsets.all(16),
            children: const [
              _TarjetaPuente(),
              SizedBox(height: 16),
              _TarjetaFrases(),
              SizedBox(height: 16),
              _NotaDeLimites(),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TarjetaPuente extends ConsumerWidget {
  const _TarjetaPuente();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final informe = ref.watch(estadoPuenteProvider);
    return Card(
      key: const ValueKey('tarjeta-puente'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Puente de casa', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'El puente es Home Assistant, en un equipo siempre encendido en '
              'la red de la casa. Es lo que deja que las bocinas contesten las '
              'frases de abajo.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            informe.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const _Estado(
                clave: 'estado-puente-error',
                icono: Icons.error_outline,
                titulo: 'No pude comprobar el puente',
                detalle: 'Inténtalo de nuevo en un momento.',
              ),
              data: (i) => switch (i.estado) {
                EstadoDelPuente.noConfigurado => const _Estado(
                  clave: 'estado-puente-vacio',
                  icono: Icons.router_outlined,
                  titulo: 'Aún no hay puente configurado',
                  detalle:
                      'Mientras no lo haya, las bocinas no responden a GRAVITY. '
                      'Lo configura el dueño (pasos abajo); la app no guarda '
                      'ningún token.',
                ),
                EstadoDelPuente.sinRespuesta => _Estado(
                  clave: 'estado-puente-sin-respuesta',
                  icono: Icons.cloud_off_outlined,
                  titulo: 'El puente no responde',
                  detalle:
                      'Revisa que Home Assistant esté encendido y en el Wi-Fi '
                      'de la casa.${_ultima(i.ultimaRespuesta)}',
                ),
                EstadoDelPuente.conectado => _Estado(
                  clave: 'estado-puente-conectado',
                  icono: Icons.check_circle_outline,
                  titulo: 'Puente conectado',
                  detalle: _ultima(i.ultimaRespuesta).trim().isEmpty
                      ? 'Las bocinas pueden contestar las frases fijas.'
                      : _ultima(i.ultimaRespuesta).trim(),
                ),
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('volver-a-comprobar-puente'),
                onPressed: () => ref.invalidate(estadoPuenteProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Volver a comprobar'),
              ),
            ),
            ExpansionTile(
              key: const ValueKey('como-configurar-puente'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Cómo configurarlo'),
              children: [
                for (var i = 0; i < pasosParaConfigurarPuente.length; i++)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 12,
                      child: Text('${i + 1}', style: tema.textTheme.labelSmall),
                    ),
                    title: Text(pasosParaConfigurarPuente[i]),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Guía completa: docs/modulos/casa-puente.md.',
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _ultima(DateTime? cuando) {
    if (cuando == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return ' Última respuesta: ${dos(cuando.hour)}:${dos(cuando.minute)}.';
  }
}

class _Estado extends StatelessWidget {
  const _Estado({
    required this.clave,
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final String clave;
  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Row(
        key: ValueKey(clave),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 32, color: tema.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: tema.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(detalle, style: tema.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Descripción corta de lo que hace una frase (la de su herramienta).
String _queHace(FraseFija frase) {
  for (final herramienta in herramientasVozAlimentacion) {
    if (herramienta.nombre == frase.herramienta) return herramienta.descripcion;
  }
  return 'Frase aprobada.';
}

/// Quién puede usar una frase, para decirlo en la lista.
String _quienes(FraseFija frase) =>
    (frase.roles.toList()..sort((a, b) => a.index.compareTo(b.index)))
        .map(nombreRol)
        .join(', ');

class _TarjetaFrases extends StatelessWidget {
  const _TarjetaFrases();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      key: const ValueKey('tarjeta-frases'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Frases para las bocinas', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Son frases fijas: las bocinas solo entienden estas. Cualquier '
              'otra no hace nada.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            for (final frase in frasesFijas)
              ListTile(
                key: ValueKey('frase-${frase.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.record_voice_over_outlined),
                title: Text('“Hey Google, ${frase.texto}”'),
                subtitle: Text(
                  '${_queHace(frase)}\nQuién: ${_quienes(frase)}.',
                ),
                isThreeLine: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _NotaDeLimites extends StatelessWidget {
  const _NotaDeLimites();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      key: const ValueKey('nota-limites-bocina'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: tema.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Por las bocinas nunca se dicen montos de dinero ni datos '
                'clínicos, ni nombres de medicamentos o de personas. Lo que '
                'se dice pasa por Google, así que GRAVITY descarta antes de '
                'enviar cualquier texto con cifras, dinero, términos de '
                'salud, enlaces o más de '
                '${FiltroBocina.maximoCaracteres} caracteres. Las bocinas '
                'siempre llegan como la cuenta Casa: la voz no identifica a '
                'nadie.',
                style: tema.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
