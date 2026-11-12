#!/bin/bash
# run_llpnano.sh  <AODSIM_file>  <year>  [output.root]
#
# THE one SIDM-specific step. The SampleFactory/IDM chain and Sunil's chain both stop at the
# standard tiers (MiniAOD / central NanoAOD), which slim away the displaced muons the search
# needs. This step runs the custom LLPNanoAOD (PAT->NANO) on the AODSIM the chain produces, so
# the displaced content survives: the DSAMuon table, Muon.dsaMatch* indices, and the extended
# GenPart vertex fields.
#
#   year in {2022PreEE, 2022PostEE, 2023PreBPix, 2023PostBPix, 2024} -- selects the MiniAOD/NANO global tag.
#
# Uses the prebuilt cms-sidm/LLPNanoAOD @ LLPnanoAODv1_Run3_devel payload staged on EOS (see
# sidm_run3_production/README.md for how it is built): CMSSW_13_0_13 for 2022-2023, CMSSW_14_0_21 for 2024
# (13_0_13 cannot open 14_0_X AODSIM; sidm_run3_production/llpnano_2024/ builds it). PAYLOAD=<local tarball>
# overrides the EOS copy.
set -u
AOD=$1; YEAR=$2; OUT=${3:-llpnano.root}
EOS=root://cmseos.fnal.gov//store/group/lpcmetx/SIDM/run3_samplegen
source /cvmfs/cms.cern.ch/cmsset_default.sh
case $YEAR in
  2024) NANOREL=CMSSW_14_0_21; export SCRAM_ARCH=el8_amd64_gcc12;;
  *)    NANOREL=CMSSW_13_0_13; export SCRAM_ARCH=el8_amd64_gcc11;;
esac

if [ -n "${PAYLOAD:-}" ]; then cp "$PAYLOAD" payload.tar.gz || { echo "FAIL payload cp"; exit 1; }
else xrdcp -f -N $EOS/payload/payload_${NANOREL}.tar.gz payload.tar.gz || { echo "FAIL payload xrdcp"; exit 1; }; fi
tar xzf payload.tar.gz || { echo "FAIL untar payload"; exit 1; }
cd $NANOREL; scram b ProjectRename >/dev/null 2>&1; cd src; eval `scram runtime -sh`

CFG=LLPNanoAOD/LLPnanoAOD/test/LLPnanoAOD_PAT_Run3_cfg.py
echo "### LLPNanoAOD PAT->NANO on $AOD (year=$YEAR) ### $(date)"
cmsRun "$CFG" inputFiles=file:$AOD outputFile=$OUT nEvents=0 runOnData=False \
  includeDSAMuon=True includeBS=True includeGenPart=True includeDGLMuon=False includeRefittedTracks=True \
  year=$YEAR || { echo "FAIL LLPNanoAOD"; exit 1; }
echo "### LLPNanoAOD done -> $(ls -S llpnano*.root *NANO*.root 2>/dev/null | head -1) ### $(date)"
