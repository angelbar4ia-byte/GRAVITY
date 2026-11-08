// Adaptador de Google (OAuth 2.0 por usuario, Gmail y Calendar). Sin Deno y sin red directa: el `fetch` entra por
// parámetro, así se prueba con un Google falso (google_test.ts). Los secretos (GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET)
// llegan por parámetro desde el servidor; aquí no hay valores reales.

export type Fetch = (url: string, init?: { method?: string; headers?: Record<string, string>; body?: string }) => Promise<Response>;

export interface ConfigGoogle {
  clientId: string;
  clientSecret: string;
  /** URI de redirección registrada en Google Cloud (GOOGLE_REDIRECT_URI). */
  redirectUri: string;
}

/** Alcances mínimos. gmail.compose permite crear borradores y enviarlos; no lee ni borra correo. */
export const ALCANCES = {
  personal: [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.compose",
    "https://www.googleapis.com/auth/calendar.events",
    "https://www.googleapis.com/auth/userinfo.email",
  ],
  // La casa solo necesita ver su calendario: ni Gmail ni escritura.
  casa: ["https://www.googleapis.com/auth/calendar.events.readonly", "https://www.googleapis.com/auth/userinfo.email"],
} as const;

export class ErrorGoogle extends Error {
  readonly estado: number;
  /** `invalid_grant`: la persona revocó el acceso o caducó; hay que reconectar. */
  readonly caducada: boolean;
  constructor(estado: number, caducada = false) {
    // Sin el cuerpo de la respuesta: puede traer contenido del correo.
    super(`Google respondió ${estado}.`);
    this.name = "ErrorGoogle";
    this.estado = estado;
    this.caducada = caducada;
  }
}

export interface TokensGoogle {
  accessToken: string;
  refreshToken?: string;
  alcances: string[];
}

export function urlAutorizacion(cfg: ConfigGoogle, ambito: "personal" | "casa", estado: string): string {
  const q = new URLSearchParams({
    client_id: cfg.clientId,
    redirect_uri: cfg.redirectUri,
    response_type: "code",
    scope: ALCANCES[ambito].join(" "),
    access_type: "offline",
    prompt: "consent",
    include_granted_scopes: "false",
    state: estado,
  });
  return `https://accounts.google.com/o/oauth2/v2/auth?${q}`;
}

async function pedirToken(f: Fetch, cuerpo: Record<string, string>): Promise<any> {
  const r = await f("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(cuerpo).toString(),
  });
  if (!r.ok) {
    let caducada = false;
    try {
      caducada = (await r.json())?.error === "invalid_grant";
    } catch { /* sin cuerpo */ }
    throw new ErrorGoogle(r.status, caducada);
  }
  return r.json();
}

export async function intercambiarCodigo(f: Fetch, cfg: ConfigGoogle, codigo: string): Promise<TokensGoogle> {
  const j = await pedirToken(f, {
    code: codigo,
    client_id: cfg.clientId,
    client_secret: cfg.clientSecret,
    redirect_uri: cfg.redirectUri,
    grant_type: "authorization_code",
  });
  return { accessToken: String(j.access_token), refreshToken: j.refresh_token ? String(j.refresh_token) : undefined, alcances: String(j.scope ?? "").split(" ").filter(Boolean) };
}

export async function renovarAcceso(f: Fetch, cfg: ConfigGoogle, refreshToken: string): Promise<string> {
  const j = await pedirToken(f, {
    refresh_token: refreshToken,
    client_id: cfg.clientId,
    client_secret: cfg.clientSecret,
    grant_type: "refresh_token",
  });
  return String(j.access_token);
}

export async function correoDeLaCuenta(f: Fetch, acceso: string): Promise<string> {
  const r = await f("https://openidconnect.googleapis.com/v1/userinfo", { headers: { Authorization: `Bearer ${acceso}` } });
  if (!r.ok) throw new ErrorGoogle(r.status);
  const j = await r.json();
  return String(j.email ?? "");
}

// --- Correo y calendario -----------------------------------------------------------------------------------------

export interface CorreoResumen {
  id: string;
  de: string;
  asunto: string;
  fecha: string;
  fragmento: string;
}
export interface BorradorEntrada {
  para: string;
  asunto: string;
  cuerpo: string;
}
export interface EventoResumen {
  id: string;
  titulo: string;
  inicio: string;
  fin: string;
  lugar: string;
}
export interface EventoEntrada {
  titulo: string;
  inicio: string;
  fin: string;
  descripcion?: string;
  lugar?: string;
}

const base64url = (s: string) => {
  const bytes = new TextEncoder().encode(s);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};
const b64 = (s: string) => {
  const bytes = new TextEncoder().encode(s);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
};

export const CORREO_VALIDO = /^[^\s@<>",;]+@[^\s@<>",;]+\.[^\s@<>",;]+$/;

/** Mensaje MIME simple. Rechaza saltos de línea en los encabezados (inyección de encabezados). */
export function armarMime(e: BorradorEntrada): string {
  if (!CORREO_VALIDO.test(e.para)) throw new Error("destinatario_invalido");
  if (/[\r\n]/.test(e.asunto) || /[\r\n]/.test(e.para)) throw new Error("encabezado_invalido");
  const asunto = /^[\x20-\x7e]*$/.test(e.asunto) ? e.asunto : `=?UTF-8?B?${b64(e.asunto)}?=`;
  const cuerpo = e.cuerpo.replace(/\r?\n/g, "\r\n");
  return [`To: ${e.para}`, `Subject: ${asunto}`, "MIME-Version: 1.0", "Content-Type: text/plain; charset=UTF-8", "Content-Transfer-Encoding: base64", "", b64(cuerpo)].join("\r\n");
}

export class ClienteGoogle {
  private readonly f: Fetch;
  private readonly acceso: string;
  constructor(f: Fetch, acceso: string) {
    this.f = f;
    this.acceso = acceso;
  }

  private async llamar(url: string, init: { method?: string; body?: unknown } = {}): Promise<any> {
    const r = await this.f(url, {
      method: init.method ?? "GET",
      headers: { Authorization: `Bearer ${this.acceso}`, "Content-Type": "application/json" },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
    });
    if (!r.ok) throw new ErrorGoogle(r.status, r.status === 401);
    return r.status === 204 ? {} : r.json();
  }

  async listarCorreos(max = 10): Promise<CorreoResumen[]> {
    const n = Math.min(Math.max(Math.trunc(max), 1), 20);
    const lista = await this.llamar(`https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=${n}&labelIds=INBOX`);
    const salida: CorreoResumen[] = [];
    for (const m of (lista.messages ?? []).slice(0, n)) {
      const d = await this.llamar(
        `https://gmail.googleapis.com/gmail/v1/users/me/messages/${encodeURIComponent(m.id)}?format=metadata&metadataHeaders=From&metadataHeaders=Subject&metadataHeaders=Date`,
      );
      const h = (nombre: string) => String((d.payload?.headers ?? []).find((x: any) => x.name?.toLowerCase() === nombre)?.value ?? "");
      salida.push({ id: String(m.id), de: h("from"), asunto: h("subject"), fecha: h("date"), fragmento: String(d.snippet ?? "") });
    }
    return salida;
  }

  async crearBorrador(e: BorradorEntrada): Promise<string> {
    const j = await this.llamar("https://gmail.googleapis.com/gmail/v1/users/me/drafts", {
      method: "POST",
      body: { message: { raw: base64url(armarMime(e)) } },
    });
    return String(j.id);
  }

  async enviarBorrador(id: string): Promise<void> {
    await this.llamar("https://gmail.googleapis.com/gmail/v1/users/me/drafts/send", { method: "POST", body: { id } });
  }

  async verEventos(desdeIso: string, hastaIso: string, max = 25): Promise<EventoResumen[]> {
    const q = new URLSearchParams({ timeMin: desdeIso, timeMax: hastaIso, singleEvents: "true", orderBy: "startTime", maxResults: String(Math.min(max, 50)) });
    const j = await this.llamar(`https://www.googleapis.com/calendar/v3/calendars/primary/events?${q}`);
    return (j.items ?? []).map((x: any) => ({
      id: String(x.id),
      titulo: String(x.summary ?? "(sin título)"),
      inicio: String(x.start?.dateTime ?? x.start?.date ?? ""),
      fin: String(x.end?.dateTime ?? x.end?.date ?? ""),
      lugar: String(x.location ?? ""),
    }));
  }

  async crearEvento(e: EventoEntrada): Promise<string> {
    const j = await this.llamar("https://www.googleapis.com/calendar/v3/calendars/primary/events", {
      method: "POST",
      body: { summary: e.titulo, description: e.descripcion, location: e.lugar, start: { dateTime: e.inicio }, end: { dateTime: e.fin } },
    });
    return String(j.id);
  }
}
