"""Assemble an evidence bundle from the live observability stack.

Queries Prometheus (metrics + the SLO recording rules this repo already defines),
Loki (top recent error logs), and Tempo (slow/error trace summaries). Every source
is best-effort: if one is unreachable the bundle is assembled from whatever answered,
because a copilot that crashes when Loki is down is useless exactly when you need it.

Uses only the stdlib (urllib) so it runs anywhere the repo runs, no pip install.
"""
import json
import os
import urllib.parse
import urllib.request

PROM = os.environ.get("PROM_URL", "http://localhost:9090")
LOKI = os.environ.get("LOKI_URL", "http://localhost:3100")
TEMPO = os.environ.get("TEMPO_URL", "http://localhost:3200")
TIMEOUT = float(os.environ.get("COPILOT_HTTP_TIMEOUT", "4"))

SLO = {"availability_target": 0.999, "latency_p95_target_s": 1.0}


def _get(url):
    with urllib.request.urlopen(url, timeout=TIMEOUT) as r:
        return json.loads(r.read().decode("utf-8"))


def _prom_instant(query):
    """Return the first scalar value of an instant query, or None on any failure."""
    try:
        url = PROM + "/api/v1/query?" + urllib.parse.urlencode({"query": query})
        data = _get(url)
        result = data.get("data", {}).get("result", [])
        if not result:
            return None
        return float(result[0]["value"][1])
    except Exception:
        return None


def _prom_vector(query):
    """Return {label_value: scalar} keyed by the given label, or {} on failure."""
    out = {}
    try:
        url = PROM + "/api/v1/query?" + urllib.parse.urlencode({"query": query})
        data = _get(url)
        for series in data.get("data", {}).get("result", []):
            metric = series.get("metric", {})
            key = metric.get("service") or metric.get("job") or metric.get("pod") or "unknown"
            out[key] = float(series["value"][1])
    except Exception:
        pass
    return out


def collect():
    metrics = {
        # These recording rules are defined in observability/rules/slo.yml.
        "orders_availability_ratio5m": _prom_instant("daig:order_availability:ratio5m"),
        "orders_error_ratio5m": _prom_instant("daig:order_error:ratio5m"),
        "orders_p95_latency_s": _prom_instant("daig:order_latency:p95_5m"),
        "burn_rate_1h": _prom_instant("daig:order_error:ratio1h / 0.001"),
        # Per-service p95 straight from the OTel spanmetrics histogram.
        "dispatch_p95_latency_s": _prom_instant(
            'histogram_quantile(0.95, sum by (le) (rate(duration_milliseconds_bucket{service_name="dispatch"}[5m])))/1000'),
        "kitchen_cpu_cores": _prom_instant('sum(rate(process_cpu_seconds_total{service="kitchen"}[2m]))'),
        "dispatch_cpu_cores": _prom_instant('sum(rate(process_cpu_seconds_total{service="dispatch"}[2m]))'),
        "up": _prom_vector('up{job="daig-services"}'),
        "restarts_5m": _prom_vector('increase(kube_pod_container_status_restarts_total{namespace="daig"}[5m])'),
    }
    # Drop keys Prometheus couldn't answer so the model isn't misled by nulls.
    metrics = {k: v for k, v in metrics.items() if v not in (None, {})}

    return {
        "window": "last 5m",
        "slo": SLO,
        "metrics": metrics,
        "logs": _loki_top_errors(),
        "traces": _tempo_slow_traces(),
        "recent_deploys": [],  # wire to your CD deploy-marker source
        "_sources": {
            "prometheus": bool(metrics),
        },
    }


def _loki_top_errors():
    """Best-effort: recent error/warn log lines, summarised. [] if Loki is down."""
    try:
        q = '{namespace="daig"} |= "error"'
        url = LOKI + "/loki/api/v1/query_range?" + urllib.parse.urlencode({"query": q, "limit": "50"})
        data = _get(url)
        out = []
        for stream in data.get("data", {}).get("result", [])[:5]:
            svc = stream.get("stream", {}).get("service", "unknown")
            values = stream.get("values", [])
            if values:
                out.append({"service": svc, "level": "error",
                            "msg": values[0][1][:200], "count": len(values)})
        return out
    except Exception:
        return []


def _tempo_slow_traces():
    """Best-effort: slowest recent traces as summaries. [] if Tempo is down."""
    try:
        url = TEMPO + "/api/search?" + urllib.parse.urlencode({"tags": "", "limit": "5", "minDuration": "1s"})
        data = _get(url)
        out = []
        for t in data.get("traces", [])[:5]:
            out.append({
                "name": t.get("rootTraceName", "unknown"),
                "p95_ms": t.get("durationMs"),
                "db_spans": None,  # a real integration would count db.system spans
                "note": "slow trace; inspect child spans for a sequential DB fan-out",
            })
        return out
    except Exception:
        return []
