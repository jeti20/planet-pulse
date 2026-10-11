# Runbooks

Every alert that can page links here (`runbook_url`). Each runbook covers what the
alert means, how to confirm it and what to do about it.

---

## SLOErrorBudgetBurnFast

**Severity:** page · **Source:** Prometheus `slo-alerts`

**Meaning.** One upstream provider (USGS / SWPC / Open-Meteo) is failing one of its SLOs
(availability, latency or freshness) fast enough to burn **2 % of the 30-day budget in 1 h**
(14.4×) or **5 % in 6 h** (6×). Both a long and a short window must agree, so the alert stops
quickly once the problem goes away.

**Confirm.**
1. Open the [SLO dashboard](http://localhost:3000/d/pp-slo) filtered to the provider from the alert.
2. Look at *Error ratio, 5-minute windows*. A solid red row is an ongoing outage. Scattered red
   cells are flapping.
3. **availability:** Platform → *Upstream endpoints*. Find out which datasets fail.
   `curl` the URL from `alloy/config.alloy` yourself.
4. **latency:** SLO → *Synthetic probe – where does the time go?* A big `connect`/`tls` phase
   points at the network. A big `processing` phase means the provider's backend is slow.
5. **freshness:** the provider answers but serves old data. Compare
   `usgs_feed_generated_timestamp_ms` / `openmeteo_*_observed_timestamp_seconds` with now.

**Act.** These are third-party APIs, so we can't fix them. What we can do:
- Check the provider's status page / social media. Silence the alert in Alertmanager for the
  expected duration and link the incident.
- If the problem is on our side (DNS, proxy, rate-limited by Open-Meteo – HTTP 429), fix the cause.
  For 429s, increase `scrape_interval` in `alloy/config.alloy` or remove cities.

## SLOErrorBudgetBurnSlow

**Severity:** ticket (working hours only)

A slow, steady leak: 3× over 1 d or 1× over 3 d. Nothing is on fire, but at this rate the budget
runs out before the window ends. Look for a pattern (time of day, a single dataset, a single city)
and decide whether the objective or the threshold is still right. See the error budget policy.

## StackComponentDown

**Severity:** page

`up == 0` for one of the stack's own components for 2 minutes.

```bash
docker compose ps
docker compose logs --tail=100 <service>
docker compose restart <service>
```

Grafana → Explore → Loki: `{service="<service>"}` shows the last logs before it died.
If **json-exporter** is down, Alertmanager inhibits all `Upstream*` alerts. Fix it first.

## NoUpstreamDataReceived

**Severity:** page

Prometheus stopped receiving `up{job="upstream"}` series. Alloy itself may still be up, because
Prometheus scrapes it directly. Usual causes:
- Alloy remote_write fails → Platform → *Remote write* panel, `AlloyRemoteWriteFailing`.
- Broken Alloy config after an edit → http://localhost:12345 shows unhealthy components.
  Run `docker compose run --rm alloy-validate`.

## UpstreamScrapeFailing

**Severity:** ticket

More than half of the scrapes of one endpoint fail. The SLO alerts decide whether this needs a
human right now. This alert tells you *which* dataset is broken.

## UpstreamSchemaDrift

**Severity:** ticket

The endpoint answers HTTP 200 but json-exporter extracts **zero samples**: the provider changed
its JSON format. Fetch the URL, compare it with the JSONPath in `json-exporter/config.yml`, fix the
path and restart json-exporter. This is a data contract test.

## UpstreamDataInvalid

**Severity:** ticket

The data parses but makes no physical sense. For example, GOES X-ray flux is exactly `0`, while
the real solar background never drops to zero. This usually comes from the provider side: satellite
manoeuvres, eclipse season, recalibration, or a switch between primary and secondary GOES satellites.
Dashboards show *no data* instead of a misleading "class A". Check SWPC's notices. Nothing to do
on our side except wait.

## AlertmanagerNotificationsFailing

**Severity:** page

Alertmanager can't reach ntfy. Check `docker compose logs ntfy` and the
*Notifications sent* panel on the Platform dashboard. The Watchdog heartbeat in the
`planet-pulse-heartbeat` topic should arrive every hour. If it doesn't, this is the reason.

## UpstreamApiQuotaNearlyExhausted

**Severity:** ticket

We have used more than 80 % of a published free-tier limit (today only Open-Meteo: 10 000/day,
5 000/hour, 600/minute per IP). The `window` label says which one. At 100 % the provider answers
HTTP 429. The availability and freshness SLOs then burn and the weather dashboards go stale.

**Confirm.** [API usage dashboard](http://localhost:3000/d/pp-api-usage): *Requests by endpoint*
shows who is calling, and *Open-Meteo projected / day* shows where the trend ends.

**Act.**
- More cities than planned? Each city costs ~720 requests/day. Remove some from `alloy/cities.json`.
- Increase `scrape_interval` of `prometheus.scrape "upstream_openmeteo"` in `alloy/config.alloy`.
  Keep it ≤ 4 m, otherwise Prometheus marks the series stale between scrapes (5 m lookback).
- Shared public IP (office NAT, VPN)? Other users of Open-Meteo count against the same limit.
  The dashboard only sees *our* requests.

## UpstreamRateLimited

**Severity:** ticket

The synthetic probe got **HTTP 429**: the provider is rejecting us because of the quota, not
because it is down. This alert explains the SLO burn of the same provider. Handle the SLO alerts
as an incident with this as the known cause.

**Act.** Reduce the load (see above) and wait. Open-Meteo resets the daily limit the next day.
Restarting the stack doesn't reset the quota.
