#!/bin/bash
# (copy of work/status.sh of the sidm-2024 task record; it expects its condor_v2/ DAG tree next to it)
# status.sh -- regenerate work/status.md for the v2 SIDM production from files only (no condor_q):
#   the outer DAG's run3v2.status and each sub-DAG's <era>_<kind>.status (DAGMan NODE_STATUS_FILEs, rewritten
#   every 10 min), the .cksum files (done chunks, upload rate), the job .out logs ("### FAIL at <step>" per failed
#   attempt) and the shared proxy's lifetime. Safe to run as often as wanted: it never contacts the schedd.
W=$(cd $(dirname $0) && pwd)
PROXY=/uscms_data/d3/murtazas/x509_proxy.pem
TL=$(voms-proxy-info -file $PROXY -timeleft 2>/dev/null || echo -1)
python3 - "$W" "$TL" <<'PYEOF'
import sys, os, glob, re, time, collections
W, tl = sys.argv[1], int(sys.argv[2])
C = os.path.join(W, "condor_v2")
NODE = {0: "not ready", 1: "ready", 2: "pre", 3: "submitted", 4: "post", 5: "done", 6: "error", 7: "futile"}


def blocks(path):
    """ClassAd blocks of a DAGMan node status file -> list of dicts (ints where possible)."""
    out = []
    for b in re.findall(r"\[(.*?)\]", open(path, errors="replace").read(), re.S):
        d = {}
        for k, v in re.findall(r"(\w+)\s*=\s*([^;]*);", b):
            v = v.strip().strip('"')
            d[k] = int(v) if re.fullmatch(r"-?\d+", v) else v
        out.append(d)
    return out


now = time.time()
outer = {}
of = os.path.join(C, "run3v2.status")
if os.path.exists(of):
    for d in blocks(of):
        if d.get("Type") == "NodeStatus":
            outer[d["Node"]] = NODE.get(d.get("NodeStatus"), d.get("NodeStatus"))
rows = ["# v2 SIDM Run 3 production status", "",
        f"generated {time.strftime('%Y-%m-%d %H:%M %Z')} by work/status.sh (files only: DAGMan node status files, "
        "cksum files, job logs)", "",
        "| DAG | outer node | chunks | done | queued (running / idle / held) | failed nodes | retries | failures by reason | rate (chunks/h, last 6 h) | ETA | status file age |",
        "|---|---|---|---|---|---|---|---|---|---|---|"]
order = [f"{e}_{k}" for k in ("column", "grid") for e in ("2024", "2022", "2022EE", "2023", "2023BPix")]
tot = collections.Counter()
for name in order:
    d = os.path.join(C, name)
    if not os.path.isdir(d):
        continue
    dag = os.path.join(d, f"{name}.dag")
    total = sum(1 for l in open(dag) if l.startswith("JOB "))
    ok, mt = 0, []
    for f in glob.glob(os.path.join(d, "cksum", "*.cksum")):
        s = open(f).read()
        if "adler32=" in s or " skip " in s:
            ok += 1; mt.append(os.path.getmtime(f))
    reasons = collections.Counter()
    for f in glob.glob(os.path.join(d, "logs", "*.out")):
        for m in re.finditer(r"### FAIL at (\S+)", open(f, errors="replace").read()):
            reasons[m.group(1)] += 1
    q = idle = held = failed = retries = 0; age = "-"
    sf = os.path.join(d, f"{name}.status")
    if os.path.exists(sf):
        age = f"{(now - os.path.getmtime(sf)) / 60:.0f} min"
        for b in blocks(sf):
            if b.get("Type") == "DagStatus":
                q, failed = b.get("NodesQueued", 0), b.get("NodesFailed", 0)
                idle, held = b.get("JobProcsIdle", 0), b.get("JobProcsHeld", 0)
            elif b.get("Type") == "NodeStatus":
                retries += b.get("RetryCount", 0)
    run = max(q - idle - held, 0)
    tot.update(run=run, idle=idle, held=held, done=ok, total=total)
    rate = sum(1 for t in mt if now - t < 6 * 3600) / 6.0
    eta = "done" if ok >= total else (f"{(total - ok) / rate:.0f} h" if rate > 0 else "-")
    rows.append(f"| {name} | {outer.get(name, '-')} | {total} | {ok} | {q} ({run} / {idle} / {held}) | {failed} | {retries} | "
                f"{', '.join(f'{k}: {v}' for k, v in reasons.most_common()) or '-'} | {rate:.1f} | {eta} | {age} |")
rows += ["", f"all sub-DAGs: {tot['done']} / {tot['total']} chunks done; jobs running {tot['run']}, idle {tot['idle']}, held {tot['held']} "
         "(running = queued nodes minus idle and held job procs, from the status files)"]
if tl >= 0:
    rows.append(f"proxy /uscms_data/d3/murtazas/x509_proxy.pem: {tl / 86400:.1f} days left, expires "
                f"{time.strftime('%Y-%m-%d %H:%M %Z', time.localtime(now + tl))} -- renew before then (user)")
else:
    rows.append("proxy /uscms_data/d3/murtazas/x509_proxy.pem: voms-proxy-info failed (missing or expired?)")
open(os.path.join(W, "status.md"), "w").write("\n".join(rows) + "\n")
print("\n".join(rows))
PYEOF
