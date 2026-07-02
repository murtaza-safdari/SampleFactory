#!/usr/bin/env python3
# make_campaign_args.py -- generate Condor job_args for the Run3 SIDM signal campaign.
#
#   make_campaign_args.py POINTS_FILE ERA EVENTS_PER_SAMPLE EVENTS_PER_JOB [--channels 4Mu,2Mu2E]
#
# POINTS_FILE: one v10 sample key per line, e.g.  4Mu_200GeV_1p2GeV_0p48mm
# Emits one whitespace line per job (consumed by campaign.sub's `queue ... from`):
#   MBs  MDp  CHAN  CTAU  ERA  NEV  JOBIDX
# JOBIDX is unique per (point, era, job) so EOS output names never collide.
import sys, math

def parse(key):
    p = key.strip().split('_')
    chan = p[0]                          # 4Mu | 2Mu2E
    mbs  = p[1][:-3]                     # '200GeV'  -> 200
    mdp  = p[2][:-3].replace('p', '.')   # '1p2GeV'  -> 1.2
    ctau = p[3][:-2].replace('p', '.')   # '0p48mm'  -> 0.48
    return chan, mbs, mdp, ctau

def main():
    pts_file, era, ev_sample, ev_job = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    chans = None
    if '--channels' in sys.argv:
        chans = set(sys.argv[sys.argv.index('--channels') + 1].split(','))
    njobs = math.ceil(ev_sample / ev_job)
    n = 0
    for line in open(pts_file):
        key = line.strip()
        if not key:
            continue
        chan, mbs, mdp, ctau = parse(key)
        if chans and chan not in chans:
            continue
        for j in range(njobs):
            print(f"{mbs} {mdp} {chan} {ctau} {era} {ev_job} j{j:03d}")
            n += 1
    sys.stderr.write(f"# {n} jobs  ({njobs} jobs/sample x samples)  era={era} nev/job={ev_job}\n")

if __name__ == '__main__':
    main()
