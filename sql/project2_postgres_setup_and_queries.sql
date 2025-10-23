-- Project 2 — SQL (PostgreSQL) · Soporte/Atención al Cliente
-- Uso:
-- 1) createdb soporte_demo    ·   psql soporte_demo
-- 2) \i project2_postgres_setup_and_queries.sql
-- 3) COPY con rutas locales correctas (ver sección 2).

DROP TABLE IF EXISTS surveys;
DROP TABLE IF EXISTS tickets;
DROP TABLE IF EXISTS agents;

CREATE TABLE agents (
  agent_id     VARCHAR(8) PRIMARY KEY,
  agent_name   TEXT NOT NULL,
  team         TEXT NOT NULL,
  seniority    TEXT NOT NULL,
  branch_code  TEXT NOT NULL
);

CREATE TABLE tickets (
  ticket_id         VARCHAR(8) PRIMARY KEY,
  created_at        TIMESTAMP NOT NULL,
  resolved_at       TIMESTAMP,
  status            TEXT NOT NULL CHECK (status IN ('Open','Resolved')),
  priority          TEXT NOT NULL CHECK (priority IN ('Low','Medium','High','Urgent')),
  category          TEXT NOT NULL,
  channel           TEXT NOT NULL,
  sla_target_hours  INT NOT NULL,
  customer_id       TEXT NOT NULL,
  agent_id          VARCHAR(8) REFERENCES agents(agent_id),
  branch_code       TEXT NOT NULL
);

CREATE INDEX idx_tickets_created ON tickets(created_at);
CREATE INDEX idx_tickets_resolved ON tickets(resolved_at);
CREATE INDEX idx_tickets_priority ON tickets(priority);
CREATE INDEX idx_tickets_channel ON tickets(channel);
CREATE INDEX idx_tickets_status ON tickets(status);

CREATE TABLE surveys (
  ticket_id   VARCHAR(8) PRIMARY KEY REFERENCES tickets(ticket_id),
  csat_score  INT CHECK (csat_score BETWEEN 1 AND 5),
  nps         INT CHECK (nps BETWEEN -100 AND 100),
  comment     TEXT
);

-- 2) COPY (editar rutas)
-- COPY agents  FROM '/ruta/absoluta/sql_project2_agents.csv'  CSV HEADER;
-- COPY tickets FROM '/ruta/absoluta/sql_project2_tickets.csv' CSV HEADER;
-- COPY surveys FROM '/ruta/absoluta/sql_project2_surveys.csv' CSV HEADER;

CREATE OR REPLACE VIEW v_tickets_enriched AS
SELECT
  t.*,
  a.team,
  a.seniority,
  CASE WHEN t.resolved_at IS NULL THEN NULL
       ELSE EXTRACT(EPOCH FROM (t.resolved_at - t.created_at)) / 3600.0 END AS resolution_hours,
  CASE WHEN t.resolved_at IS NOT NULL
            AND EXTRACT(EPOCH FROM (t.resolved_at - t.created_at))/3600.0 <= t.sla_target_hours
       THEN 1 ELSE 0 END AS sla_met
FROM tickets t
LEFT JOIN agents a ON a.agent_id = t.agent_id;

-- Q1) Volumen diario
SELECT DATE_TRUNC('day', created_at)::date AS day, COUNT(*) AS tickets
FROM tickets GROUP BY 1 ORDER BY 1;

-- Q2) SLA por prioridad
SELECT priority, ROUND(100.0 * AVG(sla_met)::numeric, 1) AS sla_pct
FROM v_tickets_enriched WHERE status='Resolved'
GROUP BY 1 ORDER BY 1;

-- Q3) Tiempo por canal x prioridad (P50/P90)
SELECT channel, priority,
  ROUND(AVG(resolution_hours)::numeric, 2) AS avg_hours,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY resolution_hours)::numeric, 2) AS p50_hours,
  ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY resolution_hours)::numeric, 2) AS p90_hours
FROM v_tickets_enriched
WHERE status='Resolved'
GROUP BY 1,2 ORDER BY 1,2;

-- Q4) Top 10 sucursales por SLA y CSAT (min 30 encuestas)
WITH branch_stats AS (
  SELECT
    branch_code,
    AVG(sla_met)::numeric AS sla_rate,
    AVG(s.csat_score)::numeric AS csat_avg,
    COUNT(s.ticket_id) AS surveys_n
  FROM v_tickets_enriched v
  LEFT JOIN surveys s ON s.ticket_id=v.ticket_id
  WHERE v.status='Resolved'
  GROUP BY 1
)
SELECT * FROM branch_stats
WHERE surveys_n >= 30
ORDER BY sla_rate DESC, csat_avg DESC
LIMIT 10;

-- Q5) Leaderboard de agentes
SELECT agent_id, team, seniority,
  COUNT(*) FILTER (WHERE status='Resolved') AS resolved_n,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY resolution_hours)::numeric,2) AS p50_hours,
  ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY resolution_hours)::numeric,2) AS p90_hours
FROM v_tickets_enriched
GROUP BY 1,2,3
HAVING COUNT(*) FILTER (WHERE status='Resolved') >= 20
ORDER BY resolved_n DESC, p50_hours ASC
LIMIT 15;

-- Q6) Cohorte mensual: % resueltos <24h
WITH base AS (
  SELECT DATE_TRUNC('month', created_at)::date AS month,
         CASE WHEN status='Resolved' AND resolution_hours < 24 THEN 1 ELSE 0 END AS fast_resolve
  FROM v_tickets_enriched
)
SELECT month, ROUND(100.0 * AVG(fast_resolve)::numeric,1) AS pct_under_24h
FROM base GROUP BY 1 ORDER BY 1;

-- Q7) Abiertos > 72h
SELECT COUNT(*) AS open_over_72h
FROM v_tickets_enriched
WHERE status='Open'
  AND EXTRACT(EPOCH FROM (NOW() - created_at))/3600.0 > 72;

-- Q8) Percentiles por categoría
SELECT category,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY resolution_hours)::numeric,2) AS p50,
  ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY resolution_hours)::numeric,2) AS p80,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY resolution_hours)::numeric,2) AS p95
FROM v_tickets_enriched
WHERE status='Resolved'
GROUP BY 1 ORDER BY 1;

-- Q9) CSAT vs SLA
SELECT s.csat_score,
       ROUND(AVG(v.sla_met)::numeric,2) AS sla_met_avg,
       COUNT(*) AS n
FROM surveys s
JOIN v_tickets_enriched v USING (ticket_id)
GROUP BY 1 ORDER BY 1;

-- Q10) Rolling 7 días (creados/resueltos)
WITH series AS (
  SELECT d::date AS day
  FROM generate_series((SELECT MIN(created_at)::date FROM tickets),
                       (SELECT MAX(COALESCE(resolved_at, created_at))::date FROM tickets),
                       '1 day') AS g(d)
),
created AS (
  SELECT DATE_TRUNC('day', created_at)::date AS day, COUNT(*) AS c
  FROM tickets GROUP BY 1
),
resolved AS (
  SELECT DATE_TRUNC('day', resolved_at)::date AS day, COUNT(*) AS r
  FROM tickets WHERE resolved_at IS NOT NULL GROUP BY 1
)
SELECT s.day,
       COALESCE(c.c,0) AS created_n,
       COALESCE(r.r,0) AS resolved_n,
       SUM(COALESCE(c.c,0)) OVER (ORDER BY s.day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS created_rolling7,
       SUM(COALESCE(r.r,0)) OVER (ORDER BY s.day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS resolved_rolling7
FROM series s
LEFT JOIN created c ON c.day=s.day
LEFT JOIN resolved r ON r.day=s.day
ORDER BY s.day;
