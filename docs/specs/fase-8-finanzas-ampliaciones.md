# Fase 8 · Bloque 1: Finanzas (ampliaciones)

> v1.0, 8/nov/2026. Aprobada para construir transferencias, casa con subcuentas, registro de aportantes y periodo de la aportación. La conciliación del PDF queda pendiente de saber los bancos. Base: D19 (libros por persona, albaceas), D24 (vista de Papá), D25, D28 (despensas) y las respuestas del dueño de hoy.

## Alcance del bloque 1

1. **Modo pareja y familiar:** transferencias entre personas con **confirmación del receptor**.
2. **Aportación a la casa:** reparto de referencia **50% Papá, 50% dueño y pareja**; la aportación es **libre, no obligatoria**.
3. **Conciliación con estados de cuenta:** los archivos del banco se procesan **solo en la laptop** y **no se suben** a la nube.

Quedan para bloques posteriores (ya en el roadmap): simulador de deudas, estimador de intereses, beneficios de tarjetas, inversión, objetivos y plan, bienes y previsión, reportes, y voz e imagen en el teléfono.

## 1. Transferencias entre personas

- Una persona propone una transferencia a otra (por ejemplo, tú a tu pareja, o la pareja a la casa).
- El **receptor confirma** antes de que el movimiento quede en ambos libros. Sin confirmación, no hay movimiento.
- Ambas personas quedan en la bitácora (quién, cuándo; sin montos fuera de sus libros).
- Ninguna transferencia cambia el libro de Papá sin el albacea (D19).
- Dinero en centavos; libro solo-agregar: una transferencia rechazada o cancelada queda como registro, no se borra.

### Quién transfiere a quién (respuesta del dueño, 8/nov/2026)

- **Pareja → dueño**, **dueño → casa** y **pareja → casa** directamente.
- Cada transferencia la **confirma el receptor**.

### Estructura de cuentas de la casa (respuesta del dueño)

- **Casa** es la **cuenta general**. Sus **subcuentas** son los servicios y gastos (luz, teléfono, etc.).
- **Quien paga un servicio no importa:** el pago se registra en la subcuenta del servicio y la cuenta de casa lleva el **registro de quién aportó** a cada pago.
- Cada aportación queda atribuida a una persona (dueño, pareja o Papá), con monto y fecha, para el reparto de referencia.

## 2a. Periodo de la aportación (respuesta del dueño, 8/nov/2026)

- El periodo de referencia es **configurable**: semana, mes, bimestre, semestre o año.
- La referencia depende del **ingreso de cada persona** y de las **fechas límite de pago** de cada cuenta o subcuenta (servicios), para que la aportación caiga antes de cada vencimiento.
- Los ingresos son datos personales: se guardan en el dispositivo o en el servidor con RLS por persona; no salen a la IA ni a las bocinas (D3).

## 2. Aportación a la casa

- **Referencia:** 50% de la aportación corresponde a Papá y 50% a ti y tu pareja (partes iguales entre ustedes dos).
- **Libre:** cada quien aporta lo que quiera; no hay obligación ni deuda por no aportar.
- La app muestra la **aportación de referencia** y lo aportado, sin marcar a nadie como deudor.
- Las aportaciones de Papá pasan por el albacea (D19).

## 3. Conciliación con estados de cuenta

- Se procesan **en la laptop**. Los archivos del banco **no se suben** a ningún servidor ni a la nube.
- Formato: **PDF** (los bancos entregan sus estados así). La lectura del PDF se hace en la laptop; el PDF nunca sale de ella.
- Cada línea del estado se compara con los movimientos registrados: **coincide**, **falta en la app** o **falta en el banco**. Nada se borra; las diferencias se resuelven con un movimiento nuevo (solo-agregar).
- Las cifras del estado no salen a la IA ni a las bocinas (D3).

## Preguntas abiertas

2. **Bancos:** ¿qué bancos usas? (para ajustar la lectura del PDF de cada uno)

## Trabajo por agente (aprobado)

- **finanzas:** transferencias con confirmación, aportación de referencia y conciliación en la laptop.
- **backend:** tablas y RPC de transferencias, reglas por cuenta (D19), bitácora sin montos.
- **plataforma:** lector de archivos locales en la laptop y aviso de transferencia pendiente.
- **calidad:** revisión al cierre (D3, D19, D24).
