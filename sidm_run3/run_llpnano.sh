#!/bin/bash
# run_llpnano.sh  <AODSIM_file>  <year>  [output.root]
#
# THE one SIDM-specific step. The SampleFactory/IDM chain and Sunil's chain both stop at the
# standard tiers (MiniAOD / central NanoAOD), which slim away the displaced muons the search
# needs. This step runs the custom LLPNanoAOD (PAT->NANO) on the AODSIM the chain produces, so
# the displaced content survives: the DSAMuon table, Muon.dsaMatch* indices, and the extended
# GenPart vertex fields.
#
#   year in {2022PreEE, 2022PostEE, 2023PreBPix, 2023PostBPix} -- selects the MiniAOD/NANO global tag.
#
# Uses the prebuilt cms-sidm/LLPNanoAOD @ LLPnanoAODv1_Run3_devel payload (CMSSW_13_0_13) staged on
# EOS (see the README for how it is built).
set -u
AOD=$1; YEAR=$2; OUT=${3:-llpnano.root}
EOS=root://cmseos.fnal.gov//store/group/lpcmetx/SIDM/run3_samplegen
source /cvmfs/cms.cern.ch/cmsset_default.sh
export SCRAM_ARCH=el8_amd64_gcc11

xrdcp -f -N $EOS/payload/payload_CMSSW_13_0_13.tar.gz payload.tar.gz || { echo "FAIL payload xrdcp"; exit 1; }
tar xzf payload.tar.gz || { echo "FAIL untar payload"; exit 1; }
cd CMSSW_13_0_13; scram b ProjectRename >/dev/null 2>&1; cd src; eval `scram runtime -sh`

CFG=LLPNanoAOD/LLPnanoAOD/test/LLPnanoAOD_PAT_Run3_cfg.py
echo "### LLPNanoAOD PAT->NANO on $AOD (year=$YEAR) ### $(date)"
cmsRun "$CFG" inputFiles=file:$AOD outputFile=$OUT nEvents=0 runOnData=False \
  includeDSAMuon=True includeBS=True includeGenPart=True includeDGLMuon=False includeRefittedTracks=True \
  year=$YEAR || { echo "FAIL LLPNanoAOD"; exit 1; }
echo "### LLPNanoAOD done -> $(ls -S llpnano*.root *NANO*.root 2>/dev/null | head -1) ### $(date)"
