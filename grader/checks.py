"""Check implementations for the challenge engine.

A challenge is a list of CHECKS that assert the desired (fixed) state. Each check
returns (passed: bool, detail: str). The engine (grader.py) dispatches on `type`,
scores, and shows the hint when a check fails.

Check types:
  file        - a repo/config file exists / contains text / is absent
  shell       - a command exits 0 (or a chosen code) and optionally prints text
  http         - an endpoint returns a status / body substring
  prometheus  - an instant query's value satisfies a comparison

Only the stdlib is used, so the engine runs anywhere the repo runs.

SECURITY: `shell` checks execute commands from challenge YAML. Challenge files are
trusted, repo-authored content (like a Makefile or an Ansible task) - never load a
challenge file from an untrusted source.
"""
import json
import os
import re
import subprocess
import urllib.parse
import urllib.request

HTTP_TIMEOUT = float(os.environ.get("GRADER_HTTP_TIMEOUT", "5"))

_OPS = {
    "<": lambda a, b: a < b,
    "<=": lambda a, b: a <= b,
    ">": lambda a, b: a > b,
    ">=": lambda a, b: a >= b,
    "==": lambda a, b: a == b,
    "!=": lambda a, b: a != b,
}


def check_file(spec):
    path = spec["path"]
    exists = os.path.exists(path)
    if spec.get("absent"):
        return (not exists, "present" if exists else "absent (as required)")
    if not exists:
        return (False, "missing: {0}".format(path))
    if "contains" in spec:
        with open(path, "r", errors="replace") as f:
            body = f.read()
        needle = spec["contains"]
        if spec.get("regex"):
            ok = re.search(needle, body) is not None
        else:
            ok = needle in body
        return (ok, "contains {0!r}".format(needle) if ok else "does not contain {0!r}".format(needle))
    return (True, "exists")


def check_shell(spec):
    cmd = spec["cmd"]
    try:
        proc = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True,
                              timeout=float(spec.get("timeout", 30)))
    except subprocess.TimeoutExpired:
        return (False, "timed out")
    except Exception as e:
        return (False, "error: {0}".format(e))
    want_exit = int(spec.get("expect_exit", 0))
    if proc.returncode != want_exit:
        return (False, "exit {0} (wanted {1}): {2}".format(
            proc.returncode, want_exit, (proc.stderr or proc.stdout).strip()[:120]))
    needle = spec.get("expect_stdout_contains")
    if needle is not None and needle not in proc.stdout:
        return (False, "stdout missing {0!r}".format(needle))
    return (True, "exit {0}".format(proc.returncode))


def _http_get(url):
    with urllib.request.urlopen(url, timeout=HTTP_TIMEOUT) as r:
        return r.getcode(), r.read().decode("utf-8", "replace")


def check_http(spec):
    url = spec["url"]
    try:
        status, body = _http_get(url)
    except urllib.error.HTTPError as e:  # a non-2xx is still a real response
        status, body = e.code, ""
    except Exception as e:
        return (False, "unreachable: {0}".format(e))
    want = int(spec.get("expect_status", 200))
    if status != want:
        return (False, "status {0} (wanted {1})".format(status, want))
    needle = spec.get("expect_contains")
    if needle is not None and needle not in body:
        return (False, "body missing {0!r}".format(needle))
    return (True, "status {0}".format(status))


def check_prometheus(spec):
    base = os.environ.get("PROM_URL", "http://localhost:9090")
    q = spec["query"]
    try:
        url = base + "/api/v1/query?" + urllib.parse.urlencode({"query": q})
        _, body = _http_get(url)
        result = json.loads(body).get("data", {}).get("result", [])
    except Exception as e:
        return (False, "query failed: {0}".format(e))
    if not result:
        return (False, "query returned no data")
    value = float(result[0]["value"][1])
    a = spec.get("assert", {})
    op = _OPS.get(a.get("op", "<"))
    target = float(a.get("value", 0))
    ok = op(value, target)
    return (ok, "value={0:.4g} {1} {2}".format(value, a.get("op"), target) if ok
            else "value={0:.4g} not {1} {2}".format(value, a.get("op"), target))


DISPATCH = {
    "file": check_file,
    "shell": check_shell,
    "http": check_http,
    "prometheus": check_prometheus,
}


def run_check(spec):
    fn = DISPATCH.get(spec.get("type"))
    if fn is None:
        return (False, "unknown check type: {0}".format(spec.get("type")))
    try:
        return fn(spec)
    except KeyError as e:
        return (False, "check misconfigured, missing key {0}".format(e))
