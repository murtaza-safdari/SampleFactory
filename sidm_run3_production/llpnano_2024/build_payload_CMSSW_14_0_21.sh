#!/bin/bash
# build_payload_CMSSW_14_0_21.sh  -- build the 2024 LLPNanoAOD payload (run in an el8 shell, e.g. cmssw-el8).
# The 13_0_13 payload cannot open 14_0_X (2024) AODSIM (PoolSource FileOpenError), so 2024 gets its own
# build of the same code: cms-sidm/LLPNanoAOD @ LLPnanoAODv1_Run3_devel (164e620) with the same
# RecoVertex/PhysicsTools corrections (the stock files they replace are identical in 13_0_13 and 14_0_21),
# plus LLPnanoAOD_PAT_Run3_cfg_2024.patch: a year=2024 switch (era Run3_2024, GT 140X_mcRun3_2024_realistic_v26,
# as central RunIII2024Summer24MiniAOD/NanoAOD in 14_0_X) and removal of the process.options FailPath/SkipEvent
# parameters, which 14_0 rejects.  Output: payload_CMSSW_14_0_21.tar.gz in the current directory.
set -e
HERE=$(cd $(dirname $0) && pwd); TOP=$(pwd)
source /cvmfs/cms.cern.ch/cmsset_default.sh; export SCRAM_ARCH=el8_amd64_gcc12
scram project CMSSW CMSSW_14_0_21
cd CMSSW_14_0_21/src; eval `scram runtime -sh`
for p in RecoVertex/KalmanVertexFit RecoVertex/VertexTools PhysicsTools/RecoUtils; do mkdir -p $(dirname $p); cp -r $CMSSW_RELEASE_BASE/src/$p $p; done
git clone -q https://github.com/cms-sidm/LLPNanoAOD.git LLPNanoAOD
(cd LLPNanoAOD && git checkout -q 164e620 && patch -p1 < $HERE/LLPnanoAOD_PAT_Run3_cfg_2024.patch)
cp LLPNanoAOD/RecoVertex_corrections/VertexTools/src/* RecoVertex/VertexTools/src/
cp LLPNanoAOD/RecoVertex_corrections/VertexTools/interface/* RecoVertex/VertexTools/interface/
cp LLPNanoAOD/RecoVertex_corrections/KalmanVertexFit/src/* RecoVertex/KalmanVertexFit/src/
cp LLPNanoAOD/PhysicsTools_corrections/RecoUtils/src/* PhysicsTools/RecoUtils/src/
cp LLPNanoAOD/PhysicsTools_corrections/RecoUtils/interface/* PhysicsTools/RecoUtils/interface/
scram b -j 6
cd $TOP; tar czf payload_CMSSW_14_0_21.tar.gz --exclude=CMSSW_14_0_21/tmp --exclude=.git CMSSW_14_0_21
echo "built $TOP/payload_CMSSW_14_0_21.tar.gz"
