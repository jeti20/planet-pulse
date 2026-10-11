# Security

Planet Pulse is a **local demo / portfolio project**. Its defaults trade security for convenience,
on the assumption that only you can reach it:

| Component | Default | Why it matters |
|---|---|---|
| All published ports | bound to `127.0.0.1` (`BIND_ADDR`) | nothing is reachable from your LAN or the internet |
| Grafana | anonymous **Editor**, admin password `admin` unless set in `.env` | anyone who can reach port 3000 can change dashboards |
| Prometheus | `--web.enable-lifecycle`, remote-write receiver, no auth | can be reloaded/shut down and written to |
| Alertmanager, Loki, ntfy, Alloy UI | no authentication | silences, logs and notifications are open |
| Alloy | mounts `/var/run/docker.sock` **read-only** to read container logs | the Docker socket grants broad access to the host; only use on a machine you trust |

**Before exposing any of it** (VPS, `BIND_ADDR=0.0.0.0`, port forwarding):

1. set `GF_SECURITY_ADMIN_PASSWORD`, `GF_RENDERER_TOKEN` in `.env` and `GF_ANONYMOUS_ROLE=Viewer`
   (or `GF_ANONYMOUS_ENABLED=false`),
2. put everything behind a reverse proxy with authentication and TLS, or don't publish the
   Prometheus/Alertmanager/Loki/ntfy/Alloy ports at all,
3. consider replacing the Docker-socket log collection with a file-based one.

No secrets are stored in this repository. `.env` is git-ignored. The data sources are public
APIs that need no API keys.

## Reporting

Found a problem? Please open a GitHub issue. For anything sensitive, use a private
[security advisory](https://docs.github.com/en/code-security/security-advisories) on the repository.
