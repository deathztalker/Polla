// ============================================================
// config.js — POLLA MUNDIALERA 2026
// ⚠️  COMPLETA TUS CLAVES ANTES DE SUBIR A GITHUB PAGES
// ⚠️  NO subas este archivo con claves reales a repos públicos
//     Usa GitHub Secrets o variables de entorno para producción
// ============================================================

const CONFIG = {
  // ----------------------------------------------------------
  // SUPABASE
  // Obtén estas claves en: https://supabase.com/dashboard/project/_/settings/api
  // ----------------------------------------------------------
  SUPABASE_URL:      'https://TU-PROYECTO.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.TU_ANON_KEY',

  // ----------------------------------------------------------
  // API-FOOTBALL (datos de partidos en vivo)
  // Regístrate gratis en: https://www.api-football.com/
  // Plan gratuito: 100 requests/día (suficiente para desarrollo)
  // ----------------------------------------------------------
  API_FOOTBALL_KEY:  'TU_API_FOOTBALL_KEY',
  API_FOOTBALL_HOST: 'v3.football.api-sports.io',
  API_FOOTBALL_LIGA: 1,        // 1 = FIFA World Cup
  API_FOOTBALL_TEMPORADA: 2026,

  // ----------------------------------------------------------
  // SINCRONIZACIÓN AUTOMÁTICA
  // ----------------------------------------------------------
  SYNC_INTERVALO_MS: 5 * 60 * 1000,   // cada 5 minutos
  SYNC_EN_VIVO_MS:   60 * 1000,       // cada 1 min si hay partido en vivo

  // ----------------------------------------------------------
  // APP
  // ----------------------------------------------------------
  APP_NOMBRE:        'Polla Mundialera 2026',
  APP_ORGANIZACION:  'LATAM Airlines x NTT Data',
  APP_VERSION:       '1.0.0',
};

// Exportar para uso como módulo (si se usa bundler) o global
if (typeof module !== 'undefined') module.exports = CONFIG;
