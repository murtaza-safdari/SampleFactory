#!/usr/bin/env python3
"""Generate the SIDM Run 3 SampleFactory chain JSONs (gen -> AODSIM), one per era.

Each is IDM's Run 3 chain structure (GENSIM -> DIGIPremix -> RECO) with the per-era conditions set
to our McM-verified values (which match Sunil's table), the SIDM fragment injected into the GEN
step (runFactory does this for any step whose name contains 'GEN'), and KEEPS = the RECO/AODSIM step
(the LLPNanoAOD add-on runs on that AODSIM). No MiniAOD/NanoAOD step -- that is where this differs
from the IDM/central chains.
"""
import json, sys, os

OUT = sys.argv[1] if len(sys.argv) > 1 else "."

# Per-era conditions -- all McM-verified against real central DRPremix datasets (and cross-checked
# vs Sunil's smdogra/SiDM run3TarBallMiniAOD). recomod="" for 2023/23BPix (they must NOT carry the
# 2022 siPixelQualityRawToDigi reco procModifier). Note 2022EE uses the Summer22 (non-EE) premix.
ERAS = {
 "Run3Summer22": dict(
   gs="CMSSW_12_4_19", gsarch="el8_amd64_gcc10", dr="CMSSW_12_4_16", drarch="el8_amd64_gcc10",
   gt="124X_mcRun3_2022_realistic_v12", bs="Realistic25ns13p6TeVEarly2022Collision",
   hlt="2022v12", era="Run3", premixmod="premix_stage2,siPixelQualityRawToDigi", recomod="siPixelQualityRawToDigi",
   pu="dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer22_124X_mcRun3_2022_realistic_v11-v2/PREMIX"),
 "Run3Summer22EE": dict(
   gs="CMSSW_12_4_11_patch3", gsarch="el8_amd64_gcc10", dr="CMSSW_12_4_11_patch3", drarch="el8_amd64_gcc10",
   gt="124X_mcRun3_2022_realistic_postEE_v1", bs="Realistic25ns13p6TeVEarly2022Collision",
   hlt="2022v14", era="Run3", premixmod="premix_stage2,siPixelQualityRawToDigi", recomod="siPixelQualityRawToDigi",
   pu="dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer22_124X_mcRun3_2022_realistic_v11-v2/PREMIX"),
 "Run3Summer23": dict(
   gs="CMSSW_13_0_17", gsarch="el8_amd64_gcc11", dr="CMSSW_13_0_14", drarch="el8_amd64_gcc11",
   gt="130X_mcRun3_2023_realistic_v14", bs="Realistic25ns13p6TeVEarly2023Collision",
   hlt="2023v12", era="Run3_2023", premixmod="premix_stage2", recomod="",
   pu="dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer23_130X_mcRun3_2023_realistic_v13-v1/PREMIX"),
 "Run3Summer23BPix": dict(
   gs="CMSSW_13_0_14", gsarch="el8_amd64_gcc11", dr="CMSSW_13_0_14", drarch="el8_amd64_gcc11",
   gt="130X_mcRun3_2023_realistic_postBPix_v6", bs="Realistic25ns13p6TeVEarly2023Collision",
   hlt="2023v12", era="Run3_2023", premixmod="premix_stage2", recomod="",
   pu="dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer23BPix_130X_mcRun3_2023_realistic_postBPix_v1-v1/PREMIX"),
}

CUST = {"files": [], "pre-cmsRun": [], "post-cmsRun": []}

for era, c in ERAS.items():
    gensim, premix, reco = f"{era}GENSIM", f"{era}DIGIPremix", f"{era}RECO"
    reco_opts = {"eventcontent": "AODSIM", "datatier": "AODSIM", "conditions": c["gt"],
                 "step": "RAW2DIGI,L1Reco,RECO,RECOSIM", "geometry": "DB:Extended", "era": c["era"], "mc": None}
    if c["recomod"]:
        reco_opts["procModifiers"] = c["recomod"]
    chain = {
        "STEPS": [gensim, premix, reco],
        "KEEPS": [reco],
        "WORKFLOWS": {
            gensim: {"SCRAM_ARCH": c["gsarch"], "CMSSW_VERSION": c["gs"], "CUSTOMIZES": dict(CUST),
                     "OPTIONS": {"eventcontent": "RAWSIM", "datatier": "GEN-SIM", "conditions": c["gt"],
                                 "beamspot": c["bs"], "step": "LHE,GEN,SIM", "geometry": "DB:Extended",
                                 "era": c["era"], "mc": None}},
            premix: {"SCRAM_ARCH": c["drarch"], "CMSSW_VERSION": c["dr"], "CUSTOMIZES": dict(CUST),
                     "OPTIONS": {"eventcontent": "PREMIXRAW", "datatier": "GEN-SIM-RAW", "conditions": c["gt"],
                                 "step": f"DIGI,DATAMIX,L1,DIGI2RAW,HLT:{c['hlt']}", "procModifiers": c["premixmod"],
                                 "geometry": "DB:Extended", "datamix": "PreMix", "era": c["era"],
                                 "pileup_input": c["pu"], "mc": None}},
            reco: {"SCRAM_ARCH": c["drarch"], "CMSSW_VERSION": c["dr"], "CUSTOMIZES": dict(CUST), "OPTIONS": reco_opts},
        },
    }
    path = os.path.join(OUT, f"chain_{era}_SIDM.json")
    json.dump(chain, open(path, "w"), indent=1)
    print(f"wrote {path}")
