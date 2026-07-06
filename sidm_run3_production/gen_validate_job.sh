#!/bin/bash
# gen_validate_job.sh  MBs  MDp  CHAN  CTAU
# GEN-level lifetime+kinematics validation for one grid point (500 ev, LHE+GEN only),
# using the SAME ctau-less gridpack + fixed fragment as the production chain. Emits a
# RESULT line (masses, channel lepton counts, measured/nominal proper ctau) to EOS/validation/.
MBs=$1; MDp=$2; CHAN=$3; CTAU=$4
MDpT=$(echo $MDp | sed 's/\./p/'); CTAUT=$(echo $CTAU | sed 's/\./p/')
NAME=SIDM_BsTo2DpTo${CHAN}_MBs-${MBs}_MDp-${MDpT}_ctau-${CTAUT}
GPBASE=SIDM_BsTo2DpTo${CHAN}_MBs-${MBs}_MDp-${MDpT}
EOS=root://cmseos.fnal.gov//store/group/lpcmetx/SIDM/run3_samplegen
EOSP=/store/group/lpcmetx/SIDM/run3_samplegen
WORKDIR=$(pwd)
echo "######## GEN-VALIDATE $NAME ######## $(date) host=$(hostname)"
source /cvmfs/cms.cern.ch/cmsset_default.sh
export SCRAM_ARCH=el8_amd64_gcc10
statsize(){ xrdfs root://cmseos.fnal.gov stat "$1" 2>/dev/null | grep -oE 'Size:[[:space:]]*[0-9]+' | grep -oE '[0-9]+'; }

EXIST=$(statsize $EOSP/validation/${NAME}.txt)
if [ -n "$EXIST" ] && [ "$EXIST" -gt 10 ]; then echo "### SKIP: result exists ###"; exit 0; fi

xrdcp -f -N $EOS/gridpacks/${GPBASE}_gridpack.tar.xz $WORKDIR/gp.tar.xz || { echo "FAIL gp xrdcp"; exit 3; }
GP=$WORKDIR/gp.tar.xz

scram project CMSSW_12_4_20 >/dev/null 2>&1 || { echo "FAIL cmsrel"; exit 4; }
cd CMSSW_12_4_20/src; eval `scram runtime -sh`
mkdir -p Configuration/GenProduction/python
cat > Configuration/GenProduction/python/${NAME}_cff.py <<EOF
import FWCore.ParameterSet.Config as cms
externalLHEProducer = cms.EDProducer("ExternalLHEProducer", args=cms.vstring('$GP'),
    nEvents=cms.untracked.uint32(500), numberOfParameters=cms.uint32(1),
    outputFile=cms.string('cmsgrid_final.lhe'),
    scriptName=cms.FileInPath('GeneratorInterface/LHEInterface/data/run_generic_tarball_cvmfs.sh'))
from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.MCTunesRun3ECM13p6TeV.PythiaCP5Settings_cfi import *
from Configuration.Generator.PSweightsPythia.PythiaPSweightsSettings_cfi import *
generator = cms.EDFilter("Pythia8HadronizerFilter", maxEventsToPrint=cms.untracked.int32(0),
    pythiaPylistVerbosity=cms.untracked.int32(0), filterEfficiency=cms.untracked.double(1.0),
    pythiaHepMCVerbosity=cms.untracked.bool(False), comEnergy=cms.double(13600.),
    PythiaParameters=cms.PSet(pythia8CommonSettingsBlock, pythia8CP5SettingsBlock, pythia8PSweightsSettingsBlock,
        processParameters=cms.vstring('ParticleDecays:tau0Max = 1000.1','LesHouches:setLifetime = 2',
            'SLHA:useDecayTable = off','32:tau0 = $CTAU','32:tauCalc = off','32:mayDecay = on'),
        parameterSets=cms.vstring('pythia8CommonSettings','pythia8CP5Settings','pythia8PSweightsSettings','processParameters')))
ProductionFilterSequence = cms.Sequence(generator)
EOF
scram b -j4 > $WORKDIR/scramb.log 2>&1 || { echo "FAIL scram b"; tail -25 $WORKDIR/scramb.log; exit 4; }
cmsDriver.py Configuration/GenProduction/python/${NAME}_cff.py --python_filename ${NAME}_gen.py \
  --eventcontent RAWSIM --datatier GEN-SIM --fileout file:${NAME}_gen.root \
  --conditions 124X_mcRun3_2022_realistic_v12 --beamspot Realistic25ns13p6TeVEarly2022Collision \
  --step LHE,GEN --era Run3 --mc -n 500 --nThreads 2 --no_exec > $WORKDIR/gs_drv.log 2>&1 || { echo "FAIL cmsDriver"; tail -25 $WORKDIR/gs_drv.log; exit 5; }
cmsRun ${NAME}_gen.py > $WORKDIR/gen.log 2>&1 || { echo "FAIL GEN"; tail -25 $WORKDIR/gen.log; exit 6; }

python3 $WORKDIR/check_grid_point.py $NAME $CTAU > $WORKDIR/result.txt 2>&1
cat $WORKDIR/result.txt
grep -q "RESULT " $WORKDIR/result.txt || { echo "FAIL check_grid_point"; cat $WORKDIR/result.txt; exit 6; }
xrdfs root://cmseos.fnal.gov mkdir -p $EOSP/validation 2>/dev/null
xrdcp -f -N $WORKDIR/result.txt $EOS/validation/${NAME}.txt || { echo "FAIL result xrdcp"; exit 7; }
echo "######## GEN-VALIDATE DONE -> validation/${NAME}.txt ######## $(date)"
