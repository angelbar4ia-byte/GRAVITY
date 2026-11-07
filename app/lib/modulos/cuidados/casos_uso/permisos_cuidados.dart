/// Lo que cada persona puede hacer en Cuidados, según la sección 5 de
/// `docs/specs/fase-5-cuidados.md`. Es solo el espejo para ocultar en la
/// interfaz: el servidor (`cui_puede`, RLS y las RPC) decide (D5).
library;

import '../../../nucleo/cuidados/turnos.dart';
import '../../../nucleo/contratos/roles.dart';
import '../datos/modelos.dart';

/// Espejo exacto de `cui_puede(hogar, objeto, accion)` del servidor
/// (migración `20261114`). [objeto]: turnos, medicamentos, tomas, comidas,
/// bitacora, entregas, cambios o gastos. [accion]: `leer` o `escribir`.
/// Las reglas por registro (los propios, para quien es) las aplica cada
/// repositorio.
bool cuiPuede(TipoPerfil? p, String objeto, String accion) {
  if (p == null) return false;
  const objetos = {
    'turnos',
    'medicamentos',
    'tomas',
    'comidas',
    'bitacora',
    'entregas',
    'cambios',
    'gastos',
  };
  if (!objetos.contains(objeto)) return false;
  final clinico = p != TipoPerfil.pareja;
  if (accion == 'leer') {
    return switch (objeto) {
      'turnos' || 'gastos' => true,
      'medicamentos' || 'tomas' || 'comidas' => clinico,
      _ =>
        p == TipoPerfil.dueno ||
            p == TipoPerfil.cuidadora ||
            p == TipoPerfil.hermana,
    };
  }
  if (accion != 'escribir') return false;
  return switch (objeto) {
    'turnos' || 'medicamentos' => p == TipoPerfil.dueno,
    'comidas' => p == TipoPerfil.dueno || p == TipoPerfil.cuidadora,
    'bitacora' || 'entregas' =>
      p == TipoPerfil.dueno ||
          p == TipoPerfil.cuidadora ||
          p == TipoPerfil.hermana,
    'gastos' => true,
    _ => false, // tomas y cambios urgentes solo cambian con su RPC
  };
}

class PermisosCuidados {
  const PermisosCuidados({
    required this.rol,
    this.perfil = const PerfilCuidados(),
    this.esMaestra = false,
  });

  final Rol rol;
  final PerfilCuidados perfil;

  /// Cuenta maestra (D19): solo lee.
  final bool esMaestra;

  /// Perfil en Cuidados: el de `cui_perfil` (por el tipo de sus turnos), no
  /// el rol de membresía.
  TipoPerfil? get tipo => perfil.efectivo(rol);

  bool get _dueno => tipo == TipoPerfil.dueno;
  bool get _cuidadora => tipo == TipoPerfil.cuidadora;
  bool get _hermana => tipo == TipoPerfil.hermana;
  bool get _pareja =>
      tipo == TipoPerfil.pareja || tipo == TipoPerfil.parejaConsentida;
  bool get _escribe => !esMaestra || _dueno;

  bool _lee(String o) => cuiPuede(tipo, o, 'leer');
  bool _escribeEn(String o) => _escribe && cuiPuede(tipo, o, 'escribir');

  /// Entra a la parte clínica de Cuidados. La pareja solo con consentimiento;
  /// Casa y quien no tiene perfil, no.
  bool get entra =>
      _dueno || _cuidadora || _hermana || tipo == TipoPerfil.parejaConsentida;

  /// Los turnos los lee todo perfil, también la pareja sin consentimiento.
  bool get veTurno => _lee('turnos');
  bool get veMedicamentos => _lee('medicamentos');
  bool get veComidas => _lee('comidas');

  /// El dueño y la cuidadora o la hermana **de turno a esa hora**
  /// (`cui_marcar_toma`; v1.2 de la especificación). El turno lo valida el
  /// servidor; aquí solo se decide quién puede intentarlo.
  bool get marcaToma => _escribe && (_dueno || _cuidadora || _hermana);

  /// Marcar una toma **a esta hora**: la hermana solo si quien está de turno es
  /// ella (v1.2). `quienEnTurno` es `cuidadorDeTurno(ahora)`.
  bool marcaTomaA(String quienEnTurno) =>
      marcaToma && (!_hermana || quienEnTurno == RolDeTurno.hermana);
  bool get registraComida => _escribeEn('comidas');
  bool get dejaEntrega => _escribeEn('entregas');

  /// Bitácora clínica: la pareja la ve solo con su consentimiento (v1.2, §8d).
  bool get veBitacora =>
      _lee('bitacora') || tipo == TipoPerfil.parejaConsentida;
  bool get escribeBitacora => _escribeEn('bitacora');

  /// Decisión pendiente (c): la cuidadora y la hermana ven solo lo que ellas
  /// escribieron. El servidor deja leer toda la bitácora a las dos.
  bool get soloLoPropioEnBitacora => _cuidadora || _hermana;

  bool get veGastos => _lee('gastos');
  bool get registraGasto => _escribeEn('gastos');
  bool get confirmaGasto => _dueno && !esMaestra;

  /// Resumen mensual: el dueño; la hermana solo con autorización.
  bool get veResumen => _dueno || _hermana;
  bool get resumenDisponible =>
      _dueno || (_hermana && perfil.resumenAutorizado);

  /// Resumen del día de Papá (conteos): todo perfil.
  bool get veResumenPapa => tipo != null;

  /// Laptop del dueño: medicamentos, citas, turnos, cuidadoras.
  bool get administra => _dueno && !esMaestra;
  bool get creaCambioUrgente => administra;
  bool get veCambiosUrgentes => _lee('cambios');
  bool get atiendeCambioUrgente =>
      _escribe && (_dueno || _cuidadora || _hermana);

  /// La pareja puede dar o retirar su consentimiento.
  bool get daConsentimiento => _pareja;
}
