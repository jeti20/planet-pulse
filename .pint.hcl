# pint - PromQL / rule linter (https://cloudflare.github.io/pint/)
#   offline:  docker compose run --rm pint
#   online:   pint can also check rules against the live Prometheus (series
#             really exist, labels match...) - see the "prometheus" block.

parser {
  relaxed = []
}

# Uncomment to let pint query the running Prometheus while linting
# (e.g. `docker compose run --rm pint pint --config=/work/.pint.hcl lint ...`
# on the compose network).
# prometheus "local" {
#   uri     = "http://prometheus:9090"
#   timeout = "30s"
# }

rule {
  match {
    kind = "alerting"
  }
  # Every alert must say how urgent it is...
  label "severity" {
    severity = "bug"
    value    = "(none|ticket|page)"
    required = true
  }
  # ...and what it is about.
  annotation "summary" {
    severity = "bug"
    required = true
  }
}

rule {
  match {
    kind = "alerting"
    label "severity" {
      value = "page"
    }
  }
  # Anything that wakes a human up must link to a runbook.
  annotation "runbook_url" {
    severity = "warning"
    required = true
  }
}
