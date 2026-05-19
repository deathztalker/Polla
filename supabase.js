// ============================================================
// supabase.js — Cliente Supabase (REST API, sin SDK)
// Vanilla JS puro — compatible con GitHub Pages
// ============================================================

class SupabaseClient {
  constructor(url, key) {
    this.url = url.replace(/\/$/, '');
    this.key = key;
    this.headers = {
      'apikey': key,
      'Authorization': `Bearer ${key}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
  }

  // ── GET ──────────────────────────────────────────────────
  async select(tabla, { columnas = '*', filtros = '', orden = '', limite = 1000, offset = 0 } = {}) {
    let url = `${this.url}/rest/v1/${tabla}?select=${columnas}`;
    if (filtros)  url += `&${filtros}`;
    if (orden)    url += `&order=${orden}`;
    if (limite)   url += `&limit=${limite}`;
    if (offset)   url += `&offset=${offset}`;

    const res = await fetch(url, { headers: { ...this.headers, 'Range-Unit': 'items', 'Range': `${offset}-${offset + limite - 1}` } });
    if (!res.ok) throw new Error(`Supabase SELECT error: ${res.status} ${await res.text()}`);
    return res.json();
  }

  // ── INSERT ───────────────────────────────────────────────
  async insert(tabla, datos) {
    const res = await fetch(`${this.url}/rest/v1/${tabla}`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify(datos),
    });
    if (!res.ok) throw new Error(`Supabase INSERT error: ${res.status} ${await res.text()}`);
    return res.json();
  }

  // ── UPDATE ───────────────────────────────────────────────
  async update(tabla, datos, filtro) {
    const res = await fetch(`${this.url}/rest/v1/${tabla}?${filtro}`, {
      method: 'PATCH',
      headers: this.headers,
      body: JSON.stringify(datos),
    });
    if (!res.ok) throw new Error(`Supabase UPDATE error: ${res.status} ${await res.text()}`);
    return res.json();
  }

  // ── UPSERT ───────────────────────────────────────────────
  async upsert(tabla, datos, onConflict = 'id') {
    const res = await fetch(`${this.url}/rest/v1/${tabla}?on_conflict=${onConflict}`, {
      method: 'POST',
      headers: { ...this.headers, 'Prefer': 'resolution=merge-duplicates,return=representation' },
      body: JSON.stringify(datos),
    });
    if (!res.ok) throw new Error(`Supabase UPSERT error: ${res.status} ${await res.text()}`);
    return res.json();
  }

  // ── RPC (funciones PostgreSQL) ────────────────────────────
  async rpc(funcion, params = {}) {
    const res = await fetch(`${this.url}/rest/v1/rpc/${funcion}`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify(params),
    });
    if (!res.ok) throw new Error(`Supabase RPC error: ${res.status} ${await res.text()}`);
    return res.json();
  }

  // ── VISTA ────────────────────────────────────────────────
  async vista(nombre, { orden = '', limite = 500 } = {}) {
    return this.select(nombre, { orden, limite });
  }

  // ── CHECK CONEXIÓN ────────────────────────────────────────
  async ping() {
    try {
      await this.select('config_torneo', { limite: 1 });
      return true;
    } catch {
      return false;
    }
  }
}

// ── Inicialización global
let db;

function initServices() {
  if (typeof CONFIG === 'undefined') {
    console.error('❌ Falta config.js — define CONFIG antes de cargar este script');
    return false;
  }
  db = new SupabaseClient(CONFIG.SUPABASE_URL, CONFIG.SUPABASE_ANON_KEY);
  console.log('✅ Supabase Client inicializado (Solo Lectura/Escritura RLS)');
  return true;
}

