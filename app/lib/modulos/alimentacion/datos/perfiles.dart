/// Perfil de cada menú. **Dato clínico (D3, D23):** el perfil de Papá solo
/// vive en este módulo y lo ven quienes tienen permiso sobre ese menú; no se
/// expone a herramientas de IA, bocinas ni avisos con texto.
library;

import 'modelos.dart';

class PerfilMenu {
  const PerfilMenu({
    required this.titulo,
    required this.lineas,
    this.texturaBlanda = false,
  });
  final String titulo;
  final List<String> lineas;

  /// Si es `true`, al elegir un platillo con alimentos duros se advierte.
  final bool texturaBlanda;
}

PerfilMenu perfilDe(MenuId menu) => switch (menu) {
  MenuId.papa => const PerfilMenu(
    titulo: 'Adulto mayor con Alzheimer',
    lineas: [
      'Adulto de 80 años.',
      'Dieta alta en proteínas y aminoácidos.',
      'No puede comer alimentos duros; de preferencia blandos.',
    ],
    texturaBlanda: true,
  ),
  MenuId.pareja => const PerfilMenu(
    titulo: 'Pareja y dueño',
    lineas: ['Menú general del hogar.'],
  ),
};
