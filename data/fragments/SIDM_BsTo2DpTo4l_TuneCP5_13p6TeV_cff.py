import FWCore.ParameterSet.Config as cms
import os

# SIDM Run 3 signal fragment (pp -> pseudoscalar -> 2 dark photons -> lepton-jets).
#
# Minimal delta from the validated Run 2 SIDM genproductions fragment
# (genfragments/ThirteenTeV/SIDM/SIDM_BsTo2DpTo4l_..._TuneCP5_13TeV_pythia8_cff.py):
#   * comEnergy 13000 -> 13600 (13.6 TeV)
#   * CP5 tune import: MCTunes2017 -> MCTunesRun3ECM13p6TeV (the Run 3 CP5 tune)
#   * added SLHA:useDecayTable=off + 32:tauCalc=off  (robustness: the dark-photon lifetime is
#     set by 32:tau0 -- exactly as in Run 2 SIDM and in Sunil's fragments -- and these two lines
#     stop the gridpack's embedded DECAY-32 width from silently overriding it)
# No gen filter: matches the v10 Run 2 SIDM signal samples ("no unwanted gen filters"). Sunil's
# Run 3 fragments add a >=4-lepton acceptance filter; we deliberately omit it to match v10.
#
# GRIDPACK (tarball path) and CTAU (dark-photon proper ctau in mm) are supplied per job via
# environment variables, exactly as in the IDM SampleFactory fragments.

externalLHEProducer = cms.EDProducer("ExternalLHEProducer",
    args = cms.vstring(os.path.abspath(os.environ["GRIDPACK"])),
    nEvents = cms.untracked.uint32(5000),
    numberOfParameters = cms.uint32(1),
    outputFile = cms.string('cmsgrid_final.lhe'),
    scriptName = cms.FileInPath('GeneratorInterface/LHEInterface/data/run_generic_tarball_cvmfs.sh')
)

from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.MCTunesRun3ECM13p6TeV.PythiaCP5Settings_cfi import *
from Configuration.Generator.PSweightsPythia.PythiaPSweightsSettings_cfi import *

generator = cms.EDFilter("Pythia8HadronizerFilter",
    maxEventsToPrint = cms.untracked.int32(0),
    pythiaPylistVerbosity = cms.untracked.int32(0),
    filterEfficiency = cms.untracked.double(1.0),
    pythiaHepMCVerbosity = cms.untracked.bool(False),
    comEnergy = cms.double(13600.),
    PythiaParameters = cms.PSet(
        pythia8CommonSettingsBlock,
        pythia8CP5SettingsBlock,
        pythia8PSweightsSettingsBlock,
        processParameters = cms.vstring(
            'ParticleDecays:tau0Max = 1000.1',
            'LesHouches:setLifetime = 2',
            'SLHA:useDecayTable = off',
            '32:tau0 = %s' % os.environ['CTAU'],
            '32:tauCalc = off',
            '32:mayDecay = on',
        ),
        parameterSets = cms.vstring(
            'pythia8CommonSettings', 'pythia8CP5Settings', 'pythia8PSweightsSettings', 'processParameters',
        )
    )
)

ProductionFilterSequence = cms.Sequence(generator)
