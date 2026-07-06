#!/bin/bash
# chain_job.sh  MBs  MDp  CHAN  CTAU  ERA  NEV  JOBIDX
# Full Run3 SIDM signal chain on a Condor worker (el8 image, self-contained in scratch):
#   xrdcp gridpack -> GEN-SIM -> premix -> RECO/AODSIM -> custom LLPNanoAOD -> xrdcp nano to EOS.
# Workers do NOT mount /uscms_data: every input comes via xrdcp from EOS; cvmfs for stock releases.
# One gridpack per (MBs,MDp,channel) serves all 5 ctau (Pythia 32:tau0 sets ctau; gridpack width ignored).
MBs=$1; MDp=$2; CHAN=$3; CTAU=$4; ERA=$5; NEV=$6; JOBIDX=$7
MDpT=$(echo $MDp | sed 's/\./p/'); CTAUT=$(echo $CTAU | sed 's/\./p/')
NAME=SIDM_BsTo2DpTo${CHAN}_MBs-${MBs}_MDp-${MDpT}_ctau-${CTAUT}     # per-point (ctau in name -> output only)
GPBASE=SIDM_BsTo2DpTo${CHAN}_MBs-${MBs}_MDp-${MDpT}                 # per-cell (ctau-less -> gridpack)
EOS=root://cmseos.fnal.gov//store/group/lpcmetx/SIDM/run3_samplegen
EOSP=/store/group/lpcmetx/SIDM/run3_samplegen
OUTNAME=${NAME}_${ERA}_${JOBIDX}.root
WORKDIR=$(pwd)
echo "######## CHAIN $NAME  ERA=$ERA NEV=$NEV JOBIDX=$JOBIDX ######## $(date)"
echo "host=$(hostname)  os=$(cat /etc/redhat-release 2>/dev/null)  scratch=$WORKDIR"
source /cvmfs/cms.cern.ch/cmsset_default.sh

statsize(){ xrdfs root://cmseos.fnal.gov stat "$1" 2>/dev/null | grep -oE 'Size:[[:space:]]*[0-9]+' | grep -oE '[0-9]+'; }
fail(){ echo "### FAIL at $1 (exit $2) ### $(date)"; [ -n "$3" ] && tail -40 "$3" 2>/dev/null; exit $2; }

# ---- idempotency: skip if a good output already exists on EOS ----
EXIST=$(statsize $EOSP/outputs/$ERA/$NAME/$OUTNAME)
if [ -n "$EXIST" ] && [ "$EXIST" -gt 100000 ]; then
  echo "### SKIP: output already exists ($EXIST bytes) -> $EOSP/outputs/$ERA/$NAME/$OUTNAME ###"; exit 0
fi

# ---- per-era config (McM-grounded: exact central-production recipe per campaign) ----
# GSREL/GSARCH: GEN-SIM release; DRREL/DRARCH: premix+reco release; COND: global tag (same across GS/DR steps);
# BS: beamspot; HLT: premix HLT menu; PU: premix pileup dataset; ERAMOD: cmsDriver --era; NYEAR: LLPnano year token.
# PREMIXMOD/RECOMOD: per-era procModifiers (2022/22EE need siPixelQualityRawToDigi; 2023/23BPix must NOT use it).
case $ERA in
  2022)     GSREL=CMSSW_12_4_19;        GSARCH=el8_amd64_gcc10; DRREL=CMSSW_12_4_16;        DRARCH=el8_amd64_gcc10
            COND=124X_mcRun3_2022_realistic_v12;             BS=Realistic25ns13p6TeVEarly2022Collision; HLT=2022v12; ERAMOD=Run3
            PREMIXMOD=premix_stage2,siPixelQualityRawToDigi; RECOMOD=siPixelQualityRawToDigi
            PU="dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer22_124X_mcRun3_2022_realistic_v11-v2/PREMIX"; NYEAR=2022PreEE;;
  2022EE)   GSREL=CMSSW_12_4_11_patch3; GSARCH=el8_amd64_gcc10; DRREL=CMSSW_12_4_11_patch3; DRARCH=el8_amd64_gcc10
            COND=124X_mcRun3_2022_realistic_postEE_v1;       BS=Realistic25ns13p6TeVEarly2022Collision; HLT=2022v14; ERAMOD=Run3
            PREMIXMOD=premix_stage2,siPixelQualityRawToDigi; RECOMOD=siPixelQualityRawToDigi
            PU="dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer22_124X_mcRun3_2022_realistic_v11-v2/PREMIX"; NYEAR=2022PostEE;;
  2023)     GSREL=CMSSW_13_0_17;        GSARCH=el8_amd64_gcc11; DRREL=CMSSW_13_0_14;        DRARCH=el8_amd64_gcc11
            COND=130X_mcRun3_2023_realistic_v14;             BS=Realistic25ns13p6TeVEarly2023Collision; HLT=2023v12; ERAMOD=Run3_2023
            PREMIXMOD=premix_stage2; RECOMOD=
            PU="dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer23_130X_mcRun3_2023_realistic_v13-v1/PREMIX"; NYEAR=2023PreBPix;;
  2023BPix) GSREL=CMSSW_13_0_14;        GSARCH=el8_amd64_gcc11; DRREL=CMSSW_13_0_14;        DRARCH=el8_amd64_gcc11
            COND=130X_mcRun3_2023_realistic_postBPix_v6;     BS=Realistic25ns13p6TeVEarly2023Collision; HLT=2023v12; ERAMOD=Run3_2023
            PREMIXMOD=premix_stage2; RECOMOD=
            PU="dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer23BPix_130X_mcRun3_2023_realistic_postBPix_v1-v1/PREMIX"; NYEAR=2023PostBPix;;
  *) echo "FATAL: unknown ERA=$ERA"; exit 2;;
esac
RECOPM=""; [ -n "$RECOMOD" ] && RECOPM="--procModifiers $RECOMOD"
echo "era-config: GS=$GSREL/$GSARCH DR=$DRREL/$DRARCH GT=$COND HLT=$HLT era=$ERAMOD premixmod=$PREMIXMOD recomod=${RECOMOD:-none} nano-year=$NYEAR"

# ---- fetch gridpack (ctau-less, per cell) ----
GPNAME=${GPBASE}_gridpack.tar.xz
echo "### xrdcp gridpack $GPNAME ### $(date)"
xrdcp -f -N $EOS/gridpacks/$GPNAME $WORKDIR/$GPNAME || { echo "### FAIL gridpack xrdcp ($GPNAME) ###"; exit 3; }
GP=$WORKDIR/$GPNAME

# RNG: populate() draws an independent OS-entropy seed per job -> statistically independent chunks
# (idempotency skip above prevents re-running a chunk that already succeeded).
RNG='--customise_commands=from IOMC.RandomEngine.RandomServiceHelper import RandomNumberServiceHelper as _R; _R(process.RandomNumberGeneratorService).populate()'

# ================= STEP 1: GEN-SIM =================
export SCRAM_ARCH=$GSARCH
cd $WORKDIR; scram project $GSREL >/dev/null 2>&1 || { echo "FAIL cmsrel $GSREL"; exit 4; }
cd $GSREL/src; eval `scram runtime -sh`
mkdir -p Configuration/GenProduction/python
cat > Configuration/GenProduction/python/${NAME}_cff.py <<EOF
import FWCore.ParameterSet.Config as cms
externalLHEProducer = cms.EDProducer("ExternalLHEProducer", args=cms.vstring('$GP'),
    nEvents=cms.untracked.uint32($NEV), numberOfParameters=cms.uint32(1),
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
scram b -j4 > $WORKDIR/scramb1.log 2>&1 || fail STEP1_SCRAMB $? $WORKDIR/scramb1.log
echo "### STEP1 GEN-SIM n=$NEV ### $(date)"
cmsDriver.py Configuration/GenProduction/python/${NAME}_cff.py --python_filename gs_cfg.py \
  --eventcontent RAWSIM --datatier GEN-SIM --fileout file:step1_gensim.root \
  --conditions $COND --beamspot $BS --step LHE,GEN,SIM --geometry DB:Extended --era $ERAMOD \
  "$RNG" --mc -n $NEV --nThreads 4 --no_exec > $WORKDIR/gs_drv.log 2>&1 || fail STEP1_CMSDRIVER $? $WORKDIR/gs_drv.log
cmsRun gs_cfg.py > $WORKDIR/step1.log 2>&1 || fail STEP1_GENSIM $? $WORKDIR/step1.log
GS1=$(pwd)/step1_gensim.root; ls -la $GS1 || { echo "FAIL no gensim out"; exit 5; }

# ================= STEP 2: premix =================
export SCRAM_ARCH=$DRARCH
cd $WORKDIR; scram project $DRREL >/dev/null 2>&1 || { echo "FAIL cmsrel $DRREL"; exit 6; }
cd $DRREL/src; eval `scram runtime -sh`
echo "### STEP2 premix ### $(date)"
cmsDriver.py step1 --mc --eventcontent PREMIXRAW --datatier GEN-SIM-RAW --conditions $COND \
  --step DIGI,DATAMIX,L1,DIGI2RAW,HLT:$HLT --procModifiers $PREMIXMOD --datamix PreMix \
  --pileup_input "$PU" --era $ERAMOD --geometry DB:Extended --nThreads 4 \
  --filein file:$GS1 --fileout file:step2_premix.root "$RNG" \
  --python_filename premix_cfg.py --no_exec -n -1 > $WORKDIR/premix_drv.log 2>&1 || fail STEP2_CMSDRIVER $? $WORKDIR/premix_drv.log
cmsRun premix_cfg.py > $WORKDIR/step2.log 2>&1 || fail STEP2_PREMIX $? $WORKDIR/step2.log
ls -la step2_premix.root || { echo "FAIL no premix out"; exit 7; }

# ================= STEP 3: RECO -> AODSIM =================
echo "### STEP3 RECO->AODSIM ### $(date)"
cmsDriver.py step2 --mc --eventcontent AODSIM --datatier AODSIM --conditions $COND \
  --step RAW2DIGI,L1Reco,RECO,RECOSIM $RECOPM --era $ERAMOD --geometry DB:Extended \
  --nThreads 4 --filein file:step2_premix.root --fileout file:step3_aodsim.root \
  --python_filename reco_cfg.py --no_exec -n -1 > $WORKDIR/reco_drv.log 2>&1 || fail STEP3_CMSDRIVER $? $WORKDIR/reco_drv.log
cmsRun reco_cfg.py > $WORKDIR/step3.log 2>&1 || fail STEP3_RECO $? $WORKDIR/step3.log
AOD=$(pwd)/step3_aodsim.root; ls -la $AOD || { echo "FAIL no aodsim out"; exit 8; }

# ================= STEP 4: custom LLPNanoAOD (prebuilt CMSSW_13_0_13 payload) =================
echo "### STEP4 fetch+unpack LLPNanoAOD payload ### $(date)"
cd $WORKDIR
xrdcp -f -N $EOS/payload/payload_CMSSW_13_0_13.tar.gz payload.tar.gz || { echo "FAIL payload xrdcp"; exit 9; }
tar xzf payload.tar.gz || { echo "FAIL untar payload"; exit 10; }
export SCRAM_ARCH=el8_amd64_gcc11
cd CMSSW_13_0_13; scram b ProjectRename > $WORKDIR/rename.log 2>&1 || fail STEP4_RENAME $? $WORKDIR/rename.log
cd src; eval `scram runtime -sh`
CFG=LLPNanoAOD/LLPnanoAOD/test/LLPnanoAOD_PAT_Run3_cfg.py
[ -f "$CFG" ] || CFG=$(ls LLPNanoAOD/LLPnanoAOD/test/*PAT*Run3*cfg.py 2>/dev/null | head -1)
echo "### STEP4 LLPnano cmsRun ($CFG, year=$NYEAR) ### $(date)"
cmsRun "$CFG" inputFiles=file:$AOD outputFile=llpnano.root nEvents=0 runOnData=False \
  includeDSAMuon=True includeBS=True includeGenPart=True includeDGLMuon=False includeRefittedTracks=True \
  year=$NYEAR > $WORKDIR/step4.log 2>&1 || fail STEP4_LLPNANO $? $WORKDIR/step4.log
NANO=$(ls -S llpnano*.root *NANO*.root 2>/dev/null | head -1)
[ -z "$NANO" ] && { echo "FAIL no nano out"; ls -la *.root; exit 11; }
echo "### nano = $NANO ### $(date)"; ls -la "$NANO"

# ---- sanity: event count + key LLP branches; HARD FAIL if unopenable / empty (no silent upload) ----
python3 - "$NANO" > $WORKDIR/sanity.txt 2>&1 <<'PYEOF'
import sys, ROOT
f=ROOT.TFile.Open(sys.argv[1])
if not f or f.IsZombie(): print("SANITY FAIL: cannot open"); sys.exit(1)
t=f.Get("Events")
if not t: print("SANITY FAIL: no Events tree"); sys.exit(1)
n=t.GetEntries()
bs=[b.GetName() for b in t.GetListOfBranches()]
r=f.Get("Runs"); sumw=(r.GetEntries() if r else 0)
print("SANITY nEvents=%d DSAMuon=%s GenPart_vx=%s dsaMatch=%s Runs=%d"%(
  n, any(b.startswith('DSAMuon') for b in bs), 'GenPart_vx' in bs, any('dsaMatch' in b for b in bs), sumw))
sys.exit(0 if (n>0 and r) else 1)
PYEOF
SRC=$?
cat $WORKDIR/sanity.txt
# HARD FAIL on unopenable / no Events tree / 0 events / missing Runs (broken genEventSumw) -- the python exits 1 in all those cases
[ "$SRC" -eq 0 ] || fail STEP4_SANITY "$SRC" $WORKDIR/sanity.txt

# ================= STEP 5: xrdcp nano to EOS (with size verify) =================
echo "### STEP5 xrdcp -> $EOSP/outputs/$ERA/$NAME/$OUTNAME ### $(date)"
xrdfs root://cmseos.fnal.gov mkdir -p $EOSP/outputs/$ERA/$NAME 2>/dev/null
# --posc: persist-on-successful-close, so a failed/interrupted transfer leaves no partial file
# on EOS (which the >100KB idempotency skip would otherwise permanently bless on resubmit).
xrdcp -f -N --posc "$NANO" $EOS/outputs/$ERA/$NAME/$OUTNAME || { echo "FAIL nano xrdcp"; xrdfs root://cmseos.fnal.gov rm $EOSP/outputs/$ERA/$NAME/$OUTNAME 2>/dev/null; exit 12; }
LSIZE=$(stat -c%s "$NANO"); RSIZE=$(statsize $EOSP/outputs/$ERA/$NAME/$OUTNAME)
[ "$LSIZE" = "$RSIZE" ] || { echo "FAIL xrdcp size mismatch local=$LSIZE remote=$RSIZE"; xrdfs root://cmseos.fnal.gov rm $EOSP/outputs/$ERA/$NAME/$OUTNAME 2>/dev/null; exit 13; }
echo "######## CHAIN DONE ($RSIZE bytes) -> $EOSP/outputs/$ERA/$NAME/$OUTNAME ######## $(date)"
