/// Lector de código de barras con la cámara (solo Android). La cámara y su
/// permiso se abren únicamente cuando la persona toca "Escanear".
library;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'lector_codigo.dart';

/// Abre una pantalla con la cámara y devuelve el primer código leído, o
/// `null` si la persona vuelve atrás o no hay permiso. El permiso de cámara
/// lo pide `mobile_scanner` al iniciar el controlador, dentro de [leer].
class LectorCodigoCamara implements LectorCodigo {
  /// [contexto] da un contexto con navegador; se consulta al tocar "Escanear".
  const LectorCodigoCamara(this.contexto);
  final BuildContext? Function() contexto;

  @override
  Future<String?> leer() async {
    final ctx = contexto();
    if (ctx == null || !ctx.mounted) return null;
    return Navigator.of(ctx, rootNavigator: true).push<String>(
      MaterialPageRoute(builder: (_) => const PantallaEscanerCodigo()),
    );
  }
}

/// Pantalla de escaneo. Se cierra con el primer código no vacío.
class PantallaEscanerCodigo extends StatefulWidget {
  const PantallaEscanerCodigo({super.key});

  @override
  State<PantallaEscanerCodigo> createState() => _EstadoEscaner();
}

class _EstadoEscaner extends State<PantallaEscanerCodigo> {
  final _controlador = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.qrCode,
    ],
  );
  bool _listo = false;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _alLeer(BarcodeCapture captura) {
    if (_listo) return;
    for (final b in captura.barcodes) {
      final v = b.rawValue?.trim();
      if (v != null && v.isNotEmpty) {
        _listo = true;
        Navigator.of(context).pop(v);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear código')),
    body: MobileScanner(
      controller: _controlador,
      onDetect: _alLeer,
      errorBuilder: (context, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error.errorCode == MobileScannerErrorCode.permissionDenied
                ? 'Sin permiso de cámara. Puedes capturar el código a mano.'
                : 'No se pudo abrir la cámara. Puedes capturar el código a mano.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
