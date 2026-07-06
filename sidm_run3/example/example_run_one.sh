#!/bin/bash
# example_run_one.sh -- run ONE Run 3 SIDM signal point end to end and check the physics.
#
# Demonstrates the whole recipe on a single point (4Mu, M_Bs=200, M_Zd=1.2, ctau=0.48 mm, era 2022,
# 50 events): gridpack -> GEN-SIM -> premix -> RECO/AODSIM -> the LLPNanoAOD add-on. The GEN-SIM /
# premix / RECO conditions here are the era-2022 values from data/chains/Run3/chain_Run3Summer22_SIDM.json
# (for other eras/points, take the conditions from the corresponding chain JSON).
#
# Run it inside the el8 CMSSW image:
#   /cvmfs/cms.cern.ch/common/cmssw-el8 -B /uscms_data/d3 -- bash example_run_one.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)   # sidm_run3/example
REPO=$(cd "$HERE/../.." && pwd)       # repo root (SampleFactory)
WORK=$(mktemp -d); cd "$WORK"
source /cvmfs/cms.cern.ch/cmsset_default.sh
export X509_USER_PROXY=/uscms_data/d3/murtazas/x509_proxy.pem
EOS=root://cmseos.fnal.gov//store/group/lpcmetx/SIDM/run3_samplegen
echo "======== example_run_one : 4Mu MBs-200 MDp-1p2 ctau-0p48 era-2022 ========  $(date)  ($WORK)"

# ---- one gridpack per (mass,mass,channel); the ctau is set in Pythia (32:tau0), not the gridpack ----
export GRIDPACK=$WORK/gp.tar.xz
xrdcp -f -N $EOS/gridpacks/SIDM_BsTo2DpTo4Mu_MBs-200_MDp-1p2_gridpack.tar.xz "$GRIDPACK" || { echo "FAIL gridpack"; exit 1; }
export CTAU=0.48

# ---- GEN-SIM (CMSSW_12_4_19), the SIDM fragment ----
export SCRAM_ARCH=el8_amd64_gcc10
scram project CMSSW_12_4_19 >/dev/null 2>&1; cd CMSSW_12_4_19/src; eval `scram runtime -sh`
mkdir -p Configuration/GenProduction/python
cp "$REPO/data/fragments/SIDM_BsTo2DpTo4l_TuneCP5_13p6TeV_cff.py" Configuration/GenProduction/python/SIDM_frag_cff.py
scram b -j4 >/dev/null 2>&1
cmsDriver.py Configuration/GenProduction/python/SIDM_frag_cff.py --python_filename gs.py \
  --eventcontent RAWSIM --datatier GEN-SIM --fileout file:gensim.root \
  --conditions 124X_mcRun3_2022_realistic_v12 --beamspot Realistic25ns13p6TeVEarly2022Collision \
  --step LHE,GEN,SIM --geometry DB:Extended --era Run3 --mc -n 50 --nThreads 4 --no_exec >/dev/null 2>&1
cmsRun gs.py > "$WORK/gensim.log" 2>&1 || { echo "FAIL GEN-SIM"; tail -20 "$WORK/gensim.log"; exit 1; }
GENSIM=$(pwd)/gensim.root; cp "$GENSIM" "$WORK/SIDMchk_gen.root"

# ---- premix (CMSSW_12_4_16) ----
cd "$WORK"; scram project CMSSW_12_4_16 >/dev/null 2>&1; cd CMSSW_12_4_16/src; eval `scram runtime -sh`
cmsDriver.py step1 --mc --eventcontent PREMIXRAW --datatier GEN-SIM-RAW --conditions 124X_mcRun3_2022_realistic_v12 \
  --step DIGI,DATAMIX,L1,DIGI2RAW,HLT:2022v12 --procModifiers premix_stage2,siPixelQualityRawToDigi --datamix PreMix \
  --pileup_input "dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer22_124X_mcRun3_2022_realistic_v11-v2/PREMIX" \
  --era Run3 --geometry DB:Extended --nThreads 4 --filein file:$GENSIM --fileout file:premix.root \
  --python_filename premix.py --no_exec -n -1 >/dev/null 2>&1
cmsRun premix.py > "$WORK/premix.log" 2>&1 || { echo "FAIL premix"; tail -20 "$WORK/premix.log"; exit 1; }

# ---- RECO -> AODSIM (CMSSW_12_4_16) ----
cmsDriver.py step2 --mc --eventcontent AODSIM --datatier AODSIM --conditions 124X_mcRun3_2022_realistic_v12 \
  --step RAW2DIGI,L1Reco,RECO,RECOSIM --procModifiers siPixelQualityRawToDigi --era Run3 --geometry DB:Extended \
  --nThreads 4 --filein file:premix.root --fileout file:aodsim.root --python_filename reco.py --no_exec -n -1 >/dev/null 2>&1
cmsRun reco.py > "$WORK/reco.log" 2>&1 || { echo "FAIL RECO"; tail -20 "$WORK/reco.log"; exit 1; }
AOD=$(pwd)/aodsim.root

# ---- THE one SIDM step: LLPNanoAOD add-on ----
cd "$WORK"; bash "$HERE/../run_llpnano.sh" "$AOD" 2022PreEE nano.root > "$WORK/llpnano.log" 2>&1 || { echo "FAIL LLPNanoAOD"; tail -20 "$WORK/llpnano.log"; exit 1; }
NANO=$(ls -S "$WORK"/CMSSW_13_0_13/src/nano*.root "$WORK"/CMSSW_13_0_13/src/*NANO*.root 2>/dev/null | head -1)

# ================= PHYSICS CHECK =================
echo "-------- physics check --------"
# masses + lifetime from GEN-SIM (FWLite; the validated per-point check)
python3 "$HERE/check_grid_point.py" "$WORK/SIDMchk" 0.48 2>/dev/null
# displaced content + event count from the final nano
python3 - "$NANO" <<'PYEOF'
import sys, ROOT
f = ROOT.TFile.Open(sys.argv[1]); t = f.Get("Events")
bs = [b.GetName() for b in t.GetListOfBranches()]
print("NANOCHECK nEv=%d DSAMuon=%s GenPart_vx=%s dsaMatch=%s" % (
    t.GetEntries(), any(b.startswith("DSAMuon") for b in bs), "GenPart_vx" in bs,
    any("dsaMatch" in b for b in bs)))
PYEOF
echo "======== example_run_one DONE ========  $(date)"
