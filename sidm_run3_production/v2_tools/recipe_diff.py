#!/usr/bin/env python3
"""recipe_diff.py: diff the cmsDriver arguments of chain_job_v2.sh (recorded by a shimmed dry run) against
McM get_setup of real central requests, per era and step. Writes ../recipe_diff_<era>.txt.
Allowed differences (brief, round 2): file names, event counts, nThreads, addMonitoring, our --customise /
--customise_commands for the generator fragment and RNG. Everything else is flagged BLOCKING."""
import re, shlex, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
MCM = os.path.join(HERE, "..", "mcm", "v2")
# GS: the newest 'done' wmLHEGS request created after 2026-07-01 (the B2G chains' own GS requests
# are older, in 12_4_25 / 13_0_24); DR: the newest 'done' B2G DRPremix request created after 2026-07-01.
ORACLE = {  # era: {step: prepid}
    "2022": {"GS": "EXO-Run3Summer22wmLHEGS-05300", "PREMIX": "B2G-Run3Summer22DRPremix-06899", "RECO": "B2G-Run3Summer22DRPremix-06899"},
    "2022EE": {"GS": "EXO-Run3Summer22EEwmLHEGS-05295", "PREMIX": "B2G-Run3Summer22EEDRPremix-07198", "RECO": "B2G-Run3Summer22EEDRPremix-07198"},
    "2023": {"GS": "EXO-Run3Summer23wmLHEGS-04353", "PREMIX": "B2G-Run3Summer23DRPremix-06497", "RECO": "B2G-Run3Summer23DRPremix-06497"},
    "2023BPix": {"GS": "EXO-Run3Summer23BPixwmLHEGS-04353", "PREMIX": "B2G-Run3Summer23BPixDRPremix-06500", "RECO": "B2G-Run3Summer23BPixDRPremix-06500"},
    "2024": {"GS": "TOP-RunIII2024Summer24wmLHEGS-00254", "PREMIX": "B2G-RunIII2024Summer24DRPremix-07498", "RECO": "B2G-RunIII2024Summer24DRPremix-07498",
             "NANO": "EXO-RunIII2024Summer24NanoAODv15-06879"},
}
# 2022-2023 have no EXONano request in McM yet: their nano reference is the recipe stated in the brief
# (its era/GT columns), cross-checked only for the GT against the newest EXO NanoAODv12 requests.
BRIEF_NANO = {"2022": ("Run3", "130X_mcRun3_2022_realistic_v5"), "2022EE": ("Run3", "130X_mcRun3_2022_realistic_postEE_v6"),
              "2023": ("Run3_2023", "130X_mcRun3_2023_realistic_v15"), "2023BPix": ("Run3_2023", "130X_mcRun3_2023_realistic_postBPix_v6")}
ALIASES = {"-s": "--step", "-n": "--number", "--filein": "--filein", "--fileout": "--fileout"}
ALLOWED = {"--fileout", "--filein", "--python_filename", "--number", "--number_out", "--nThreads", "--no_exec",
           "--customise_commands", "--nStreams", "--nConcurrentLumis"}
# 2022/2022EE only, approved in round 3 (12_4_X AODSIM read by the 16_0_10 EXONano):
APPROVED = {("RECO", "--outputCommands", "keep *_dt1DRecHits_*_*,keep *_csc2DRecHits_*_*"):
                "keep the DT 1D / CSC 2D muon rec hits (13_0_X+ default AOD content; needed by the EXONano dt/cscMDSshower tables)",
            ("NANO", "--customise", "IOPool/Input/fixReading_12_4_X_Files.fixReading_12_4_X_Files"):
                "FixMissingStreamerInfos for the 12_4_X HLT scouting classes (cms-sw/cmssw#41348, #45888)"}
COMPARED = ["release", "arch", "--conditions", "--step", "--era", "--beamspot", "--pileup_input", "--procModifiers", "--datamix",
            "--geometry", "--customise", "--eventcontent", "--datatier", "--scenario", "--mc"]


def parse(argv):
    pos, opt, i = [], {}, 0
    while i < len(argv):
        a = argv[i]
        if a.startswith("--customise_commands="):
            opt["--customise_commands"] = a.split("=", 1)[1]; i += 1; continue
        if a.startswith("-"):
            k = ALIASES.get(a, a)
            if i + 1 < len(argv) and (not argv[i + 1].startswith("-") or re.fullmatch(r"-\d+", argv[i + 1])):
                v = argv[i + 1]; i += 2
            else:
                v = True; i += 1
            if k == "--customise":   # repeated option: keep a sorted comma list
                opt[k] = ",".join(sorted(filter(None, (opt.get(k, "") + "," + v).split(","))))
            else:
                opt[k] = v
        else:
            pos.append(a); i += 1
    return pos, opt


def kind(opt):
    s = str(opt.get("--step", ""))
    return "GS" if s.startswith("LHE") else "PREMIX" if s.startswith("DIGI") else "RECO" if s.startswith("RAW2DIGI") else \
        "NANO" if s.startswith("PAT") else "?"


def oracle(prepid):
    txt = open(os.path.join(MCM, f"setup_{prepid}.sh")).read()
    rel = re.search(r"scram p CMSSW (\S+)", txt).group(1)
    arch = re.search(r"export SCRAM_ARCH=(\S+)", txt).group(1)
    out = {}
    for line in txt.splitlines():
        if line.startswith("cmsDriver.py"):
            argv = shlex.split(line.split("||")[0])[1:]
            pos, opt = parse(argv)
            opt["release"], opt["arch"] = rel, arch
            out[kind(opt)] = opt
    return out


def ours(era):
    blocks = open(os.path.join(HERE, f"ours_{era}.args")).read().split("@@END\n")
    cfg = open(os.path.join(HERE, f"run_{era}", "dry.log")).read()
    m = re.search(r"REL=(\S+)/(\S+) .* nano=(\S+)/(\S+) ", cfg)
    out = {}
    for b in blocks:
        argv = [x for x in b.split("\n") if x != ""]
        if not argv:
            continue
        pos, opt = parse(argv)
        k = kind(opt)
        opt["release"], opt["arch"] = (m.group(3), m.group(4)) if k == "NANO" else (m.group(1), m.group(2))
        out[k] = opt
    return out


def main():
    nblock = 0
    for era in ORACLE:
        o, lines = ours(era), []
        lines.append(f"# recipe diff, era {era}: chain_job_v2.sh (dry run) vs McM get_setup (public API, read 2026-11-02)")
        for step in ["GS", "PREMIX", "RECO", "NANO"]:
            if step in ORACLE[era]:
                ref, src = oracle(ORACLE[era][step])[step], ORACLE[era][step]
            else:
                e, gt = BRIEF_NANO[era]
                ref = {"release": "CMSSW_16_0_10", "arch": "el8_amd64_gcc13", "--scenario": "pp", "--mc": True,
                       "--step": "PAT,NANO:@EXO", "--datatier": "NANOAODSIM", "--eventcontent": "NANOEDMAODSIM1",
                       "--era": e, "--conditions": gt, "--customise": "Configuration/DataProcessing/Utils.addMonitoring"}
                src = "brief round-2 recipe (no EXONano request for this era in McM)"
            mine = o[step]
            lines.append(f"\n## {step}  reference: {src}")
            keys = sorted(set(ref) | set(mine), key=lambda k: (COMPARED.index(k) if k in COMPARED else 99, k))
            for k in keys:
                a, b = ref.get(k), mine.get(k)
                if a == b:
                    lines.append(f"  same     {k} = {a}")
                    continue
                allowed = k in ALLOWED
                if k == "--customise":   # addMonitoring is allowed to differ
                    strip = lambda v: {x for x in str(v or "").split(",") if x and x != "Configuration/DataProcessing/Utils.addMonitoring"}
                    allowed = strip(a) == strip(b)
                note = ""
                if not allowed and era in ("2022", "2022EE"):
                    extra = {x for x in str(b or "").split(",") if x} - {x for x in str(a or "").split(",") if x}
                    if k == "--outputCommands" and a is None and (step, k, b) in APPROVED:
                        allowed, note = "approved", APPROVED[(step, k, b)]
                    elif k == "--customise" and {x for x in str(a or "").split(",") if x} <= {x for x in str(b or "").split(",")} \
                            and all((step, k, x) in APPROVED or x == "Configuration/DataProcessing/Utils.addMonitoring" for x in extra):
                        allowed, note = "approved", "; ".join(APPROVED[(step, k, x)] for x in extra if (step, k, x) in APPROVED)
                tag = "APPROVED" if allowed == "approved" else "allowed " if allowed else "BLOCKING"
                nblock += not allowed
                lines.append(f"  {tag} {k}: mcm={a!r}  ours={b!r}" + (f"  [round 3: {note}]" if note else ""))
        open(os.path.join(HERE, "..", f"recipe_diff_{era}.txt"), "w").write("\n".join(lines) + "\n")
        print(f"{era}: BLOCKING lines = {sum('BLOCKING' in l for l in lines)}")
    return nblock


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
