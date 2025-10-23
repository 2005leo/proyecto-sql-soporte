# Proyecto 2 — SQL (PostgreSQL): Soporte / Atención al Cliente
**Rol:** Data/BI Analyst · **Herramientas:** PostgreSQL (CTEs, ventanas, percentiles, cohortes)

## Dataset
Sintético (~3.2k tickets, 2024–2025). Tablas: `tickets`, `surveys`, `agents`.

## Uso (Windows + psql)
```sql
-- Crear DB y esquema
createdb soporte_demo
psql -U postgres -h localhost -d soporte_demo
\i sql/project2_postgres_setup_and_queries.sql

-- Cargar CSV (método probado)
\copy agents  (agent_id,agent_name,team,seniority,branch_code) FROM 'data/sql_project2_agents.csv'  DELIMITER ',' CSV HEADER ENCODING 'windows-1251';
\copy tickets (ticket_id,created_at,resolved_at,status,priority,category,channel,sla_target_hours,customer_id,agent_id,branch_code) FROM 'data/sql_project2_tickets.csv' DELIMITER ',' CSV HEADER ENCODING 'windows-1251';
\copy surveys (ticket_id,csat_score,nps,comment) FROM 'data/sql_project2_surveys.csv' DELIMITER ',' CSV HEADER ENCODING 'windows-1251';
