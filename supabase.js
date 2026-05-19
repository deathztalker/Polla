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

// ============================================================
// API-Football client
// ============================================================
class APIFootballClient {
  constructor(key, host) {
    this.key  = key;
    this.host = host;
    this.base = `https://${host}`;
    this.headers = {
      'x-rapidapi-key':  key,
      'x-rapidapi-host': host,
    };
  }

  async _fetch(endpoint, params = {}) {
    const qs = new URLSearchParams(params).toString();
    const url = `${this.base}/${endpoint}${qs ? '?' + qs : ''}`;
    const res = await fetch(url, { headers: this.headers });
    if (!res.ok) throw new Error(`API-Football error: ${res.status}`);
    const data = await res.json();
    if (data.errors && Object.keys(data.errors).length > 0) {
      throw new Error(`API-Football errors: ${JSON.stringify(data.errors)}`);
    }
    return data.response;
  }

  // Partidos de una fecha
  async getFixtures({ liga, temporada, fecha, estado }) {
    const params = { league: liga, season: temporada };
    if (fecha)  params.date   = fecha;
    if (estado) params.status = estado;
    return this._fetch('fixtures', params);
  }

  // Partidos en vivo
  async getLive(liga) {
    return this._fetch('fixtures', { league: liga, live: 'all' });
  }

  // Tabla de posiciones
  async getStandings(liga, temporada) {
    return this._fetch('standings', { league: liga, season: temporada });
  }

  // Goleadores
  async getTopScorers(liga, temporada) {
    return this._fetch('players/topscorers', { league: liga, season: temporada });
  }
}

// ============================================================
// Servicio de sincronización
// ============================================================
class SyncService {
  constructor(supabase, apiFootball, config) {
    this.db  = supabase;
    this.api = apiFootball;
    this.cfg = config;
    this._timer     = null;
    this._timerLive = null;
    this.listeners  = [];
  }

  onSync(fn) { this.listeners.push(fn); }
  _notify(tipo, data) { this.listeners.forEach(fn => fn(tipo, data)); }

  // ── Sincronizar partidos (fixtures)
  async syncPartidos() {
    try {
      const fixtures = await this.api.getFixtures({
        liga: this.cfg.API_FOOTBALL_LIGA,
        temporada: this.cfg.API_FOOTBALL_TEMPORADA,
      });

      const registros = fixtures.map(f => ({
        api_id:           f.fixture.id,
        fase:             f.league.round || 'Fase de Grupos',
        fecha:            f.fixture.date,
        estadio:          f.fixture.venue?.name,
        ciudad:           f.fixture.venue?.city,
        goles_local:      f.goals?.home,
        goles_visita:     f.goals?.away,
        estado:           this._mapEstado(f.fixture.status?.short),
        minuto:           f.fixture.status?.elapsed,
      }));

      // Upsert por api_id
      for (const r of registros) {
        await this.db.upsert('partidos', r, 'api_id');
      }

      await this._logSync('partidos', 'ok', registros.length);
      this._notify('partidos', registros);
      return registros;
    } catch (e) {
      await this._logSync('partidos', 'error', 0, e.message);
      throw e;
    }
  }

  // ── Sincronizar tabla de grupos
  async syncGrupos() {
    try {
      const standings = await this.api.getStandings(
        this.cfg.API_FOOTBALL_LIGA,
        this.cfg.API_FOOTBALL_TEMPORADA
      );
      this._notify('grupos', standings);
      await this._logSync('grupos', 'ok', standings.length);
      return standings;
    } catch (e) {
      await this._logSync('grupos', 'error', 0, e.message);
      throw e;
    }
  }

  // ── Sincronizar goleadores
  async syncGoleadores() {
    try {
      const scorers = await this.api.getTopScorers(
        this.cfg.API_FOOTBALL_LIGA,
        this.cfg.API_FOOTBALL_TEMPORADA
      );

      for (const s of scorers.slice(0, 20)) {
        await this.db.update(
          'jugadores',
          { goles_mundial: s.statistics[0]?.goals?.total || 0 },
          `api_id=eq.${s.player.id}`
        );
      }

      await this._logSync('goleadores', 'ok', scorers.length);
      this._notify('goleadores', scorers);
      return scorers;
    } catch (e) {
      await this._logSync('goleadores', 'error', 0, e.message);
      throw e;
    }
  }

  // ── Sincronizar partidos en vivo
  async syncEnVivo() {
    try {
      const live = await this.api.getLive(this.cfg.API_FOOTBALL_LIGA);
      if (live.length > 0) {
        for (const f of live) {
          await this.db.update('partidos', {
            goles_local:  f.goals?.home,
            goles_visita: f.goals?.away,
            estado:       'en_vivo',
            minuto:       f.fixture.status?.elapsed,
          }, `api_id=eq.${f.fixture.id}`);
        }
        this._notify('en_vivo', live);
      }
      return live;
    } catch (e) {
      console.warn('Sync en vivo error:', e.message);
      return [];
    }
  }

  // ── Sync completa inicial
  async syncCompleta() {
    console.log('🔄 Iniciando sincronización completa...');
    try {
      await Promise.allSettled([
        this.syncPartidos(),
        this.syncGrupos(),
        this.syncGoleadores(),
      ]);
      await this.db.update('config_torneo', { valor: new Date().toISOString() }, "clave=eq.ultima_sync_api");
      console.log('✅ Sincronización completa OK');
    } catch (e) {
      console.error('❌ Error en sync completa:', e);
    }
  }

  // ── Iniciar polling automático
  iniciarPolling() {
    // Sync general cada 5 min
    this._timer = setInterval(() => this.syncPartidos(), this.cfg.SYNC_INTERVALO_MS);
    // Check en vivo cada 1 min
    this._timerLive = setInterval(() => this.syncEnVivo(), this.cfg.SYNC_EN_VIVO_MS);
    console.log('⏱️ Polling iniciado');
  }

  detenerPolling() {
    clearInterval(this._timer);
    clearInterval(this._timerLive);
  }

  _mapEstado(code) {
    const mapa = {
      'NS':'pendiente','TBD':'pendiente',
      '1H':'en_vivo','HT':'en_vivo','2H':'en_vivo',
      'ET':'en_vivo','BT':'en_vivo','P':'en_vivo',
      'FT':'finalizado','AET':'finalizado','PEN':'finalizado',
      'PST':'suspendido','CANC':'suspendido','ABD':'suspendido',
    };
    return mapa[code] || 'pendiente';
  }

  async _logSync(tipo, estado, registros, detalle = '') {
    try {
      await this.db.insert('sync_log', { tipo, estado, registros, detalle });
    } catch {}
  }
}

// ── Inicialización global
let db, apiF, syncSvc;

function initServices() {
  if (typeof CONFIG === 'undefined') {
    console.error('❌ Falta config.js — define CONFIG antes de cargar este script');
    return false;
  }
  db      = new SupabaseClient(CONFIG.SUPABASE_URL, CONFIG.SUPABASE_ANON_KEY);
  apiF    = new APIFootballClient(CONFIG.API_FOOTBALL_KEY, CONFIG.API_FOOTBALL_HOST);
  syncSvc = new SyncService(db, apiF, CONFIG);
  return true;
}
