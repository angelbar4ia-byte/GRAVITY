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
    }
}
