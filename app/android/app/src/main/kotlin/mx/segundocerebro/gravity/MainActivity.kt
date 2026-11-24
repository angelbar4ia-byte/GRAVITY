package mx.segundocerebro.gravity

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// local_auth (huella para el bloqueo del teléfono, I8) necesita
// FlutterFragmentActivity.
//
// I11: FLAG_SECURE impide capturas y grabaciones y hace que el selector de
// apps ("recientes") muestre la ventana en blanco, que es la cubierta al pasar
// a segundo plano. La app lo enciende solo mientras hay pantallas con dinero
// (Finanzas) o datos clínicos (Cuidados) a la vista y lo apaga después
// (app/lib/nucleo/seguridad/pantalla_segura.dart).
//
// Fase 8 (H-14, aprobado el 24/nov/2026): FLAG_KEEP_SCREEN_ON mantiene la
// pantalla encendida durante la sesión de gimnasio. No pide ningún permiso; la
// bandera es de la ventana (si la app muere, el sistema la suelta). La app la
// enciende al empezar o retomar la sesión y la apaga al terminar, al cambiar de
// persona y al pasar a segundo plano
// (app/lib/nucleo/gimnasio/pantalla_encendida.dart).
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler { llamada, resultado ->
                when (llamada.method) {
                    "establecer" -> {
                        // Si no viene el dato, se protege: es lo más seguro.
                        establecerPantallaSegura(llamada.argument<Boolean>("segura") ?: true)
                        resultado.success(null)
                    }
                    else -> resultado.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_PANTALLA_ENCENDIDA)
            .setMethodCallHandler { llamada, resultado ->
                when (llamada.method) {
                    "establecer" -> {
                        // Si no viene el dato, se devuelve el control al
                        // sistema: es lo más seguro para la batería.
                        establecerPantallaEncendida(llamada.argument<Boolean>("encendida") ?: false)
                        resultado.success(null)
                    }
                    else -> resultado.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        // La bandera es de la ventana; se suelta de todos modos.
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        super.onDestroy()
    }

    private fun establecerPantallaEncendida(encendida: Boolean) {
        runOnUiThread {
            if (encendida) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    private fun establecerPantallaSegura(segura: Boolean) {
        runOnUiThread {
            if (segura) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    companion object {
        // Mismo nombre que ProtectorDePantallaAndroid.canalDelSistema (Dart).
        const val CANAL = "mx.segundocerebro.gravity/pantalla_segura"

        // Mismo nombre que PantallaEncendidaAndroid.canalDelSistema (Dart).
        const val CANAL_PANTALLA_ENCENDIDA = "mx.segundocerebro.gravity/pantalla_encendida"
    }
}
