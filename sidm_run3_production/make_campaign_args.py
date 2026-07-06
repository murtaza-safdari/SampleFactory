#!/usr/bin/env python3
"""make_campaign_args.py -- generate Condor args for the Run3 SIDM signal campaign, or for the
GEN-level validation scan.

Campaign args (7 fields: MBs MDp CHAN CTAU ERA NEV JOBIDX), consumed by campaign.sub:
    make_campaign_args.py POINTS_FILE ERA EVENTS_PER_SAMPLE EVENTS_PER_JOB [--channels 4Mu,2Mu2E]
GEN-validation args (4 fields: MBs MDp CHAN CTAU), consumed by gen_validate.sub:
    make_campaign_args.py POINTS_FILE --gen-validate [--channels 4Mu,2Mu2E]

POINTS_FILE: one v10 sample key per line, e.g.  4Mu_200GeV_1p2GeV_0p48mm
JOBIDX is unique per (point, era, job) so EOS output names never collide.
"""
import sys, math, argparse

VALID_CHANS = {"4Mu", "2Mu2E"}


def parse(key):
    p = key.strip().split("_")
    return p[0], p[1][:-3], p[2][:-3].replace("p", "."), p[3][:-2].replace("p", ".")  # chan, mbs, mdp, ctau


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("points_file")
    ap.add_argument("era", nargs="?", help="Run3 era (required unless --gen-validate)")
    ap.add_argument("events_per_sample", nargs="?", type=int)
    ap.add_argument("events_per_job", nargs="?", type=int)
    ap.add_argument("--channels", help="comma-separated subset of 4Mu,2Mu2E")
    ap.add_argument("--gen-validate", action="store_true",
                    help="emit 4-field GEN-validation args (one line per point) instead of campaign args")
    a = ap.parse_args()

    chans = None
    if a.channels:
        chans = set(a.channels.split(","))
        bad = chans - VALID_CHANS
        if bad:
            ap.error(f"unknown channel(s): {sorted(bad)} (valid: {sorted(VALID_CHANS)})")
    if not a.gen_validate and (a.era is None or a.events_per_sample is None or a.events_per_job is None):
        ap.error("campaign mode needs ERA EVENTS_PER_SAMPLE EVENTS_PER_JOB (or pass --gen-validate)")

    njobs = 0 if a.gen_validate else math.ceil(a.events_per_sample / a.events_per_job)
    n = 0
    for line in open(a.points_file):
        key = line.strip()
        if not key:
            continue
        chan, mbs, mdp, ctau = parse(key)
        if chans and chan not in chans:
            continue
        if a.gen_validate:
            print(f"{mbs} {mdp} {chan} {ctau}"); n += 1
        else:
            for j in range(njobs):
                print(f"{mbs} {mdp} {chan} {ctau} {a.era} {a.events_per_job} j{j:03d}"); n += 1
    mode = "gen-validate points" if a.gen_validate else f"jobs ({njobs} jobs/sample x samples, era={a.era})"
    sys.stderr.write(f"# {n} {mode}\n")


if __name__ == "__main__":
    main()
