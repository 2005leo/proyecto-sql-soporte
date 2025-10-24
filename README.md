# Proyecto 2 — SQL (PostgreSQL): Soporte / Atención al Cliente
**Rol:** Data/BI Analyst · **Herramientas:** PostgreSQL (CTEs, funciones ventana, percentiles, cohortes)

Analítica operativa de tickets (SLA, tiempos de resolución y satisfacción) para priorizar mejoras y ruteo por canal.

---

## 1) Problema
La operación de soporte necesita entender **SLA**, **tiempos de resolución** y **satisfacción** (CSAT/NPS) para:
- Detectar cuellos de botella (por prioridad/canal).
- Optimizar ruteo de tickets críticos.
- Priorizar equipos/sucursales con mayor impacto.

---

## 2) Dataset
Sintético (~**3.2k** tickets, 2024–2025). Tres tablas:

- **`tickets`**  
  `ticket_id, created_at, resolved_at, status, priority, category, channel, sla_target_hours, customer_id, agent_id, branch_code`  
- **`surveys`**  
  `ticket_id, csat_score (1–5), nps (-100..100), comment`  
- **`agents`**  
  `agent_id, agent_name, team, seniority, branch_code`

> El script crea también la vista **`v_tickets_enriched`** con `resolution_hours` y flag `sla_met`.

---

## 3) Reproducibilidad (Windows + psql desde VS Code)
1. **Crear DB** y conectarse:
   ```bash
   createdb soporte_demo
   "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -h localhost -d soporte_demo

---

## Resultados (reales)

**SLA por prioridad (resueltos)**
- Low: **99.4%**
- Medium: **97.8%**
- High: **94.7%**
- Urgent: **63.6%**

**Tiempos de resolución por Canal × Prioridad**  
*(horas; promedio, p50, p90)*

| Canal | Prioridad | Avg | p50 | p90 |
|------|-----------|----:|----:|----:|
| App   | High   |  8.53 |  7.88 | 14.24 |
| App   | Low    | 24.66 | 20.56 | 33.59 |
| App   | Medium | 16.60 | 15.25 | 26.91 |
| App   | Urgent |  7.07 |  7.07 |  8.04 |
| Chat  | High   | 10.86 |  8.73 | 21.35 |
| Chat  | Low    | 21.89 | 19.20 | 38.98 |
| Chat  | Medium | 15.73 | 12.77 | 30.26 |
| Chat  | Urgent |  7.87 |  6.51 | 12.99 |
| Email | High   | 10.36 |  8.77 | 18.37 |
| Email | Low    | 21.88 | 18.54 | 38.38 |
| Email | Medium | 16.01 | 13.37 | 28.43 |
| Email | Urgent |  7.51 |  6.70 | 12.31 |
| Phone | High   | 10.46 |  8.13 | 21.16 |
| Phone | Low    | 21.68 | 17.66 | 39.89 |
| Phone | Medium | 15.78 | 13.88 | 29.11 |
| Phone | Urgent |  6.83 |  5.40 | 11.47 |

**Insights**
- **Urgent**: mejor performance en **Phone** (p50 ≈ **5.4h**).  
- **High**: gana **App** (p50 ≈ **7.9h**).  
- **Medium**: destaca **Chat** (p50 ≈ **12.8h**).  
- **Low**: más eficiente **Phone** (p50 ≈ **17.7h**).  
- Gran gap de **SLA en Urgent** (≈ **63.6%**): oportunidad de ruteo por canal + priorización inicial para subir SLA.
