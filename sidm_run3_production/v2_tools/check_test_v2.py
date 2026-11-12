#!/usr/bin/env python3
"""check_test_v2.py -- gate 2 oracle on the v2 test nanos (one per era), reusing era_fingerprint.py's
provenance read-back. Run with the SIDM venv and PYTHONPATH=work/fp/sidm_head/sidm/studies/run3_signal_validation:work/fp/sidm_head
(the committed SIDM tree, HEAD 365aec29, exported with git archive).
Prints one block per era and writes work/test_fingerprint_v2.csv.
References: v1 era_fingerprint.csv for 2022-2023BPix (same premix libraries and beamspots as v2);
for 2024 a central RunIII2024Summer24 NANO file (pileup profile, beamspot from the GT) and the HLT_ count
of the 2024v14 menu in our round-1 LLPNano of a central 2024 AODSIM."""
import csv, sys, os
import numpy as np
import uproot
import era_fingerprint as ef

EOS = "root://cmseos.fnal.gov//store/group/lpcmetx/SIDM/run3_samplegen/outputs_v2/test"
NAME = "SIDM_BsTo2DpTo4Mu_MBs-200_MDp-1p2_ctau-4p8"
ERAS = ["2022", "2022EE", "2023", "2023BPix", "2024"]
NEED = ["DSAMuon_pt", "DSAMuon_muonMatch1idx", "DSAMuon_nSegments", "DSAMuon_dxyPVSigned", "Muon_pt",
        "Electron_pt", "GenPart_vx", "GenPart_pdgId", "LHEPart_pt"]
W = os.path.dirname(os.path.abspath(__file__))
V1 = {r["era"]: r for r in csv.DictReader(open(os.path.join(os.path.dirname(ef.__file__), "era_fingerprint.csv")))}


def ref2024():
    t = uproot.open(os.path.join(W, "llpnano_test", "central_2024_nano14.root"))["Events"]
    a = t.arrays(["Pileup_nTrueInt", "GenVtx_x", "GenVtx_y", "GenVtx_z"], library="np")
    nhlt = sum(k.startswith("HLT_") for k in uproot.open(os.path.join(W, "llpnano_build", "t14_central.root"))["Events"].keys())
    return dict(pileup_nTrueInt_mean=a["Pileup_nTrueInt"].mean(), genvtx_x_mean_cm=a["GenVtx_x"].mean(),
                genvtx_y_mean_cm=a["GenVtx_y"].mean(), genvtx_z_std_cm=a["GenVtx_z"].std(), n_hlt_branches=nhlt, n=len(a["GenVtx_x"]))


rows = []
r24 = ref2024()
for era in ERAS:
    url = f"{EOS}/{era}/{NAME}/{NAME}_{era}_t000.root"
    try:
        f = uproot.open(url)
    except Exception as e:
        print(f"== {era}: cannot open {url}: {e}"); continue
    keys = set(f["Events"].keys())
    mds = [p_ + "*" for p_ in ("cscMDSCluster_", "dtMDSCluster_") if not any(k.startswith(p_) for k in keys)]
    d = ef.read_file(url, None)
    p = ef.provenance(url)
    p["steps"] = [tuple(str(x).rstrip("\x00") if x else x for x in s) for s in p["steps"]]
    ref = V1.get(era) or {k: v for k, v in r24.items()}
    row = dict(era=era, events=d["n"], missing=";".join([b for b in NEED if b not in keys] + mds) or "none",
               n_hlt=len(d["hlt"]), sqrt_s_median=np.nanmedian(d["sqrts"]), sqrt_s_lhe_median=np.nanmedian(d["sqrts_lhe"]),
               com=p["com"], pileup_mean=np.nanmean(d["Pileup_nTrueInt"]), pileup_std=np.nanstd(d["Pileup_nTrueInt"]),
               vx_mean=np.nanmean(d["GenVtx_x"]), vy_mean=np.nanmean(d["GenVtx_y"]), z_std=np.nanstd(d["GenVtx_z"]),
               hlt_menu=p["hlt_menu"], vtxsmear=p["vtx"], steps=" | ".join(f"{n}:{r}:{g}" for n, r, g in p["steps"]),
               ref_pileup_mean=float(ref["pileup_nTrueInt_mean"]), ref_vx=float(ref["genvtx_x_mean_cm"]),
               ref_vy=float(ref["genvtx_y_mean_cm"]), ref_z_std=float(ref["genvtx_z_std_cm"]), ref_n_hlt=int(ref["n_hlt_branches"]))
    rows.append(row)
    print(f"== {era}: {row['events']} events, missing branches: {row['missing']}")
    for n, r, g in p["steps"]:
        print(f"   step {n:10s} {r:22s} {g}")
    print(f"   HLT menu {row['hlt_menu']}  HLT_ branches {row['n_hlt']} (ref {row['ref_n_hlt']})")
    print(f"   sqrt(s) median {row['sqrt_s_median']:.0f} GeV (LHE {row['sqrt_s_lhe_median']:.0f}), comEnergy {row['com']}")
    print(f"   pileup nTrueInt mean {row['pileup_mean']:.2f} +- {row['pileup_std'] / np.sqrt(max(row['events'], 1)):.2f} (ref {row['ref_pileup_mean']:.2f})")
    print(f"   GenVtx x {row['vx_mean']:.4f} y {row['vy_mean']:.4f} z_std {row['z_std']:.3f} cm "
          f"(ref {row['ref_vx']:.4f} {row['ref_vy']:.4f} {row['ref_z_std']:.3f}); VtxSmeared PSet {row['vtxsmear']}")
print(f"# 2024 reference: central RunIII2024Summer24NanoAOD file, {r24['n']} events")
with open(os.path.join(W, "test_fingerprint_v2.csv"), "w", newline="") as fo:
    if rows:
        w = csv.DictWriter(fo, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
