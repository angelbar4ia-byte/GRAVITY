/// Lo que cada persona puede hacer en Cuidados, según la sección 5 de
/// `docs/specs/fase-5-cuidados.md`. Es solo el espejo para ocultar en la
/// interfaz: el servidor (RLS) decide (D5).
library;

import '../../../nucleo/contratos/roles.dart';
import '../datos/modelos.dart';

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

  bool get _dueno => rol == Rol.dueno;
  bool get _cuidador => rol == Rol.cuidador;
  bool get _pareja => rol == Rol.coadministrador;

  /// Cuidadora principal (no la hermana): marca y registra.
  bool get _cuidadora => _cuidador && !perfil.esFamiliar;
  bool get _escribe => !esMaestra || _dueno;

  /// Entra a Cuidados. La pareja solo con consentimiento; los demás roles
  /// (familiar, casa) no.
  bool get entra => _dueno || _cuidador || (_pareja && perfil.consentimiento);

  bool get veTurno => entra;
  bool get veMedicamentos => entra;
  bool get veComidas => entra;
  bool get marcaToma => _escribe && (_dueno || _cuidadora);
  bool get registraComida => _escribe && (_dueno || _cuidadora);
  bool get dejaEntrega => _escribe && (_dueno || _cuidador);

  /// Bitácora clínica: nunca para la pareja (aun con consentimiento, §4).
  bool get veBitacora => _dueno || _cuidador;
  bool get escribeBitacora => _escribe && (_dueno || _cuidador);

  /// La cuidadora y la hermana solo ven lo que ellas escribieron.
  bool get soloLoPropioEnBitacora => _cuidador;

  bool get veGastos => _dueno || _cuidador || (_pareja && perfil.consentimiento);
  bool get registraGasto => _escribe && (_dueno || _cuidador || _pareja);
  bool get confirmaGasto => _dueno && !esMaestra;

  /// Resumen mensual: el dueño completo; la hermana solo con autorización.
  bool get veResumen => _dueno || (_cuidador && perfil.esFamiliar);
  bool get resumenDisponible =>
      _dueno || (_cuidador && perfil.esFamiliar && perfil.resumenAutorizado);
  bool get resumenSinMontosDelDueno => !_dueno;

  /// Laptop del dueño: medicamentos, citas, turnos, cuidadoras.
  bool get administra => _dueno && !esMaestra;
  bool get creaCambioUrgente => administra;
  bool get veCambiosUrgentes => _dueno || _cuidadora;
  bool get atiendeCambioUrgente => _escribe && (_dueno || _cuidadora);
}
