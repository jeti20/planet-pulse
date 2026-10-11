# Error budget policy

Modelled on the example policy in *The Site Reliability Workbook*, appendix B, and scaled
down to a one-person project that depends on third-party APIs.

## SLOs in scope

| Provider | SLI | Objective (30-day rolling) | Budget |
|---|---|---|---|
| USGS, NOAA SWPC, Open-Meteo | availability – successful scrapes / all scrapes | 99.5 % | 0.5 % ≈ 3 h 36 min / 30 d |
| USGS, NOAA SWPC, Open-Meteo | latency – synthetic probes OK **and** < 1 s | 99 % | 1 % |
| USGS, Open-Meteo | freshness – data younger than 5 min / 30 min / 2 h | 99 % | 1 % |

SWPC has no freshness SLO. Its JSON products carry their timestamps as strings, and
json-exporter can't turn those into numbers. That's a known gap.

## What we control

We don't operate these APIs. The budget therefore governs **our own** decisions:
- how aggressively we poll (scrape interval, number of cities),
- which provider we rely on for a given dataset,
- what we show on dashboards when data is stale,
- whether we spend time on mitigation (caching, fallbacks, a second provider).

## Policy

| Budget left | What happens |
|---|---|
| **> 50 %** | Business as usual. Experiments allowed: new datasets, more cities, shorter intervals. |
| **25–50 %** | No new load on the affected provider. Review the dashboards: is the trend ours or theirs? |
| **< 25 %** | Grafana sends `Error budget below 25%`. Freeze changes that touch the affected pipeline. Write down the top cause. |
| **exhausted** | `SLOErrorBudgetExhausted` ticket. Postmortem-style note in `docs/`, then one of: fix our side, add a fallback, or **renegotiate the SLO** if the objective was unrealistic. |

### Renegotiating an SLO is allowed

An SLO that's always red is useless. Changing an objective or threshold is fine as long as the
change is **based on data** and **documented**. The first real example is the latency SLO: it
started at 500 ms. Open-Meteo turned out to answer about 5 % of requests in 0.5–0.6 s, a steady
5× burn rate with no real user impact. The consumer is a scrape every 4 minutes, so the threshold
became 1 s. See the README, "Tuning the latency SLO".

## Exceptions

- Planned maintenance announced by the provider: silence the alerts and keep the budget burn.
  The SLO stays honest, the pager stays quiet.
- Outages caused by our own stack (Alloy, json-exporter, Docker host) **do** count. The user
  doesn't care whose fault it was.
