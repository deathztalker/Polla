// ============================================================
// config.js — POLLA MUNDIALERA 2026
// Configuración de Supabase + API-Football
// ============================================================

const CONFIG = {
  // ----------------------------------------------------------
  // SUPABASE
  // ----------------------------------------------------------
  SUPABASE_URL:      'https://rkarxmetbktowmmxkfam.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJrYXJ4bWV0Ymt0b3dtbXhrZmFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5NDY3MjksImV4cCI6MjA5MTUyMjcyOX0.eVctkjVHkscDH_o6G_txKpo-3MOabmHJySbWdsZFnIE',

  // ----------------------------------------------------------
  // API-FOOTBALL: La sincronización se hace vía Edge Function
  // en Supabase (sync-football). No se necesita la key aquí.
  // ----------------------------------------------------------
  API_FOOTBALL_HOST: 'v3.football.api-sports.io',
  API_FOOTBALL_LIGA: 1,
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
