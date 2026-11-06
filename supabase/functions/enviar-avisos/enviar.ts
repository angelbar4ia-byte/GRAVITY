// Núcleo de la Edge Function enviar-avisos (sin APIs de Deno: se prueba con Deno o con Node).
//
// Lo único que viaja por Firebase es { v, id }: un identificador opaco del aviso. Nada de tipo,
// libro, persona, monto ni texto (D3, D20). El dispositivo lee su propia fila de `avisos` con su
// sesión (RLS) y arma el texto del catálogo; sin señal o sin sesión muestra el genérico.

export interface Fila {
  aviso_id: string;
  intentos: number;
  dispositivo_id: string;
  token: string;
}

export interface Dependencias {
  /** Llama a una función SQL (PostgREST /rpc) con la clave de servicio. */
  rpc(nombre: string, args: Record<string, unknown>): Promise<unknown>;
  /** fetch hacia FCM. */
  fetch: typeof fetch;
  /** Token OAuth2 de la cuenta de servicio de Firebase. */
  tokenAcceso(): Promise<string>;
  /** Id del proyecto de Firebase. */
  proyectoFcm: string;
}

export interface Resumen {
  avisos: number;
  entregas: number;
  ok: number;
  tokenInvalido: number;
  error: number;
}

export type Resultado = "ok" | "token_invalido" | "error";

/** El cuerpo EXACTO que se manda a FCM HTTP v1: mensaje solo de datos, prioridad alta. */
export function mensajeFcm(token: string, id: string) {
  return {
    message: {
      token,
      data: { v: "1", id },
      android: { priority: "HIGH", collapse_key: id },
    },
  };
}

/** Clasifica la respuesta de FCM. */
export async function clasificar(r: Response): Promise<{ resultado: Resultado; codigo: string }> {
  if (r.ok) return { resultado: "ok", codigo: "200" };
  let cuerpo: any = null;
  try {
    cuerpo = await r.json();
  } catch {
    cuerpo = null;
  }
  const estado = String(cuerpo?.error?.status ?? "");
  const detalle = JSON.stringify(cuerpo?.error?.details ?? []);
  // UNREGISTERED / NOT_FOUND: el token ya no existe. INVALID_ARGUMENT: el token es inválido
  // (el cuerpo que mandamos es fijo, así que el único argumento variable es el token).
  if (r.status === 404 || estado === "NOT_FOUND" || estado === "INVALID_ARGUMENT" || detalle.includes("UNREGISTERED")) {
    return { resultado: "token_invalido", codigo: (estado || String(r.status)).slice(0, 60) };
  }
  return { resultado: "error", codigo: (estado || String(r.status)).slice(0, 60) };
}

/** Reclama un lote (skip locked en SQL), envía y registra el resultado. */
export async function enviarLote(dep: Dependencias, limite = 200): Promise<Resumen> {
  const resumen: Resumen = { avisos: 0, entregas: 0, ok: 0, tokenInvalido: 0, error: 0 };
  const filas = (await dep.rpc("avisos_reclamar", { p_limite: Math.min(limite, 200) })) as Fila[] | null;
  if (!filas || filas.length === 0) return resumen;

  const porAviso = new Map<string, Fila[]>();
  for (const f of filas) {
    const lista = porAviso.get(f.aviso_id) ?? [];
    lista.push(f);
    porAviso.set(f.aviso_id, lista);
  }
  const acceso = await dep.tokenAcceso();
  const url = `https://fcm.googleapis.com/v1/projects/${dep.proyectoFcm}/messages:send`;

  for (const [avisoId, destinos] of porAviso) {
    resumen.avisos++;
    let alguno = false;
    for (const d of destinos) {
      let resultado: Resultado;
      let codigo: string;
      try {
        const r = await dep.fetch(url, {
          method: "POST",
          headers: { "Authorization": `Bearer ${acceso}`, "Content-Type": "application/json" },
          body: JSON.stringify(mensajeFcm(d.token, avisoId)),
        });
        ({ resultado, codigo } = await clasificar(r));
      } catch (e) {
        resultado = "error";
        codigo = "red";
      }
      resumen.entregas++;
      if (resultado === "ok") {
        resumen.ok++;
        alguno = true;
      } else if (resultado === "token_invalido") resumen.tokenInvalido++;
      else resumen.error++;
      await dep.rpc("avisos_registrar_entrega", {
        p_aviso_id: avisoId,
        p_dispositivo_id: d.dispositivo_id,
        p_resultado: resultado,
        p_codigo: codigo,
      });
    }
    await dep.rpc("avisos_resultado_envio", { p_aviso_id: avisoId, p_ok: alguno });
  }
  return resumen;
}
