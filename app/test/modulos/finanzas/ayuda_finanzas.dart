/// Ayuda para las pruebas de Finanzas: el hogar de ejemplo (Ana y Alex,
/// "Papá (ejemplo)") en un repositorio en memoria y el servicio con la hora
/// fija. Datos ilustrativos, nunca reales.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

/// Martes 20 de octubre de 2026, 10:00 (la hora de las pruebas de la app).
final ahoraDePrueba = DateTime(2026, 10, 20, 10);
final hoyDePrueba = Fecha.deDateTime(ahoraDePrueba);

/// Todos los adultos con Finanzas del ejemplo.
final adultosDeEjemplo = {IdsDemostracion.dueno, IdsDemostracion.pareja};

/// Cuenta maestra de ejemplo: una cuenta aparte con rol de dueño.
const personaMaestra = Persona(
  id: '00000000-0000-4000-8000-0000000000f1',
  nombre: 'Cuenta maestra de ejemplo',
);

Sesion sesionDe(Rol rol, {bool maestra = false}) => maestra
    ? Sesion(
        persona: personaMaestra,
        rol: rol,
        hogarId: hogarDeEjemplo,
        esMaestra: true,
      )
    : sesionDeEjemplo(rol);

/// Repositorio en memoria con lo que vería [sesion] (como la RLS).
RepositorioFinanzasEnMemoria repositorioDe(Sesion sesion) {
  final datos = filtrarParaPersona(
    datosDeDemostracion(hoy: hoyDePrueba),
    sesion.persona.id,
    hoy: hoyDePrueba,
    esMaestra: sesion.esMaestra,
  );
  return RepositorioFinanzasEnMemoria(
    datos: datos,
    personaId: sesion.persona.id,
    personas: {
      ...personasDeDemostracion(),
      personaMaestra.id: personaMaestra.nombre,
    },
    esMaestra: sesion.esMaestra,
    cuentaMaestra: sesion.esMaestra ? null : 'Cuenta maestra de ejemplo',
    adultosConFinanzas: sesion.rol == Rol.dueno
        ? adultosDeEjemplo
        : {sesion.persona.id},
  );
}

/// Repositorio vacío (hogar sin configurar) del dueño.
RepositorioFinanzasEnMemoria repositorioVacio() => RepositorioFinanzasEnMemoria(
  personaId: IdsDemostracion.dueno,
  personas: personasDeDemostracion(),
  adultosConFinanzas: adultosDeEjemplo,
);

ServicioFinanzas servicioDe(
  RepositorioFinanzas repo,
  Sesion sesion, {
  DateTime? ahora,
}) => ServicioFinanzas(
  repositorio: repo,
  personaId: sesion.persona.id,
  hogarId: sesion.hogarId ?? hogarDeEjemplo,
  esMaestra: sesion.esMaestra,
  reloj: () => ahora ?? ahoraDePrueba,
);

extension LecturaDeRepo on RepositorioFinanzasEnMemoria {
  DatosFinanzas get datos => actual.datos;

  Cuenta cuentaDe(String libroId, String nombre) =>
      datos.cuentasDe(libroId).firstWhere((c) => c.nombre == nombre);
}

/// Hogar recién creado: sus libros y cuentas propias, pero sin categorías,
/// cuentas de gasto, compromisos ni movimientos (antes de importar la
/// plantilla).
RepositorioFinanzasEnMemoria repositorioSinCategorias(Sesion sesion) {
  final completo = filtrarParaPersona(
    datosDeDemostracion(hoy: hoyDePrueba),
    sesion.persona.id,
    hoy: hoyDePrueba,
    esMaestra: sesion.esMaestra,
  );
  return RepositorioFinanzasEnMemoria(
    datos: completo.copiar(
      categorias: const [],
      cuentas: [
        for (final c in completo.cuentas)
          if (c.libroId != null) c,
      ],
      compromisos: const [],
      sobres: const [],
      semanas: const [],
      movimientos: const [],
    ),
    personaId: sesion.persona.id,
    personas: personasDeDemostracion(),
    adultosConFinanzas: adultosDeEjemplo,
  );
}
