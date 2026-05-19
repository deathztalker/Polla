-- ============================================================
-- POLLA MUNDIALERA 2026 — LATAM x NTT DATA
-- Esquema completo para Supabase (PostgreSQL)
-- Ejecutar en el SQL Editor de Supabase
-- ============================================================

-- Extensión para UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. SELECCIONES (equipos del mundial)
-- ============================================================
CREATE TABLE selecciones (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  codigo        VARCHAR(3)   NOT NULL UNIQUE,  -- 'BRA', 'ARG', etc.
  nombre        VARCHAR(100) NOT NULL,
  nombre_corto  VARCHAR(50),
  bandera       VARCHAR(10),                   -- emoji
  grupo         VARCHAR(2),                    -- 'A','B',...'L'
  confederacion VARCHAR(10),                   -- 'CONMEBOL','UEFA', etc.
  api_id        INTEGER,                       -- ID en API-Football
  activo        BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. JUGADORES (para predicción de goleador)
-- ============================================================
CREATE TABLE jugadores (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre         VARCHAR(150) NOT NULL,
  nombre_corto   VARCHAR(80),
  seleccion_id   UUID REFERENCES selecciones(id) ON DELETE SET NULL,
  posicion       VARCHAR(30),
  api_id         INTEGER,
  goles_mundial  INTEGER DEFAULT 0,
  activo         BOOLEAN DEFAULT TRUE,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. PARTICIPANTES
-- ============================================================
CREATE TABLE participantes (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre           VARCHAR(100) NOT NULL,
  apellido         VARCHAR(100) NOT NULL,
  email            VARCHAR(200) NOT NULL UNIQUE,
  telefono         VARCHAR(20),
  alias            VARCHAR(100) NOT NULL,
  cuota_clp        INTEGER NOT NULL DEFAULT 5000,
  pagado           BOOLEAN DEFAULT FALSE,
  fecha_pago       TIMESTAMPTZ,
  puntos_total     INTEGER DEFAULT 0,
  activo           BOOLEAN DEFAULT TRUE,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT cuota_minima CHECK (cuota_clp >= 2000),
  CONSTRAINT cuota_maxima CHECK (cuota_clp <= 500000)
);

-- ============================================================
-- 4. PREDICCIONES PRINCIPALES (por participante)
-- ============================================================
CREATE TABLE predicciones (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  participante_id     UUID NOT NULL REFERENCES participantes(id) ON DELETE CASCADE,
  campeon_id          UUID REFERENCES selecciones(id),
  subcampeon_id       UUID REFERENCES selecciones(id),
  tercero_id          UUID REFERENCES selecciones(id),
  goleador_id         UUID REFERENCES jugadores(id),
  seleccion_sorpresa_id UUID REFERENCES selecciones(id),
  goles_total_pred    INTEGER,
  puntos_campeon      INTEGER DEFAULT 0,
  puntos_subcampeon   INTEGER DEFAULT 0,
  puntos_tercero      INTEGER DEFAULT 0,
  puntos_goleador     INTEGER DEFAULT 0,
  puntos_sorpresa     INTEGER DEFAULT 0,
  puntos_goles        INTEGER DEFAULT 0,
  calculado           BOOLEAN DEFAULT FALSE,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(participante_id)
);

-- ============================================================
-- 5. GRUPOS
-- ============================================================
CREATE TABLE grupos (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  letra      VARCHAR(2) NOT NULL UNIQUE,
  nombre     VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE grupo_selecciones (
  grupo_id      UUID REFERENCES grupos(id) ON DELETE CASCADE,
  seleccion_id  UUID REFERENCES selecciones(id) ON DELETE CASCADE,
  posicion_final INTEGER,
  partidos_j    INTEGER DEFAULT 0,
  victorias     INTEGER DEFAULT 0,
  empates       INTEGER DEFAULT 0,
  derrotas      INTEGER DEFAULT 0,
  goles_favor   INTEGER DEFAULT 0,
  goles_contra  INTEGER DEFAULT 0,
  puntos        INTEGER DEFAULT 0,
  clasificado   BOOLEAN DEFAULT FALSE,
  PRIMARY KEY (grupo_id, seleccion_id)
);

-- ============================================================
-- 6. PARTIDOS
-- ============================================================
CREATE TABLE partidos (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  api_id          INTEGER UNIQUE,               -- ID en API-Football
  jornada         INTEGER,
  fase            VARCHAR(50) DEFAULT 'Fase de Grupos',
  -- 'Fase de Grupos','Octavos','Cuartos','Semifinal','Tercer Puesto','Final'
  grupo_id        UUID REFERENCES grupos(id),
  equipo_local_id UUID REFERENCES selecciones(id),
  equipo_visita_id UUID REFERENCES selecciones(id),
  fecha           TIMESTAMPTZ,
  estadio         VARCHAR(200),
  ciudad          VARCHAR(100),
  pais_sede       VARCHAR(50),
  goles_local     INTEGER,
  goles_visita    INTEGER,
  estado          VARCHAR(30) DEFAULT 'pendiente',
  -- 'pendiente','en_vivo','finalizado','suspendido'
  minuto          INTEGER,
  ganador_id      UUID REFERENCES selecciones(id),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 7. PREDICCIONES DE PARTIDOS (bonus semanal)
-- ============================================================
CREATE TABLE predicciones_partidos (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  participante_id   UUID NOT NULL REFERENCES participantes(id) ON DELETE CASCADE,
  partido_id        UUID NOT NULL REFERENCES partidos(id) ON DELETE CASCADE,
  goles_local_pred  INTEGER NOT NULL,
  goles_visita_pred INTEGER NOT NULL,
  puntos_obtenidos  INTEGER DEFAULT 0,
  -- 3 = resultado exacto, 1 = acertó ganador, 0 = falló
  calculado         BOOLEAN DEFAULT FALSE,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(participante_id, partido_id),
  CONSTRAINT pred_antes_partido CHECK (created_at < (SELECT fecha FROM partidos WHERE id = partido_id) + INTERVAL '0 hours')
);

-- ============================================================
-- 8. CONFIGURACIÓN GLOBAL DEL TORNEO
-- ============================================================
CREATE TABLE config_torneo (
  clave   VARCHAR(100) PRIMARY KEY,
  valor   TEXT,
  tipo    VARCHAR(20) DEFAULT 'texto', -- 'texto','numero','booleano','fecha'
  descripcion TEXT
);

INSERT INTO config_torneo VALUES
  ('torneo_activo',        'true',            'booleano', 'Habilita inscripciones y predicciones'),
  ('inscripciones_abiertas','true',           'booleano', 'Permite nuevas inscripciones'),
  ('fecha_cierre_inscripcion','2026-06-11T00:00:00Z','fecha','Fecha límite de inscripción'),
  ('fecha_inicio_torneo',  '2026-06-11T00:00:00Z','fecha','Inicio del Mundial'),
  ('fecha_final_torneo',   '2026-07-19T00:00:00Z','fecha','Final del Mundial'),
  ('cuota_minima_clp',     '2000',            'numero', 'Cuota mínima en pesos chilenos'),
  ('cuota_maxima_clp',     '500000',          'numero', 'Cuota máxima en pesos chilenos'),
  ('pts_campeon',          '40',              'numero', 'Puntos por acertar campeón'),
  ('pts_subcampeon',       '20',              'numero', 'Puntos por acertar subcampeón'),
  ('pts_tercero',          '15',              'numero', 'Puntos por acertar tercer puesto'),
  ('pts_goleador',         '15',              'numero', 'Puntos por acertar goleador'),
  ('pts_sorpresa',         '10',              'numero', 'Puntos por selección sorpresa'),
  ('pts_goles_exactos',    '10',              'numero', 'Puntos por goles totales ±5'),
  ('pts_resultado_exacto', '3',               'numero', 'Puntos por resultado exacto partido'),
  ('pts_ganador_partido',  '1',               'numero', 'Puntos por acertar ganador partido'),
  ('pct_primer_lugar',     '60',              'numero', 'Porcentaje del bote para 1.° lugar'),
  ('pct_segundo_lugar',    '25',              'numero', 'Porcentaje del bote para 2.° lugar'),
  ('pct_tercer_lugar',     '15',              'numero', 'Porcentaje del bote para 3.° lugar'),
  ('api_football_temporada','2026',           'texto',  'Temporada en API-Football'),
  ('api_football_liga_id', '1',               'numero', 'ID de liga en API-Football (1=World Cup)'),
  ('ultima_sync_api',      NULL,              'fecha',  'Última sincronización con API externa'),
  ('organizador_nombre',   'LATAM x NTT Data','texto', 'Nombre del organizador'),
  ('organizador_email',    'polla@empresa.cl','texto', 'Email del organizador');

-- ============================================================
-- 9. LOG DE SINCRONIZACIÓN API
-- ============================================================
CREATE TABLE sync_log (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tipo        VARCHAR(50),   -- 'partidos','grupos','goleadores','resultados'
  estado      VARCHAR(20),   -- 'ok','error'
  detalle     TEXT,
  registros   INTEGER DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- FUNCIONES Y TRIGGERS
-- ============================================================

-- Trigger: actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_participantes_updated
  BEFORE UPDATE ON participantes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_predicciones_updated
  BEFORE UPDATE ON predicciones
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_partidos_updated
  BEFORE UPDATE ON partidos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Función: recalcular puntos totales de un participante
CREATE OR REPLACE FUNCTION recalcular_puntos(p_participante_id UUID)
RETURNS INTEGER AS $$
DECLARE
  total INTEGER := 0;
BEGIN
  -- Puntos de predicciones principales
  SELECT COALESCE(
    puntos_campeon + puntos_subcampeon + puntos_tercero +
    puntos_goleador + puntos_sorpresa + puntos_goles, 0
  )
  INTO total
  FROM predicciones
  WHERE participante_id = p_participante_id;

  -- Sumar puntos de predicciones de partidos
  SELECT total + COALESCE(SUM(puntos_obtenidos), 0)
  INTO total
  FROM predicciones_partidos
  WHERE participante_id = p_participante_id AND calculado = TRUE;

  -- Actualizar participante
  UPDATE participantes
  SET puntos_total = total, updated_at = NOW()
  WHERE id = p_participante_id;

  RETURN total;
END;
$$ LANGUAGE plpgsql;

-- Vista: clasificación completa
CREATE OR REPLACE VIEW clasificacion AS
SELECT
  ROW_NUMBER() OVER (ORDER BY p.puntos_total DESC, p.cuota_clp DESC) AS posicion,
  p.id,
  p.nombre || ' ' || p.apellido AS nombre_completo,
  p.alias,
  p.email,
  p.cuota_clp,
  p.puntos_total,
  p.pagado,
  p.created_at,
  -- Predicciones
  sc.nombre  AS campeon,
  sc.bandera AS campeon_bandera,
  ss.nombre  AS subcampeon,
  j.nombre   AS goleador,
  sorp.nombre AS sorpresa
FROM participantes p
LEFT JOIN predicciones pred ON pred.participante_id = p.id
LEFT JOIN selecciones sc   ON sc.id  = pred.campeon_id
LEFT JOIN selecciones ss   ON ss.id  = pred.subcampeon_id
LEFT JOIN jugadores j      ON j.id   = pred.goleador_id
LEFT JOIN selecciones sorp ON sorp.id = pred.seleccion_sorpresa_id
WHERE p.activo = TRUE
ORDER BY p.puntos_total DESC, p.cuota_clp DESC;

-- Vista: bote total
CREATE OR REPLACE VIEW bote AS
SELECT
  COUNT(*)                          AS total_participantes,
  COUNT(*) FILTER (WHERE pagado)    AS pagados,
  SUM(cuota_clp) FILTER (WHERE pagado) AS bote_total_clp,
  ROUND(SUM(cuota_clp) FILTER (WHERE pagado) * 0.60) AS primer_lugar_clp,
  ROUND(SUM(cuota_clp) FILTER (WHERE pagado) * 0.25) AS segundo_lugar_clp,
  ROUND(SUM(cuota_clp) FILTER (WHERE pagado) * 0.15) AS tercer_lugar_clp
FROM participantes
WHERE activo = TRUE;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE participantes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE predicciones          ENABLE ROW LEVEL SECURITY;
ALTER TABLE predicciones_partidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE selecciones           ENABLE ROW LEVEL SECURITY;
ALTER TABLE jugadores             ENABLE ROW LEVEL SECURITY;
ALTER TABLE grupos                ENABLE ROW LEVEL SECURITY;
ALTER TABLE grupo_selecciones     ENABLE ROW LEVEL SECURITY;
ALTER TABLE partidos              ENABLE ROW LEVEL SECURITY;
ALTER TABLE config_torneo         ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_log              ENABLE ROW LEVEL SECURITY;

-- Lectura pública para tablas de consulta
CREATE POLICY "lectura_publica_selecciones"   ON selecciones        FOR SELECT USING (TRUE);
CREATE POLICY "lectura_publica_jugadores"     ON jugadores          FOR SELECT USING (TRUE);
CREATE POLICY "lectura_publica_grupos"        ON grupos             FOR SELECT USING (TRUE);
CREATE POLICY "lectura_publica_grupo_sel"     ON grupo_selecciones  FOR SELECT USING (TRUE);
CREATE POLICY "lectura_publica_partidos"      ON partidos           FOR SELECT USING (TRUE);
CREATE POLICY "lectura_publica_config"        ON config_torneo      FOR SELECT USING (TRUE);
CREATE POLICY "lectura_publica_participantes" ON participantes      FOR SELECT USING (TRUE);
CREATE POLICY "lectura_publica_predicciones"  ON predicciones       FOR SELECT USING (TRUE);

-- Inserción pública (inscripción anónima)
CREATE POLICY "insercion_publica_participantes" ON participantes      FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "insercion_publica_predicciones"  ON predicciones       FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "insercion_publica_pred_partidos" ON predicciones_partidos FOR INSERT WITH CHECK (TRUE);

-- ============================================================
-- ÍNDICES DE RENDIMIENTO
-- ============================================================
CREATE INDEX idx_participantes_email      ON participantes(email);
CREATE INDEX idx_participantes_puntos     ON participantes(puntos_total DESC);
CREATE INDEX idx_predicciones_part        ON predicciones(participante_id);
CREATE INDEX idx_pred_partidos_part       ON predicciones_partidos(participante_id);
CREATE INDEX idx_pred_partidos_partido    ON predicciones_partidos(partido_id);
CREATE INDEX idx_partidos_fecha           ON partidos(fecha);
CREATE INDEX idx_partidos_estado          ON partidos(estado);
CREATE INDEX idx_partidos_api_id          ON partidos(api_id);
CREATE INDEX idx_grupo_sel_grupo          ON grupo_selecciones(grupo_id);
CREATE INDEX idx_sync_log_tipo            ON sync_log(tipo, created_at DESC);

-- ============================================================
-- DATOS INICIALES: GRUPOS A-H
-- ============================================================
INSERT INTO grupos (letra, nombre) VALUES
  ('A','Grupo A'),('B','Grupo B'),('C','Grupo C'),('D','Grupo D'),
  ('E','Grupo E'),('F','Grupo F'),('G','Grupo G'),('H','Grupo H'),
  ('I','Grupo I'),('J','Grupo J'),('K','Grupo K'),('L','Grupo L');

-- ============================================================
-- DATOS INICIALES: SELECCIONES CONFIRMADAS
-- ============================================================
INSERT INTO selecciones (codigo, nombre, nombre_corto, bandera, grupo, confederacion, api_id) VALUES
  ('ARG','Argentina','Argentina','🇦🇷','B','CONMEBOL',1),
  ('BRA','Brasil','Brasil','🇧🇷','C','CONMEBOL',6),
  ('URU','Uruguay','Uruguay','🇺🇾','A','CONMEBOL',25),
  ('COL','Colombia','Colombia','🇨🇴','G','CONMEBOL',6052),
  ('ECU','Ecuador','Ecuador','🇪🇨','F','CONMEBOL',31164),
  ('PER','Perú','Perú','🇵🇪','B','CONMEBOL',26),
  ('PAR','Paraguay','Paraguay','🇵🇾','J','CONMEBOL',18),
  ('BOL','Bolivia','Bolivia','🇧🇴','K','CONMEBOL',26),
  ('VEN','Venezuela','Venezuela','🇻🇪','L','CONMEBOL',255),
  ('FRA','Francia','Francia','🇫🇷','D','UEFA',2),
  ('ESP','España','España','🇪🇸','E','UEFA',9),
  ('ENG','Inglaterra','Inglaterra','🏴󠁧󠁢󠁥󠁮󠁧󠁿','F','UEFA',10),
  ('GER','Alemania','Alemania','🇩🇪','D','UEFA',25),
  ('POR','Portugal','Portugal','🇵🇹','E','UEFA',27),
  ('NED','Países Bajos','P. Bajos','🇳🇱','F','UEFA',1118),
  ('BEL','Bélgica','Bélgica','🇧🇪','G','UEFA',4),
  ('CRO','Croacia','Croacia','🇭🇷','G','UEFA',3),
  ('AUT','Austria','Austria','🇦🇹','H','UEFA',22),
  ('DEN','Dinamarca','Dinamarca','🇩🇰','K','UEFA',21),
  ('SCO','Escocia','Escocia','🏴󠁧󠁢󠁳󠁣󠁴󠁿','I','UEFA',1178),
  ('SRB','Serbia','Serbia','🇷🇸','L','UEFA',5665),
  ('SUI','Suiza','Suiza','🇨🇭','H','UEFA',15),
  ('TUR','Turquía','Turquía','🇹🇷','H','UEFA',21),
  ('MAR','Marruecos','Marruecos','🇲🇦','E','CAF',32),
  ('SEN','Senegal','Senegal','🇸🇳','C','CAF',35),
  ('NGA','Nigeria','Nigeria','🇳🇬','B','CAF',36),
  ('CMR','Camerún','Camerún','🇨🇲','J','CAF',44),
  ('EGY','Egipto','Egipto','🇪🇬','I','CAF',3),
  ('CIV','Costa de Marfil','C. Marfil','🇨🇮','A','CAF',1337),
  ('ALG','Algeria','Algeria','🇩🇿','K','CAF',6),
  ('GHA','Ghana','Ghana','🇬🇭','H','CAF',7),
  ('TUN','Túnez','Túnez','🇹🇳','L','CAF',26),
  ('USA','Estados Unidos','USA','🇺🇸','A','CONCACAF',2),
  ('MEX','México','México','🇲🇽','C','CONCACAF',3),
  ('CAN','Canadá','Canadá','🇨🇦','C','CONCACAF',94),
  ('PAN','Panamá','Panamá','🇵🇦','A','CONCACAF',6141),
  ('JAM','Jamaica','Jamaica','🇯🇲','J','CONCACAF',49),
  ('HND','Honduras','Honduras','🇭🇳','L','CONCACAF',106),
  ('CRC','Costa Rica','C. Rica','🇨🇷','G','CONCACAF',15),
  ('JPN','Japón','Japón','🇯🇵','D','AFC',7),
  ('KOR','Corea del Sur','Corea S.','🇰🇷','F','AFC',5),
  ('IRN','Irán','Irán','🇮🇷','D','AFC',5666),
  ('AUS','Australia','Australia','🇦🇺','H','AFC',26),
  ('IRQ','Iraq','Iraq','🇮🇶','J','AFC',156),
  ('JOR','Jordania','Jordania','🇯🇴','K','AFC',3),
  ('OMA','Omán','Omán','🇴🇲','L','AFC',91),
  ('ARB','Arabia Saudita','Arabia S.','🇸🇦','D','AFC',16),
  ('NZL','Nueva Zelanda','Nueva Z.','🇳🇿','K','OFC',14);

-- ============================================================
-- DATOS INICIALES: JUGADORES PRINCIPALES
-- ============================================================
INSERT INTO jugadores (nombre, nombre_corto, posicion, api_id) VALUES
  ('Kylian Mbappé','Mbappé','Delantero',278),
  ('Erling Haaland','Haaland','Delantero',1100),
  ('Vinicius Jr','Vinicius Jr','Delantero',318),
  ('Harry Kane','Kane','Delantero',184),
  ('Lamine Yamal','Yamal','Extremo',284087),
  ('Lionel Messi','Messi','Delantero',154),
  ('Cristiano Ronaldo','Ronaldo','Delantero',306),
  ('Pedri','Pedri','Mediocampista',306),
  ('Raphinha','Raphinha','Extremo',24993),
  ('Bukayo Saka','Saka','Extremo',24497),
  ('Phil Foden','Foden','Mediocampista',47080),
  ('Jude Bellingham','Bellingham','Mediocampista',169021),
  ('Neymar Jr','Neymar','Delantero',276),
  ('Rodri','Rodri','Mediocampista',293),
  ('Mohamed Salah','Salah','Extremo',745),
  ('Vinícius Jr','Vinícius Jr','Extremo',318);
