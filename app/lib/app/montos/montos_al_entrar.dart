/// En la tablet, **entrar con el PIN ya cuenta como haber pedido ver los
/// montos** (decisión del dueño, 23/oct/2026, D18): la persona que entró ve
/// sus montos de una vez, sin que se le pida el PIN otra vez para revelarlos.
///
/// Todo lo demás de los montos ocultos sigue igual: tras el tiempo sin uso
/// ([OcultarMontosPorInactividad]) se ocultan solos y volver a verlos pide el
/// PIN (`revelarMontos`); el modo privado los oculta; al cambiar la persona en
/// pantalla vuelven a su estado inicial. En el teléfono y la laptop no cambia
/// nada: allí los montos se abren ocultos.
///
/// Es el estado inicial de `montosVisiblesProvider` del sistema de diseño
/// (diseno no cambia: este notifier lo sustituye en el arranque, ver
/// `conexionesDeLaApp`). La firma de `revelarMontosProvider` y de
/// `revelarMontos(context)` no cambió.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../diseno/proveedores.dart'
    show MontosVisibles, personaEnPantallaProvider;
import '../../nucleo/tablet/controlador_tablet.dart';

class MontosVisiblesAlEntrar extends MontosVisibles {
  @override
  bool build() {
    final persona = ref.watch(personaEnPantallaProvider);
    // Quien entró con su PIN en la tablet (nadie, en los demás equipos).
    final entroConPin = ref.watch(
      controladorTabletProvider.select((e) => e.usuarioActivo?.personaId),
    );
    return persona != null && persona == entroConPin;
  }
}
