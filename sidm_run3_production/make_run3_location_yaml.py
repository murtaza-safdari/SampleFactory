#!/usr/bin/env python3
# Generate Run3 signal location YAMLs (signal_4mu_run3.yaml, signal_2mu2e_run3.yaml) in the
# make_fileset shape: per-era ntuple_version key -> {path, samples{key:{path,files,year}}}.
# Crawls the produced nanos on EOS so the file lists reflect what actually exists.
#   full URL = locations[era]["path"] + samples[key]["path"] + file
import subprocess, re, sys
OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else "."
ERAS = ["2022", "2022EE", "2023", "2023BPix"]
EOSP = "/store/group/lpcmetx/SIDM/run3_samplegen/outputs"
TOP = "root://cmseos.fnal.gov//store/group/lpcmetx/SIDM/run3_samplegen/outputs/"

def ls(d):
    try:
        return subprocess.run(["xrdfs", "root://cmseos.fnal.gov", "ls", d],
                              capture_output=True, text=True, timeout=90).stdout.split()
    except Exception:
        return []

for chan in ["4Mu", "2Mu2E"]:
    lines = [f"# Run3 {chan} signal samples (private full-chain production; LLPNanoAOD).",
             f"# Auto-generated from EOS: {EOSP}/<era>/. ntuple_version key = era (2022/2022EE/2023/2023BPix).",
             f"# Consume via make_fileset(samples, ntuple_version=<era>, location_cfg='signal_{chan.lower()}_run3.yaml', replace_xcache=False)."]
    total = 0
    for era in ERAS:
        subdirs = [d for d in ls(f"{EOSP}/{era}") if f"_BsTo2DpTo{chan}_" in d]
        block = []
        for d in sorted(subdirs):
            name = d.split("/")[-1]
            m = re.match(r"SIDM_BsTo2DpTo\w+?_MBs-(\d+)_MDp-([\dp]+)_ctau-([\dp]+)", name)
            if not m:
                continue
            # campaign chunks only (_<era>_jNNN.root); excludes 50-ev pilot/test files
            files = sorted(f.split("/")[-1] for f in ls(d) if re.search(rf"_{era}_j[0-9]+\.root$", f))
            if not files:
                continue
            key = f"{chan}_{m.group(1)}GeV_{m.group(2)}GeV_{m.group(3)}mm"
            block.append((key, name, files))
        if not block:
            continue
        lines.append(f"'{era}':")   # quote so YAML keeps it a string key (bare 2022 parses as int)
        lines.append(f"  path: {TOP}{era}/")
        lines.append("  samples:")
        for key, name, files in block:
            lines.append(f"    {key}:")
            lines.append(f"      path: {name}/")
            lines.append(f"      year: '{era}'")
            lines.append("      files:")
            for f in files:
                lines.append(f"      - {f}")
            total += 1
    path = f"{OUT_DIR}/signal_{chan.lower()}_run3.yaml"
    open(path, "w").write("\n".join(lines) + "\n")
    print(f"wrote {path}: {total} sample-eras")
