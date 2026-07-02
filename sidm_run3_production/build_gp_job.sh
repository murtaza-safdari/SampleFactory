#!/bin/bash
# build_gp_job.sh  MBs  MDp  CHAN
# Build one ctau-less el8 gridpack on a Condor worker (el8 image) and xrdcp it to EOS.
# Runs inside a full genproductions checkout (shipped with .git) so gridpack_generation.sh's
# script_dir/git-rev-parse and root Utilities/scripts resolve; MG prompts are auto-defaulted via </dev/null.
# One gridpack per (MBs,MDp,channel) serves all 5 ctau (ctau set later by Pythia 32:tau0), so newg here is a
# don't-care reference (ctau=1.0mm) — the LHE decay width is overridden downstream by SLHA:useDecayTable=off.
MBs=$1; MDp=$2; CHAN=$3
MDpT=$(echo $MDp | sed 's/\./p/')
GPBASE=SIDM_BsTo2DpTo${CHAN}_MBs-${MBs}_MDp-${MDpT}
EOS=root://cmseos.fnal.gov//store/group/lpcmetx/SIDM/run3_samplegen
EOSP=/store/group/lpcmetx/SIDM/run3_samplegen
WORKDIR=$(pwd)
echo "######## BUILD $GPBASE ######## $(date)  host=$(hostname)  os=$(cat /etc/redhat-release 2>/dev/null)"
source /cvmfs/cms.cern.ch/cmsset_default.sh
export SCRAM_ARCH=el8_amd64_gcc10

statsize(){ xrdfs root://cmseos.fnal.gov stat "$1" 2>/dev/null | grep -oE 'Size:[[:space:]]*[0-9]+' | grep -oE '[0-9]+'; }

# idempotency: skip only if a COMPLETE gridpack (>15MB) already exists (broken ~5MB ones do NOT skip)
EXIST=$(statsize $EOSP/gridpacks/${GPBASE}_gridpack.tar.xz)
if [ -n "$EXIST" ] && [ "$EXIST" -gt 15000000 ]; then echo "### SKIP: complete gridpack exists ($EXIST bytes) ###"; exit 0; fi

# fetch full genproductions repo (with .git + root Utilities/scripts)
xrdcp -f -N $EOS/payload/genpro_repo.tar.gz genpro_repo.tar.gz || { echo "FAIL payload xrdcp"; exit 3; }
tar xzf genpro_repo.tar.gz || { echo "FAIL untar payload"; exit 4; }
cd genproductions/bin/MadGraph5_aMCatNLO || { echo "FAIL no genproductions dir"; exit 4; }

# channel decay + reference newg (ctau-independent for the sample; ctau=1.0mm reference)
if [ "$CHAN" = "2Mu2E" ]; then DEC="zp > mu+ mu-, zp > e+ e-"; else DEC="zp > mu+ mu-"; fi
EPS=$(python3 -c "import math;print('%.6e'%(math.sqrt(80.0/$MDp/1.0)*1e-6))")

CD=cards/$GPBASE; rm -rf $CD; mkdir -p $CD
cat > $CD/${GPBASE}_proc_card.dat <<EOF
set group_subprocesses Auto
set ignore_six_quark_processes False
set loop_optimized_output True
set complex_mass_scheme False
import model pscalar_darkphoton_UFO -modelname
generate p p > pscalar, (pscalar > zp zp, $DEC)
output $GPBASE -nojpeg
EOF
cp $WORKDIR/run_card_template.dat $CD/${GPBASE}_run_card.dat || { echo "FAIL no run_card template"; exit 5; }
cat > $CD/${GPBASE}_customizecards.dat <<EOF
set time_of_flight 0.0001
set param_card mass 35 $MBs
set param_card mass 32 $MDp
set param_card newg 1 $EPS
EOF
echo "pscalar_darkphoton_UFO.zip" > $CD/${GPBASE}_extramodels.dat

echo "### gridpack_generation.sh $GPBASE (newg=$EPS, decay: $DEC) ### $(date)"
bash gridpack_generation.sh $GPBASE cards/$GPBASE local ALL < /dev/null > $WORKDIR/build.log 2>&1
RC=$?
TAR=$(ls ${GPBASE}_el8_amd64_gcc10_*tarball.tar.xz 2>/dev/null | head -1)
if [ -z "$TAR" ]; then echo "### FAIL build (rc=$RC) ###"; tail -50 $WORKDIR/build.log; exit 6; fi

# completeness check: the gridpack must contain the generated MadEvent process (else it makes no events)
NPROC=$(tar tf "$TAR" 2>/dev/null | grep -c "process/madevent")
if [ "$NPROC" -lt 1 ]; then
  echo "### FAIL: incomplete gridpack ($TAR, $(stat -c%s $TAR) bytes, process/madevent entries=$NPROC) ###"
  tail -40 $WORKDIR/build.log; exit 9
fi
echo "### built $TAR ($(stat -c%s $TAR) bytes, process/madevent entries=$NPROC) ### $(date)"

xrdcp -f -N "$TAR" $EOS/gridpacks/${GPBASE}_gridpack.tar.xz || { echo "FAIL gridpack xrdcp"; exit 7; }
RSIZE=$(statsize $EOSP/gridpacks/${GPBASE}_gridpack.tar.xz); LSIZE=$(stat -c%s "$TAR")
[ "$LSIZE" = "$RSIZE" ] || { echo "FAIL xrdcp size mismatch local=$LSIZE remote=$RSIZE"; exit 8; }
echo "######## BUILD DONE ($RSIZE bytes) -> gridpacks/${GPBASE}_gridpack.tar.xz ######## $(date)"
