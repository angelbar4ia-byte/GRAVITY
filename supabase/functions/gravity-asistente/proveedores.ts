// Adaptadores de proveedores de IA. Todos reciben el mismo ContextoIa (ya filtrado, contexto.ts) y
// devuelven {texto, herramienta}. La clave NUNCA se guarda aquí: llega por parámetro desde el secreto
// del servidor y viaja en un encabezado (nunca en la URL, para que no quede en registros).
import type { ContextoIa } from "./contexto.ts";

export interface RespuestaIa {
  texto: string;
  /** Nombre (con punto, p. ej. "finanzas.abrir") de la herramienta elegida, o null. */
  herramienta: string | null;
}

export interface ProveedorIa {
  id: string;
  generar(contexto: ContextoIa, clave: string): Promise<RespuestaIa>;
}

export class ErrorProveedor extends Error {
  readonly estado: number;
  constructor(estado: number) {
    // Sin el cuerpo de la respuesta: podría repetir lo enviado.
    super(`El proveedor de IA respondió ${estado}.`);
    this.name = "ErrorProveedor";
    this.estado = estado;
  }
}

export type Fetch = (url: string, init: { method: string; headers: Record<string, string>; body: string }) => Promise<Response>;

/** Claude y ChatGPT no aceptan puntos en el nombre de una herramienta. */
export const aProveedor = (nombre: string) => nombre.replaceAll(".", "__");
export const deProveedor = (nombre: string) => nombre.replaceAll("__", ".");

const MAX_SALIDA = 400;
const PARAMETROS_VACIOS = { type: "object", properties: {} };

async function json(r: Response): Promise<any> {
  if (!r.ok) throw new ErrorProveedor(r.status);
  try {
    return await r.json();
  } catch {
    throw new ErrorProveedor(502);
  }
}

export function gemini(f: Fetch, modelo = "gemini-2.5-flash"): ProveedorIa {
  return {
    id: "gemini",
    async generar(c, clave) {
      const cuerpo: Record<string, unknown> = {
        systemInstruction: { parts: [{ text: c.sistema }] },
        contents: [
          ...c.historial.map((t) => ({ role: t.de === "persona" ? "user" : "model", parts: [{ text: t.texto }] })),
          { role: "user", parts: [{ text: c.mensaje }] },
        ],
        generationConfig: { maxOutputTokens: c.maxSalida ?? MAX_SALIDA, ...(c.formatoJson ? { responseMimeType: "application/json" } : {}) },
      };
      if (c.herramientas.length > 0) {
        cuerpo.tools = [{
          functionDeclarations: c.herramientas.map((h) => ({
            name: aProveedor(h.nombre),
            description: h.descripcion,
          })),
        }];
      }
      const r = await json(
        await f(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(modelo)}:generateContent`, {
          method: "POST",
          headers: { "content-type": "application/json", "x-goog-api-key": clave },
          body: JSON.stringify(cuerpo),
        }),
      );
      const partes: any[] = r?.candidates?.[0]?.content?.parts ?? [];
      const llamada = partes.find((p) => p?.functionCall?.name)?.functionCall?.name;
      return {
        texto: partes.map((p) => p?.text ?? "").join("").trim(),
        herramienta: llamada ? deProveedor(llamada) : null,
      };
    },
  };
}

export function claude(f: Fetch, modelo = "claude-haiku-4-5"): ProveedorIa {
  return {
    id: "claude",
    async generar(c, clave) {
      const cuerpo: Record<string, unknown> = {
        model: modelo,
        max_tokens: c.maxSalida ?? MAX_SALIDA,
        system: c.sistema,
        messages: [
          ...c.historial.map((t) => ({ role: t.de === "persona" ? "user" : "assistant", content: t.texto })),
          { role: "user", content: c.mensaje },
        ],
      };
      if (c.herramientas.length > 0) {
        cuerpo.tools = c.herramientas.map((h) => ({
          name: aProveedor(h.nombre),
          description: h.descripcion,
          input_schema: PARAMETROS_VACIOS,
        }));
      }
      const r = await json(
        await f("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: { "content-type": "application/json", "x-api-key": clave, "anthropic-version": "2023-06-01" },
          body: JSON.stringify(cuerpo),
        }),
      );
      const bloques: any[] = r?.content ?? [];
      const uso = bloques.find((b) => b?.type === "tool_use" && b?.name);
      return {
        texto: bloques.filter((b) => b?.type === "text").map((b) => b.text ?? "").join("").trim(),
        herramienta: uso ? deProveedor(uso.name) : null,
      };
    },
  };
}

export function chatgpt(f: Fetch, modelo = "gpt-4o-mini"): ProveedorIa {
  return {
    id: "chatgpt",
    async generar(c, clave) {
      const cuerpo: Record<string, unknown> = {
        model: modelo,
        max_tokens: c.maxSalida ?? MAX_SALIDA,
        messages: [
          { role: "system", content: c.sistema },
          ...c.historial.map((t) => ({ role: t.de === "persona" ? "user" : "assistant", content: t.texto })),
          { role: "user", content: c.mensaje },
        ],
      };
      if (c.herramientas.length > 0) {
        cuerpo.tools = c.herramientas.map((h) => ({
          type: "function",
          function: { name: aProveedor(h.nombre), description: h.descripcion, parameters: PARAMETROS_VACIOS },
        }));
      }
      const r = await json(
        await f("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          headers: { "content-type": "application/json", authorization: `Bearer ${clave}` },
          body: JSON.stringify(cuerpo),
        }),
      );
      const m = r?.choices?.[0]?.message;
      const llamada = m?.tool_calls?.[0]?.function?.name;
      return { texto: String(m?.content ?? "").trim(), herramienta: llamada ? deProveedor(llamada) : null };
    },
  };
}

/** Nombre del secreto del servidor de cada proveedor. */
export const SECRETO_DE: Record<string, string> = {
  gemini: "GEMINI_API_KEY",
  claude: "ANTHROPIC_API_KEY",
  chatgpt: "OPENAI_API_KEY",
};

export function crearProveedor(id: string, f: Fetch, modelo?: string): ProveedorIa | null {
  const m = modelo || undefined;
  switch (id) {
    case "gemini": return gemini(f, m);
    case "claude": return claude(f, m);
    case "chatgpt": return chatgpt(f, m);
    default: return null;
  }
}
